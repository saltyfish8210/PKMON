package edu.pkmon.user.service;

import edu.pkmon.user.domain.AuthSession;
import edu.pkmon.user.domain.User;
import edu.pkmon.user.dto.AuthDtos.*;
import edu.pkmon.user.port.*;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import java.util.function.Supplier;
import static edu.pkmon.user.service.AuthFailure.Kind.*;

/** Executable design prototype. No Spring bean, HTTP route or production storage adapter is installed. */
public final class AuthService {
    private final UserRepository users;
    private final AuthSessionRepository sessions;
    private final PasswordHasher passwords;
    private final Clock clock;
    private final String dummyHash;

    public AuthService(UserRepository users, AuthSessionRepository sessions, PasswordHasher passwords, Clock clock) {
        this.users = users; this.sessions = sessions; this.passwords = passwords; this.clock = clock;
        // Same hashing path on unknown usernames. This is not a login credential.
        this.dummyHash = safely(() -> passwords.hash(SessionTokens.issue()));
    }

    public UserView register(RegisterRequest request) {
        if (request == null) throw new AuthFailure(INVALID_INPUT);
        String username = AuthRules.username(request.username());
        String nickname = AuthRules.nickname(request.nickname());
        AuthRules.password(request.password());
        return safely(() -> {
            User user = new User(UUID.randomUUID().toString(), username, nickname,
                    passwords.hash(request.password()), clock.instant());
            if (!users.insertIfUsernameAbsent(user)) throw new AuthFailure(USERNAME_TAKEN);
            return UserView.from(user);
        });
    }

    public LoginResult login(LoginRequest request) {
        if (request == null) throw new AuthFailure(INVALID_INPUT);
        String username = AuthRules.username(request.username());
        AuthRules.password(request.password());
        return safely(() -> {
            User user = users.findByUsername(username).orElse(null);
            boolean matched = passwords.matches(request.password(), user == null ? dummyHash : user.passwordHash());
            if (user == null || !matched) throw new AuthFailure(UNAUTHENTICATED);
            Instant issuedAt = clock.instant();
            String token = SessionTokens.issue();
            AuthSession session = new AuthSession(UUID.randomUUID().toString(), user.userId(),
                    SessionTokens.hash(token), issuedAt, issuedAt.plus(AuthRules.SESSION_TTL), null);
            sessions.insert(session); // A failed write must never yield a usable login response.
            return new LoginResult(token, session.expiresAt(), UserView.from(user));
        });
    }

    public UserView currentUser(String authorization) {
        return safely(() -> {
            AuthSession session = findSession(authorization);
            if (!session.isActiveAt(clock.instant())) throw new AuthFailure(UNAUTHENTICATED);
            return UserView.from(users.findById(session.userId()).orElseThrow(() -> new AuthFailure(UNAUTHENTICATED)));
        });
    }

    public void logout(String authorization) {
        safely(() -> {
            AuthSession session = findSession(authorization);
            Instant now = clock.instant();
            if (now.isBefore(session.issuedAt())) throw new AuthFailure(UNAUTHENTICATED);
            sessions.revokeIfActive(session.sessionId(), now);
            return null;
        });
    }

    /** Supplier must read the current request on every call; never capture one user's header in a singleton. */
    public CurrentUser currentUserPort(Supplier<String> authorizationHeader) {
        return () -> currentUser(authorizationHeader.get()).userId();
    }

    private AuthSession findSession(String authorization) {
        return sessions.findByTokenHash(SessionTokens.hashFromAuthorization(authorization))
                .orElseThrow(() -> new AuthFailure(UNAUTHENTICATED));
    }

    private static <T> T safely(Supplier<T> work) {
        try { return work.get(); }
        catch (AuthFailure failure) { throw failure; }
        catch (RuntimeException failure) { throw new AuthFailure(UNAVAILABLE); }
    }
}
