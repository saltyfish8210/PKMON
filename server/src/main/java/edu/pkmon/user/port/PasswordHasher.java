package edu.pkmon.user.port;

/** Production adapter must use a mature adaptive password library. Never implement with plain SHA-256. */
public interface PasswordHasher {
    String hash(String password);
    boolean matches(String password, String encodedHash);
}
