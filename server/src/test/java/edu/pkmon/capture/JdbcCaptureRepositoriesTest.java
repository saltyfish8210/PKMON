package edu.pkmon.capture;

import edu.pkmon.capture.domain.AnswerAttempt;
import edu.pkmon.capture.domain.AnswerResult;
import edu.pkmon.capture.domain.CaptureRecord;
import edu.pkmon.capture.domain.Challenge;
import edu.pkmon.capture.domain.ChallengeStatus;
import edu.pkmon.capture.domain.Spawn;
import edu.pkmon.capture.domain.SpawnSourceType;
import edu.pkmon.capture.repository.DuplicateRecordException;
import edu.pkmon.capture.repository.Repositories.AnswerAttemptRepository;
import edu.pkmon.capture.repository.Repositories.CaptureRecordRepository;
import edu.pkmon.capture.repository.Repositories.ChallengeRepository;
import edu.pkmon.capture.repository.Repositories.SpawnRepository;
import edu.pkmon.demo.PkmonApplication;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * capture 四个 JDBC 仓储的验收（胡豪 11/05）：在独立测试库 pkmon_test 上强制启用 JDBC 实现，
 * 覆盖读写往返、归属隔离、幂等与收录唯一约束。题目/图鉴使用 V3 种子（siege_lion /
 * hello_world_001），用户用独立编号插入。时间使用固定 Instant，避免精度截断造成假失败。
 */
@SpringBootTest(classes = PkmonApplication.class)
@ActiveProfiles("test")
@TestPropertySource(properties = {
        "pkmon.capture.in-memory-store=false",
        "pkmon.study.in-memory-store=false"})
class JdbcCaptureRepositoriesTest {

    private static final Instant T0 = Instant.parse("2026-11-05T10:00:00Z");

    @Autowired
    private SpawnRepository spawns;

    @Autowired
    private ChallengeRepository challenges;

    @Autowired
    private AnswerAttemptRepository attempts;

    @Autowired
    private CaptureRecordRepository records;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    @DisplayName("遭遇读写往返：save 后 findById 可查，字段一致")
    void spawnRoundTrip() {
        insertUser("user-jdbc-cap-1");
        Spawn spawn = new Spawn("spawn-jdbc-cap-1", "user-jdbc-cap-1", "library_entrance",
                "siege_lion", SpawnSourceType.DEV_SIMULATED, T0.plusSeconds(3600));
        spawns.save(spawn);
        assertEquals(Optional.of(spawn), spawns.findById("spawn-jdbc-cap-1"));
    }

    @Test
    @DisplayName("挑战生命周期：新建可复用，CAPTURED 后不再出现在开放查询；按用户隔离")
    void challengeLifecycle() {
        insertUser("user-jdbc-cap-2");
        insertSpawn("spawn-jdbc-cap-2", "user-jdbc-cap-2");
        Challenge challenge = new Challenge("challenge-jdbc-cap-2", "user-jdbc-cap-2",
                "spawn-jdbc-cap-2", "hello_world_001", ChallengeStatus.OPEN, T0.plusSeconds(300));
        challenges.save(challenge);

        // Challenge 是普通类，逐字段比较而非对象相等
        Challenge loaded = challenges.findOpenByUserAndSpawn("user-jdbc-cap-2", "spawn-jdbc-cap-2")
                .orElseThrow();
        assertEquals(challenge.challengeId(), loaded.challengeId());
        assertEquals(challenge.userId(), loaded.userId());
        assertEquals(challenge.spawnId(), loaded.spawnId());
        assertEquals(challenge.questionId(), loaded.questionId());
        assertEquals(challenge.status(), loaded.status());
        assertEquals(challenge.expiresAt(), loaded.expiresAt());
        // 用户隔离：同一遭遇他人查不到
        assertTrue(challenges.findOpenByUserAndSpawn("user-jdbc-cap-other",
                "spawn-jdbc-cap-2").isEmpty());

        challenge.markCaptured();
        challenges.save(challenge);
        assertTrue(challenges.findOpenByUserAndSpawn("user-jdbc-cap-2",
                "spawn-jdbc-cap-2").isEmpty());
        assertEquals(ChallengeStatus.CAPTURED,
                challenges.findById("challenge-jdbc-cap-2").orElseThrow().status());
    }

    @Test
    @DisplayName("作答幂等：requestId 唯一约束翻译为 DuplicateRecordException，可按用户查回")
    void attemptIdempotency() {
        insertUser("user-jdbc-cap-3");
        insertSpawn("spawn-jdbc-cap-3", "user-jdbc-cap-3");
        insertChallenge("challenge-jdbc-cap-3", "spawn-jdbc-cap-3");

        AnswerAttempt attempt = new AnswerAttempt("attempt-jdbc-cap-3", "user-jdbc-cap-3",
                "challenge-jdbc-cap-3", "req-jdbc-cap-3", "A", AnswerResult.CORRECT, T0);
        attempts.save(attempt);

        assertEquals(Optional.of(attempt),
                attempts.findByUserAndRequestId("user-jdbc-cap-3", "req-jdbc-cap-3"));
        assertEquals(Optional.of(attempt),
                attempts.findLatestByUserAndChallenge("user-jdbc-cap-3", "challenge-jdbc-cap-3"));

        AnswerAttempt duplicate = new AnswerAttempt("attempt-jdbc-cap-3b", "user-jdbc-cap-3",
                "challenge-jdbc-cap-3", "req-jdbc-cap-3", "B", AnswerResult.WRONG,
                T0.plusSeconds(5));
        assertThrows(DuplicateRecordException.class, () -> attempts.save(duplicate));
    }

    @Test
    @DisplayName("收录唯一：speciesId 由遭遇带出；(userId, spawnId) 重复收录抛 DuplicateRecordException")
    void recordUniquePerUserAndSpawn() {
        insertUser("user-jdbc-cap-4");
        insertSpawn("spawn-jdbc-cap-4", "user-jdbc-cap-4");
        insertChallenge("challenge-jdbc-cap-4", "spawn-jdbc-cap-4");

        CaptureRecord record = new CaptureRecord("record-jdbc-cap-4", "user-jdbc-cap-4",
                "spawn-jdbc-cap-4", "challenge-jdbc-cap-4", T0);
        records.save(record);

        assertEquals(Optional.of(record),
                records.findByUserAndSpawn("user-jdbc-cap-4", "spawn-jdbc-cap-4"));
        assertEquals(1, records.findByUser("user-jdbc-cap-4").size());
        String speciesId = jdbc.queryForObject(
                "select species_id from capture_records where record_id = ?",
                String.class, "record-jdbc-cap-4");
        assertEquals("siege_lion", speciesId);

        CaptureRecord duplicate = new CaptureRecord("record-jdbc-cap-4b", "user-jdbc-cap-4",
                "spawn-jdbc-cap-4", "challenge-jdbc-cap-4", T0.plusSeconds(5));
        assertThrows(DuplicateRecordException.class, () -> records.save(duplicate));
        assertEquals(1, records.findByUser("user-jdbc-cap-4").size());
    }

    private void insertUser(String userId) {
        jdbc.update("insert into users (user_id, username, password_hash, nickname, created_at)"
                        + " values (?, ?, ?, ?, ?)",
                userId, "name-" + userId, "$2a$10$testhash", "测试用户",
                OffsetDateTime.now(ZoneOffset.UTC));
    }

    private void insertSpawn(String spawnId, String userId) {
        spawns.save(new Spawn(spawnId, userId, "library_entrance", "siege_lion",
                SpawnSourceType.DEV_SIMULATED, T0.plusSeconds(3600)));
    }

    private void insertChallenge(String challengeId, String spawnId) {
        jdbc.update("insert into challenges (challenge_id, spawn_id, question_id, status,"
                        + " expires_at, created_at) values (?, ?, ?, 'OPEN', ?, CURRENT_TIMESTAMP)",
                challengeId, spawnId, "hello_world_001", T0.plusSeconds(300).atOffset(ZoneOffset.UTC));
    }
}
