package edu.pkmon.user.dto;

import edu.pkmon.user.domain.User;
import java.time.Instant;

/** JSON field names are the final account contract; no HTTP controller is wired in this prototype. */
public final class AuthDtos {
    private AuthDtos() {}

    public record RegisterRequest(String username, String password, String nickname) {
        @Override public String toString() { return "RegisterRequest[REDACTED]"; }
    }
    public record LoginRequest(String username, String password) {
        @Override public String toString() { return "LoginRequest[REDACTED]"; }
    }
    public record UserView(String userId, String username, String nickname) {
        public static UserView from(User user) {
            return new UserView(user.userId(), user.username(), user.nickname());
        }
    }
    public record LoginResult(String token, Instant expiresAt, UserView user) {
        @Override public String toString() { return "LoginResult[token=REDACTED]"; }
    }
}
