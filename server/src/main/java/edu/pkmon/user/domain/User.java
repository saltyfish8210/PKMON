package edu.pkmon.user.domain;

import java.time.Instant;
import java.util.Objects;

/** Internal persistence model. Expose only AuthDtos.UserView to clients. */
public record User(String userId, String username, String nickname, String passwordHash, Instant createdAt) {
    public User {
        Objects.requireNonNull(userId);
        Objects.requireNonNull(username);
        Objects.requireNonNull(nickname);
        Objects.requireNonNull(passwordHash);
        Objects.requireNonNull(createdAt);
    }

    @Override public String toString() { return "User[userId=" + userId + ", credentials=REDACTED]"; }
}
