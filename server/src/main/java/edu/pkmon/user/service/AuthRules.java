package edu.pkmon.user.service;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Locale;
import static edu.pkmon.user.service.AuthFailure.Kind.INVALID_INPUT;

public final class AuthRules {
    public static final Duration SESSION_TTL = Duration.ofHours(8);
    private AuthRules() {}

    public static String username(String value) {
        if (value == null || !value.matches("[A-Za-z0-9_]{3,24}")) throw new AuthFailure(INVALID_INPUT);
        return value.toLowerCase(Locale.ROOT);
    }

    public static String nickname(String value) {
        if (value == null) throw new AuthFailure(INVALID_INPUT);
        String result = value.strip();
        int length = result.codePointCount(0, result.length());
        if (length < 1 || length > 20 || result.codePoints().anyMatch(Character::isISOControl)
                || !StandardCharsets.UTF_8.newEncoder().canEncode(result)) throw new AuthFailure(INVALID_INPUT);
        return result;
    }

    public static void password(String value) {
        if (value == null) throw new AuthFailure(INVALID_INPUT);
        int length = value.codePointCount(0, value.length());
        if (length < 12 || length > 64 || value.getBytes(StandardCharsets.UTF_8).length > 72
                || value.codePoints().anyMatch(Character::isISOControl)
                || !StandardCharsets.UTF_8.newEncoder().canEncode(value)) throw new AuthFailure(INVALID_INPUT);
    }
}
