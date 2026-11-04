package edu.pkmon.user.web;

import edu.pkmon.capture.config.CaptureConfig;
import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.user.jdbc.JdbcAccounts;
import edu.pkmon.user.service.AuthFailure;
import edu.pkmon.user.service.AuthService;
import edu.pkmon.user.service.BcryptPasswords;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.jdbc.core.JdbcTemplate;
import java.time.Clock;

@AutoConfiguration(before = CaptureConfig.class)
public class AccountConfiguration {
    @Bean JdbcAccounts accountStore(JdbcTemplate jdbc) { return new JdbcAccounts(jdbc); }

    @Bean AuthService accountService(JdbcAccounts store, Clock clock) {
        return new AuthService(store, store, new BcryptPasswords(), clock);
    }

    @Bean AccountWeb accountWeb(AuthService auth) { return new AccountWeb(auth); }

    @Bean AccountErrors accountErrors() { return new AccountErrors(); }

    @Bean CurrentUserProvider accountIdentity(AuthService auth, HttpServletRequest request, Environment env) {
        boolean devIdentities = env.acceptsProfiles(Profiles.of("dev", "test"))
                && env.getProperty("pkmon.capture.dev-user-header", Boolean.class, true);
        return () -> {
            String header = AccountWeb.authorization(request);
            if (header == null && devIdentities) {
                String fixture = request.getHeader("X-Dev-User");
                if (fixture != null && !fixture.isBlank()) return "dev:" + fixture;
            }
            if (header == null) throw new AuthFailure(AuthFailure.Kind.UNAUTHENTICATED);
            return auth.currentUser(header).userId();
        };
    }
}
