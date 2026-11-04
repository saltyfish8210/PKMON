package edu.pkmon.user;

import com.fasterxml.jackson.databind.ObjectMapper;
import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.demo.PkmonApplication;
import edu.pkmon.user.service.SessionTokens;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;
import java.util.UUID;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(classes = PkmonApplication.class)
@AutoConfigureMockMvc
class AccountIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate db;
    @Autowired ApplicationContext context;

    @Test void realStorageHashesCredentialsAndHonorsExpiry() throws Exception {
        String username = "user_" + UUID.randomUUID().toString().substring(0,8);
        String pwd = UUID.randomUUID().toString();
        String registration = json.writeValueAsString(Map.of("username",username,"password",pwd,"nickname","队员"));
        mvc.perform(post("/api/v1/auth/register").contentType("application/json").content(registration))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.data.token").doesNotExist());
        String stored = db.queryForObject("select password_hash from users where username=?", String.class,username);
        assertThat(stored).startsWith("{bcrypt}$2").contains("$12$").doesNotContain(pwd);
        String login = json.writeValueAsString(Map.of("username",username,"password",pwd));
        String reply = mvc.perform(post("/api/v1/auth/login").contentType("application/json").content(login))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String token = json.readTree(reply).at("/data/token").textValue();
        String digest = SessionTokens.hash(token);
        assertThat(db.queryForObject("select token_digest from auth_sessions s join users u on s.user_id=u.user_id where u.username=?",String.class,username)).isEqualTo(digest);
        assertThat(context.getBeansOfType(CurrentUserProvider.class)).hasSize(1);
        mvc.perform(get("/api/v1/users/me").header("Authorization","Bearer "+token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.username").value(username));
        mvc.perform(get("/api/v1/users/me").header("Authorization","Bearer "+token,"Bearer ignored"))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value(40101));
        db.update("update auth_sessions set issued_at=dateadd(hour,-10,current_timestamp), expires_at=dateadd(hour,-1,current_timestamp) where token_digest=?",digest);
        mvc.perform(get("/api/v1/collection/summary").header("Authorization","Bearer "+token)
                        .header("X-Dev-User",username))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value(40101));
    }

    @Test void rejectsAmbiguousJsonAndOversizeBodies() throws Exception {
        for (String body : new String[] {
                "{\"username\":\"alpha\",\"username\":\"bravo\",\"password\":\"0123456789ab\"}",
                "{\"username\":12345,\"password\":\"0123456789ab\"}",
                "{\"username\":\"alpha\",\"password\":\"0123456789ab\",\"userId\":\"fake\"}",
                "{\"username\":\"alpha\",\"password\":\"0123456789ab\"} {}",
                " ".repeat(4097) }) {
            mvc.perform(post("/api/v1/auth/login").contentType("application/json").content(body))
                    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value(40001));
        }
    }

    @Test void rejectsDuplicateCredentialsAndForgedIdentity() throws Exception {
        mvc.perform(get("/api/v1/users/me").header("Authorization","Bearer bad","Bearer other"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/study/tasks/current").header("X-Dev-User","forged"))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value(40101));
    }
}
