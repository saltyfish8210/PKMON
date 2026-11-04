package edu.pkmon.user.service;

import edu.pkmon.user.port.PasswordHasher;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

public final class BcryptPasswords implements PasswordHasher {
    private static final String PREFIX = "{bcrypt}";
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12);

    @Override public String hash(String password) {
        return PREFIX + encoder.encode(password);
    }

    @Override public boolean matches(String password, String encodedHash) {
        return encodedHash.startsWith(PREFIX) && encoder.matches(password, encodedHash.substring(PREFIX.length()));
    }
}
