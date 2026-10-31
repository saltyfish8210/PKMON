package edu.pkmon.common;

import edu.pkmon.demo.PkmonApplication;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import javax.sql.DataSource;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 公共骨架验收：独立测试库、空库迁移、可注入 Clock、关键唯一约束。
 * 测试数据各用例独立编号，互不影响；只连 pkmon_test 内存库（见 application-test.properties）。
 */
@SpringBootTest(classes = PkmonApplication.class)
@ActiveProfiles("test")
class CommonFoundationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private DataSource dataSource;

    @Autowired
    private Clock clock;

    @Autowired
    private Flyway flyway;

    @Test
    @DisplayName("测试库独立：连接的是 pkmon_test 内存库，不是开发文件库")
    void testDatabaseIsIsolated() throws Exception {
        String url = dataSource.getConnection().getMetaData().getURL();
        assertTrue(url.contains("pkmon_test"), "测试库应为 pkmon_test，实际：" + url);
    }

    @Test
    @DisplayName("空库迁移：V1 初始结构已由 Flyway 成功应用，且无其他迁移")
    void emptyDatabaseMigrated() {
        var applied = flyway.info().applied();
        assertEquals(1, applied.length);
        assertEquals("V1__init_schema.sql", applied[0].getScript());
    }

    @Test
    @DisplayName("可注入时钟：全模块统一的 Clock Bean 为 UTC")
    void clockBeanIsUtc() {
        assertEquals(ZoneOffset.UTC, clock.getZone());
    }

    @Test
    @DisplayName("唯一约束：users.username 不允许重复")
    void usernameIsUnique() {
        insertUser("u-dup-1", "dup_name");
        assertThrows(DuplicateKeyException.class, () -> insertUser("u-dup-2", "dup_name"));
    }

    @Test
    @DisplayName("唯一约束：answer_attempts.request_id 幂等键不允许重复")
    void requestIdIsUnique() {
        insertCaptureChain("uniq-req");
        insertAnswerAttempt("att-req-1", "uniq-req", "req-dup");
        assertThrows(DuplicateKeyException.class,
                () -> insertAnswerAttemptRow("att-req-2", "uniq-req", "req-dup"));
    }

    @Test
    @DisplayName("唯一约束：capture_records (user_id, spawn_id) 不允许同一遭遇重复收录")
    void captureRecordIsUniquePerUserAndSpawn() {
        insertCaptureChain("uniq-cap");
        insertCaptureRecord("rec-cap-1", "uniq-cap");
        assertThrows(DuplicateKeyException.class,
                () -> insertCaptureRecord("rec-cap-2", "uniq-cap"));
    }

    // ---- 测试数据准备：显式编号，不依赖种子数据 ----

    private void insertUser(String userId, String username) {
        jdbc.update("INSERT INTO users (user_id, username, password_hash, nickname, created_at)"
                        + " VALUES (?, ?, ?, ?, ?)",
                userId, username, "$2a$10$testhash", "测试用户", OffsetDateTime.now(ZoneOffset.UTC));
    }

    /** 插入 user → species → question → spawn → challenge 一整条外键链，编号统一带 tag。 */
    private void insertCaptureChain(String tag) {
        insertUser("user-" + tag, "name-" + tag);
        jdbc.update("INSERT INTO species (species_id, business_key, name) VALUES (?, ?, ?)",
                "species-" + tag, "bk-species-" + tag, "攻城狮");
        jdbc.update("INSERT INTO questions (question_id, species_id, business_key, question_text,"
                        + " options_json, correct_option_id) VALUES (?, ?, ?, ?, ?, ?)",
                "question-" + tag, "species-" + tag, "bk-question-" + tag, "题干",
                "[{\"optionId\":\"A\",\"text\":\"hello world\"}]", "A");
        jdbc.update("INSERT INTO spawns (spawn_id, user_id, species_id, region_id, source_type,"
                        + " expires_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
                "spawn-" + tag, "user-" + tag, "species-" + tag, "library_entrance",
                "DEV_SIMULATED", OffsetDateTime.now(ZoneOffset.UTC).plusHours(1),
                OffsetDateTime.now(ZoneOffset.UTC));
        jdbc.update("INSERT INTO challenges (challenge_id, spawn_id, question_id, status,"
                        + " expires_at, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                "challenge-" + tag, "spawn-" + tag, "question-" + tag, "OPEN",
                OffsetDateTime.now(ZoneOffset.UTC).plusHours(1),
                OffsetDateTime.now(ZoneOffset.UTC));
    }

    /** 经外键链正常插入一条作答记录。 */
    private void insertAnswerAttempt(String attemptId, String tag, String requestId) {
        insertAnswerAttemptRow(attemptId, tag, requestId);
    }

    private void insertAnswerAttemptRow(String attemptId, String tag, String requestId) {
        jdbc.update("INSERT INTO answer_attempts (attempt_id, challenge_id, request_id, option_id,"
                        + " result, submitted_at) VALUES (?, ?, ?, ?, ?, ?)",
                attemptId, "challenge-" + tag, requestId, "A", "WRONG",
                OffsetDateTime.now(ZoneOffset.UTC));
    }

    private void insertCaptureRecord(String recordId, String tag) {
        jdbc.update("INSERT INTO capture_records (record_id, user_id, species_id, spawn_id,"
                        + " challenge_id, captured_at) VALUES (?, ?, ?, ?, ?, ?)",
                recordId, "user-" + tag, "species-" + tag, "spawn-" + tag, "challenge-" + tag,
                OffsetDateTime.now(ZoneOffset.UTC));
    }
}
