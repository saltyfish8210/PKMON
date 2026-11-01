package edu.pkmon.user;

import com.fasterxml.jackson.databind.ObjectMapper;
import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.user.domain.*;
import edu.pkmon.user.dto.AuthDtos.*;
import edu.pkmon.user.port.*;
import edu.pkmon.user.service.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.jupiter.api.Assertions.*;
import static edu.pkmon.user.service.AuthFailure.Kind.*;

/** Contract tests. All storage and password substitutes are test-only, not production security adapters. */
class AuthServiceTest {
    private static final String PASSWORD = "campus password 2026";
    private MemoryUsers users;
    private MemorySessions sessions;
    private TestHasher hasher;
    private MutableClock clock;
    private AuthService auth;

    @BeforeEach void setUp() {
        users = new MemoryUsers(); sessions = new MemorySessions(); hasher = new TestHasher();
        clock = new MutableClock(Instant.parse("2026-10-27T00:00:00Z"));
        auth = new AuthService(users, sessions, hasher, clock);
    }

    @Test void registerNormalizesUsernameButDoesNotCreateSession() {
        var view = register("Alice");
        assertEquals("alice", view.username());
        assertEquals("校园同学", view.nickname());
        assertDoesNotThrow(() -> UUID.fromString(view.userId()));
        assertTrue(sessions.rows.isEmpty());
    }

    @Test void caseVariantsCannotCreateDuplicateAccountsEvenConcurrently() throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Callable<String> job = () -> { try { register("Alice"); return "created"; }
                catch (AuthFailure failure) { return failure.kind().name(); } };
            var results = pool.invokeAll(List.of(job, job));
            assertEquals(Set.of("created", "USERNAME_TAKEN"), Set.of(results.get(0).get(), results.get(1).get()));
            assertEquals(1, users.rows.size());
            assertFailure(USERNAME_TAKEN, () -> register("ALICE"));
        } finally { pool.shutdownNow(); }
    }

    @Test void invalidRegistrationDoesNotWriteAnything() {
        for (String value : List.of("ab", " alice", "学生123", "a".repeat(25)))
            assertFailure(INVALID_INPUT, () -> register(value));
        assertFailure(INVALID_INPUT, () -> auth.register(new RegisterRequest("alice", PASSWORD, " ")));
        assertFailure(INVALID_INPUT, () -> auth.register(new RegisterRequest("alice", PASSWORD, "同".repeat(21))));
        assertFailure(INVALID_INPUT, () -> auth.register(null));
        assertTrue(users.rows.isEmpty());
    }

    @Test void passwordUsesUnicodeCountAndUtf8ByteLimitWithoutTruncation() {
        assertFailure(INVALID_INPUT, () -> AuthRules.password("a".repeat(11)));
        assertDoesNotThrow(() -> AuthRules.password("a".repeat(12)));
        assertDoesNotThrow(() -> AuthRules.password("a".repeat(64)));
        assertFailure(INVALID_INPUT, () -> AuthRules.password("a".repeat(65)));
        assertDoesNotThrow(() -> AuthRules.password("密".repeat(24)));
        assertFailure(INVALID_INPUT, () -> AuthRules.password("密".repeat(25)));
        assertFailure(INVALID_INPUT, () -> AuthRules.password("a".repeat(12) + "\n"));
        assertFailure(INVALID_INPUT, () -> AuthRules.password("a".repeat(12) + "\uD800"));
    }

    @Test void nicknameCountsEmojiAsOneCodePoint() {
        assertEquals("😀".repeat(20), AuthRules.nickname("  " + "😀".repeat(20) + "  "));
        assertFailure(INVALID_INPUT, () -> AuthRules.nickname("😀".repeat(21)));
        assertFailure(INVALID_INPUT, () -> AuthRules.nickname("昵称\n异常"));
    }

    @Test void unknownUserAndWrongPasswordReturnSameFailureAndBothUseHasher() {
        register("alice");
        var unknown = assertFailure(UNAUTHENTICATED, () -> auth.login(new LoginRequest("nobody", PASSWORD)));
        var wrong = assertFailure(UNAUTHENTICATED, () -> auth.login(new LoginRequest("alice", "wrong password 2026")));
        assertEquals(unknown.getMessage(), wrong.getMessage());
        assertEquals(2, hasher.matchesCalls);
        assertTrue(sessions.rows.isEmpty());
    }

    @Test void passwordSpacesAreSignificant() {
        auth.register(new RegisterRequest("alice", "  campus password  ", "校园同学"));
        assertFailure(UNAUTHENTICATED, () -> auth.login(new LoginRequest("alice", "campus password")));
        assertNotNull(auth.login(new LoginRequest("alice", "  campus password  ")).token());
    }

    @Test void loginReturnsOpaqueTokenAndOnlyStoresItsDigest() {
        register("alice"); var result = login("ALICE");
        assertEquals(32, Base64.getUrlDecoder().decode(result.token()).length);
        assertEquals(clock.instant().plus(Duration.ofHours(8)), result.expiresAt());
        var row = sessions.rows.get(0);
        assertEquals(SessionTokens.hash(result.token()), row.tokenHash());
        assertNotEquals(result.token(), row.tokenHash());
        assertFalse(row.toString().contains(result.token()));
        assertFalse(result.toString().contains(result.token()));
    }

    @Test void failedSessionInsertCannotProduceLoginSuccessOrLeakStorageDetails() {
        register("alice"); sessions.failInsert = true;
        var failure = assertFailure(UNAVAILABLE, () -> login("alice"));
        assertFalse(failure.toString().contains("private database details"));
        assertTrue(sessions.rows.isEmpty());
    }

    @Test void missingMalformedAndUnknownCredentialsFailClosed() {
        register("alice"); String token = login("alice").token();
        for (String header : Arrays.asList(null, "", "X-Dev-User alice", "Basic " + token,
                "Bearer  " + token, "Bearer " + token + " ", "Bearer " + token + "," + token,
                "Bearer short", "Bearer " + SessionTokens.issue()))
            assertFailure(UNAUTHENTICATED, () -> auth.currentUser(header));
        assertEquals("alice", auth.currentUser("bearer " + token).username());
    }

    @Test void nonCanonicalBase64TokenIsRejected() {
        assertFailure(UNAUTHENTICATED, () -> SessionTokens.hashFromAuthorization("Bearer " + "A".repeat(42) + "B"));
    }

    @Test void sessionExpiresAtTheExactBoundaryAndNeverSlides() {
        register("alice"); var result = login("alice"); String header = bearer(result);
        clock.now = result.expiresAt().minusNanos(1);
        assertEquals("alice", auth.currentUser(header).username());
        assertEquals(result.expiresAt(), sessions.rows.get(0).expiresAt());
        clock.now = result.expiresAt();
        assertFailure(UNAUTHENTICATED, () -> auth.currentUser(header));
    }

    @Test void clockBeforeIssuedAtDoesNotAuthenticate() {
        register("alice"); String header = bearer(login("alice"));
        clock.now = clock.now.minusSeconds(1);
        assertFailure(UNAUTHENTICATED, () -> auth.currentUser(header));
        assertFailure(UNAUTHENTICATED, () -> auth.logout(header));
    }

    @Test void logoutRevokesOnlyThisSessionAndIsIdempotent() {
        register("alice"); var first = login("alice"); var second = login("alice");
        assertNotEquals(first.token(), second.token());
        auth.logout(bearer(first)); Instant revoked = sessions.rows.get(0).revokedAt();
        clock.now = clock.now.plusSeconds(5); auth.logout(bearer(first));
        assertEquals(revoked, sessions.rows.get(0).revokedAt());
        assertFailure(UNAUTHENTICATED, () -> auth.currentUser(bearer(first)));
        assertEquals("alice", auth.currentUser(bearer(second)).username());
    }

    @Test void knownExpiredLogoutIsIdempotentButUnknownTokenIsRejected() {
        register("alice"); var result = login("alice"); clock.now = result.expiresAt();
        assertDoesNotThrow(() -> auth.logout(bearer(result)));
        assertDoesNotThrow(() -> auth.logout(bearer(result)));
        assertFailure(UNAUTHENTICATED, () -> auth.logout("Bearer " + SessionTokens.issue()));
    }

    @Test void deletedUserCannotKeepUsingTheirSession() {
        register("alice"); var result = login("alice"); users.rows.clear();
        assertFailure(UNAUTHENTICATED, () -> auth.currentUser(bearer(result)));
    }

    @Test void identityPortResolvesPerRequestAndFitsExistingCaptureInterface() {
        var alice = register("alice"); var bob = register("bob");
        String a = bearer(login("alice")), b = bearer(login("bob"));
        AtomicReference<String> header = new AtomicReference<>(a);
        CurrentUser port = auth.currentUserPort(header::get);
        CurrentUserProvider captureAdapter = port::currentUserId;
        assertEquals(alice.userId(), captureAdapter.currentUserId());
        header.set(b); assertEquals(bob.userId(), captureAdapter.currentUserId());
        header.set(null); assertFailure(UNAUTHENTICATED, captureAdapter::currentUserId);
    }

    @Test void storageReadFailureDoesNotFallBackToDevelopmentIdentity() {
        register("alice"); var result = login("alice"); sessions.failRead = true;
        assertFailure(UNAVAILABLE, () -> auth.currentUser(bearer(result)));
    }

    @Test void failedRevocationCannotReportServerLogoutSuccess() {
        register("alice"); var result = login("alice"); sessions.failRevoke = true;
        assertFailure(UNAVAILABLE, () -> auth.logout(bearer(result)));
        assertEquals("alice", auth.currentUser(bearer(result)).username());
    }

    @Test void publicUserDtoContainsNoCredentialFields() throws Exception {
        var view = register("alice");
        var json = new ObjectMapper().readTree(new ObjectMapper().writeValueAsString(view));
        assertEquals(3, json.size());
        assertTrue(json.has("userId") && json.has("username") && json.has("nickname"));
        assertFalse(users.rows.values().iterator().next().toString().contains(PASSWORD));
        assertFalse(new LoginRequest("alice", PASSWORD).toString().contains(PASSWORD));
        assertFalse(new RegisterRequest("alice", PASSWORD, "昵称").toString().contains(PASSWORD));
    }

    private UserView register(String username) {
        return auth.register(new RegisterRequest(username, PASSWORD, " 校园同学 "));
    }
    private LoginResult login(String username) { return auth.login(new LoginRequest(username, PASSWORD)); }
    private String bearer(LoginResult result) { return "Bearer " + result.token(); }
    private static AuthFailure assertFailure(AuthFailure.Kind kind, org.junit.jupiter.api.function.Executable action) {
        AuthFailure failure = assertThrows(AuthFailure.class, action);
        assertEquals(kind, failure.kind()); return failure;
    }

    // All substitutes stay in src/test; no production bean or reusable fake-login switch exists.
    private static final class TestHasher implements PasswordHasher {
        int matchesCalls;
        public String hash(String password) { return "TEST_ONLY:" + password; }
        public boolean matches(String password, String encoded) { matchesCalls++; return encoded.equals(hash(password)); }
    }
    private static final class MemoryUsers implements UserRepository {
        final Map<String, User> rows = new ConcurrentHashMap<>();
        public Optional<User> findById(String id) { return rows.values().stream().filter(u -> u.userId().equals(id)).findFirst(); }
        public Optional<User> findByUsername(String name) { return Optional.ofNullable(rows.get(name)); }
        public boolean insertIfUsernameAbsent(User user) { return rows.putIfAbsent(user.username(), user) == null; }
    }
    private static final class MemorySessions implements AuthSessionRepository {
        final List<AuthSession> rows = new ArrayList<>();
        boolean failRead, failInsert, failRevoke;
        public synchronized Optional<AuthSession> findByTokenHash(String hash) {
            if (failRead) throw new IllegalStateException("private database details");
            return rows.stream().filter(s -> s.tokenHash().equals(hash)).findFirst();
        }
        public synchronized void insert(AuthSession session) {
            if (failInsert) throw new IllegalStateException("private database details");
            if (rows.stream().anyMatch(s -> s.sessionId().equals(session.sessionId()) || s.tokenHash().equals(session.tokenHash())))
                throw new IllegalStateException("duplicate session");
            rows.add(session);
        }
        public synchronized void revokeIfActive(String sessionId, Instant now) {
            if (failRevoke) throw new IllegalStateException("private database details");
            rows.replaceAll(s -> s.sessionId().equals(sessionId) ? s.revokeAt(now) : s);
        }
    }
    private static final class MutableClock extends Clock {
        Instant now;
        MutableClock(Instant now) { this.now = now; }
        @Override public ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(ZoneId zone) {
            if (!zone.equals(ZoneOffset.UTC)) throw new UnsupportedOperationException("UTC only test clock");
            return this;
        }
        @Override public Instant instant() { return now; }
    }
}
