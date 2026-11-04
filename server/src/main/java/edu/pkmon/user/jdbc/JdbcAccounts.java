package edu.pkmon.user.jdbc;

import edu.pkmon.user.domain.AuthSession;
import edu.pkmon.user.domain.User;
import edu.pkmon.user.port.AuthSessionRepository;
import edu.pkmon.user.port.UserRepository;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

/** Uses the shared Flyway V1 schema. Each write is a single atomic SQL statement. */
public final class JdbcAccounts implements UserRepository, AuthSessionRepository {
    private final JdbcTemplate db;

    public JdbcAccounts(JdbcTemplate db) {
        this.db = db;
    }

    private static final RowMapper<User> USER = (rs, row) -> new User(
            rs.getString("user_id"), rs.getString("username"), rs.getString("nickname"),
            rs.getString("password_hash"), rs.getObject("created_at", OffsetDateTime.class).toInstant());

    @Override public Optional<User> findById(String id) {
        return db.query("select * from users where user_id = ?", USER, id).stream().findFirst();
    }

    @Override public Optional<User> findByUsername(String username) {
        return db.query("select * from users where username = ?", USER, username).stream().findFirst();
    }

    @Override public boolean insertIfUsernameAbsent(User user) {
        try {
            db.update("insert into users (user_id,username,nickname,password_hash,created_at) values (?,?,?,?,?)",
                    user.userId(), user.username(), user.nickname(), user.passwordHash(), utc(user.createdAt()));
            return true;
        } catch (DuplicateKeyException conflict) {
            if (findByUsername(user.username()).isPresent()) return false;
            throw conflict;
        }
    }

    @Override public Optional<AuthSession> findByTokenHash(String digest) {
        return db.query("select * from auth_sessions where token_digest = ?", (rs, row) -> {
            OffsetDateTime revoked = rs.getObject("revoked_at", OffsetDateTime.class);
            return new AuthSession(rs.getString("session_id"), rs.getString("user_id"), rs.getString("token_digest"),
                    rs.getObject("issued_at", OffsetDateTime.class).toInstant(),
                    rs.getObject("expires_at", OffsetDateTime.class).toInstant(),
                    revoked == null ? null : revoked.toInstant());
        }, digest).stream().findFirst();
    }

    @Override public void insert(AuthSession session) {
        db.update("insert into auth_sessions (session_id,user_id,token_digest,issued_at,expires_at) values (?,?,?,?,?)",
                session.sessionId(), session.userId(), session.tokenHash(), utc(session.issuedAt()), utc(session.expiresAt()));
    }

    @Override public void revokeIfActive(String id, Instant now) {
        db.update("update auth_sessions set revoked_at = ? where session_id = ? and revoked_at is null", utc(now), id);
    }

    private static OffsetDateTime utc(Instant time) {
        return time.atOffset(ZoneOffset.UTC);
    }
}
