package edu.pkmon.user.port;

import edu.pkmon.user.domain.AuthSession;
import java.time.Instant;
import java.util.Optional;

public interface AuthSessionRepository {
    Optional<AuthSession> findByTokenHash(String tokenHash);
    /** Atomic insert. sessionId and tokenHash must both be unique; conflict or storage failure throws. */
    void insert(AuthSession session);
    /** Atomic update, only if revokedAt IS NULL; retain the first revocation time. Missing row is a no-op. */
    void revokeIfActive(String sessionId, Instant now);
}
