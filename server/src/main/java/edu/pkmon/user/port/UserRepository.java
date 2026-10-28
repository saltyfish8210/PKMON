package edu.pkmon.user.port;

import edu.pkmon.user.domain.User;
import java.util.Optional;

public interface UserRepository {
    Optional<User> findById(String userId);
    Optional<User> findByUsername(String canonicalUsername);
    /** Atomic insert: false only for a duplicate canonical username. Other failures throw. */
    boolean insertIfUsernameAbsent(User user);
}
