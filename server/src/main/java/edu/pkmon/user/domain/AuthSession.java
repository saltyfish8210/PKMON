package edu.pkmon.user.domain;

import java.time.Instant;
import java.util.Objects;

public record AuthSession(String sessionId, String userId, String tokenHash,
                          Instant issuedAt, Instant expiresAt, Instant revokedAt) {
    public AuthSession {
        Objects.requireNonNull(sessionId);
        Objects.requireNonNull(userId);
        Objects.requireNonNull(tokenHash);
        Objects.requireNonNull(issuedAt);
        Objects.requireNonNull(expiresAt);
        if (!tokenHash.matches("[0-9a-f]{64}") || !expiresAt.isAfter(issuedAt)
                || (revokedAt != null && revokedAt.isBefore(issuedAt))) {
            throw new IllegalArgumentException("Invalid session state");
        }
    }

    public boolean isActiveAt(Instant now) {
        return revokedAt == null && !now.isBefore(issuedAt) && now.isBefore(expiresAt);
    }

    public AuthSession revokeAt(Instant now) {
        return revokedAt != null ? this : new AuthSession(sessionId, userId, tokenHash, issuedAt, expiresAt, now);
    }

    @Override public String toString() { return "AuthSession[sessionId=" + sessionId + ", token=REDACTED]"; }
}
