package edu.pkmon.user.service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;
import java.util.regex.Pattern;
import static edu.pkmon.user.service.AuthFailure.Kind.UNAUTHENTICATED;

/** Hashes random session credentials, never user passwords. */
public final class SessionTokens {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Pattern BEARER = Pattern.compile("(?i:Bearer) ([A-Za-z0-9_-]{43})");
    private SessionTokens() {}

    public static String issue() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public static String hashFromAuthorization(String header) {
        if (header == null) throw new AuthFailure(UNAUTHENTICATED);
        var matcher = BEARER.matcher(header);
        if (!matcher.matches()) throw new AuthFailure(UNAUTHENTICATED);
        String token = matcher.group(1);
        // Reject noncanonical base64 spellings instead of accepting aliases of one credential.
        String canonical = Base64.getUrlEncoder().withoutPadding().encodeToString(Base64.getUrlDecoder().decode(token));
        if (!canonical.equals(token)) throw new AuthFailure(UNAUTHENTICATED);
        return hash(token);
    }

    public static String hash(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.US_ASCII)));
        } catch (NoSuchAlgorithmException impossible) {
            throw new IllegalStateException("SHA-256 unavailable", impossible);
        }
    }
}
