package edu.pkmon.capture.repository.jdbc;

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
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

/**
 * capture 四个仓储接口的 JDBC 实现（胡豪，11/05 实现轮），对应 V1 迁移的
 * spawns / challenges / answer_attempts / capture_records 四表，接口签名不变。
 *
 * <p>V1 的 challenges / answer_attempts 不冗余 user_id 列，按用户查询时经
 * spawn 归属连接（challenge 1-1 spawn，spawn 属于用户）；capture_records.species_id
 * 在写入时由 spawn 带出，保证收录记录可独立于遭遇查询。</p>
 *
 * <p>唯一约束冲突统一翻译为 {@link DuplicateRecordException}，与内存实现一致，
 * 业务层的冲突处理路径不变。</p>
 */
public final class JdbcRepositories {

    private JdbcRepositories() {
    }

    /** 遭遇机会。created_at 由数据库写入，领域对象不携带。 */
    public static final class SpawnStore implements SpawnRepository {
        private final JdbcTemplate db;

        public SpawnStore(JdbcTemplate db) {
            this.db = db;
        }

        private static final RowMapper<Spawn> MAPPER = (rs, row) -> new Spawn(
                rs.getString("spawn_id"),
                rs.getString("user_id"),
                rs.getString("region_id"),
                rs.getString("species_id"),
                SpawnSourceType.valueOf(rs.getString("source_type")),
                rs.getObject("expires_at", OffsetDateTime.class).toInstant());

        @Override
        public Optional<Spawn> findById(String spawnId) {
            return db.query("select * from spawns where spawn_id = ?", MAPPER, spawnId)
                    .stream().findFirst();
        }

        @Override
        public Spawn save(Spawn spawn) {
            try {
                db.update("insert into spawns (spawn_id, user_id, species_id, region_id,"
                                + " source_type, expires_at, created_at)"
                                + " values (?,?,?,?,?,?,CURRENT_TIMESTAMP)",
                        spawn.spawnId(), spawn.userId(), spawn.speciesId(), spawn.regionId(),
                        spawn.sourceType().name(), utc(spawn.expiresAt()));
            } catch (DuplicateKeyException alreadyExists) {
                // 同一 spawnId 重复写入：遭遇创建只发生一次，沿用已有行
            }
            return spawn;
        }
    }

    /** 问答挑战。save 为 upsert：状态流转（CAPTURED/EXPIRED）靠更新落库。 */
    public static final class ChallengeStore implements ChallengeRepository {
        private final JdbcTemplate db;

        public ChallengeStore(JdbcTemplate db) {
            this.db = db;
        }

        private static final RowMapper<Challenge> MAPPER = (rs, row) -> new Challenge(
                rs.getString("challenge_id"),
                rs.getString("owner_id"),
                rs.getString("spawn_id"),
                rs.getString("question_id"),
                ChallengeStatus.valueOf(rs.getString("status")),
                rs.getObject("expires_at", OffsetDateTime.class).toInstant());

        private static final String SELECT_WITH_OWNER =
                "select c.*, s.user_id as owner_id from challenges c"
                        + " join spawns s on s.spawn_id = c.spawn_id";

        @Override
        public Optional<Challenge> findById(String challengeId) {
            return db.query(SELECT_WITH_OWNER + " where c.challenge_id = ?", MAPPER, challengeId)
                    .stream().findFirst();
        }

        @Override
        public Optional<Challenge> findOpenByUserAndSpawn(String userId, String spawnId) {
            return db.query(SELECT_WITH_OWNER
                            + " where s.user_id = ? and c.spawn_id = ? and c.status = 'OPEN'",
                    MAPPER, userId, spawnId).stream().findFirst();
        }

        @Override
        public Challenge save(Challenge challenge) {
            int updated = db.update("update challenges set status = ?, expires_at = ?"
                            + " where challenge_id = ?",
                    challenge.status().name(), utc(challenge.expiresAt()), challenge.challengeId());
            if (updated == 0) {
                try {
                    db.update("insert into challenges (challenge_id, spawn_id, question_id,"
                                    + " status, expires_at, created_at)"
                                    + " values (?,?,?,?,?,CURRENT_TIMESTAMP)",
                            challenge.challengeId(), challenge.spawnId(), challenge.questionId(),
                            challenge.status().name(), utc(challenge.expiresAt()));
                } catch (DuplicateKeyException conflict) {
                    // uk_challenges_spawn：同一遭遇已有挑战，并发下回查即可
                    db.update("update challenges set status = ?, expires_at = ?"
                                    + " where challenge_id = ?",
                            challenge.status().name(), utc(challenge.expiresAt()),
                            challenge.challengeId());
                }
            }
            return challenge;
        }
    }

    /** 作答尝试。requestId 全局唯一约束是幂等语义的兜底。 */
    public static final class AttemptStore implements AnswerAttemptRepository {
        private final JdbcTemplate db;

        public AttemptStore(JdbcTemplate db) {
            this.db = db;
        }

        private static final RowMapper<AnswerAttempt> MAPPER = (rs, row) -> new AnswerAttempt(
                rs.getString("attempt_id"),
                rs.getString("owner_id"),
                rs.getString("challenge_id"),
                rs.getString("request_id"),
                rs.getString("option_id"),
                AnswerResult.valueOf(rs.getString("result")),
                rs.getObject("submitted_at", OffsetDateTime.class).toInstant());

        private static final String SELECT_WITH_OWNER =
                "select a.*, s.user_id as owner_id from answer_attempts a"
                        + " join challenges c on c.challenge_id = a.challenge_id"
                        + " join spawns s on s.spawn_id = c.spawn_id";

        @Override
        public Optional<AnswerAttempt> findByUserAndRequestId(String userId, String requestId) {
            return db.query(SELECT_WITH_OWNER + " where s.user_id = ? and a.request_id = ?",
                    MAPPER, userId, requestId).stream().findFirst();
        }

        @Override
        public Optional<AnswerAttempt> findLatestByUserAndChallenge(String userId, String challengeId) {
            return db.query(SELECT_WITH_OWNER + " where s.user_id = ? and a.challenge_id = ?"
                            + " order by a.submitted_at desc limit 1",
                    MAPPER, userId, challengeId).stream().findFirst();
        }

        @Override
        public AnswerAttempt save(AnswerAttempt attempt) {
            try {
                db.update("insert into answer_attempts (attempt_id, challenge_id, request_id,"
                                + " option_id, result, submitted_at) values (?,?,?,?,?,?)",
                        attempt.attemptId(), attempt.challengeId(), attempt.requestId(),
                        attempt.optionId(), attempt.result().name(), utc(attempt.submittedAt()));
            } catch (DuplicateKeyException conflict) {
                throw new DuplicateRecordException("requestId 已存在: " + attempt.requestId());
            }
            return attempt;
        }
    }

    /** 收录记录。(userId, spawnId) 唯一约束保证同一遭遇不重复发奖。 */
    public static final class RecordStore implements CaptureRecordRepository {
        private final JdbcTemplate db;

        public RecordStore(JdbcTemplate db) {
            this.db = db;
        }

        private static final RowMapper<CaptureRecord> MAPPER = (rs, row) -> new CaptureRecord(
                rs.getString("record_id"),
                rs.getString("user_id"),
                rs.getString("spawn_id"),
                rs.getString("challenge_id"),
                rs.getObject("captured_at", OffsetDateTime.class).toInstant());

        @Override
        public Optional<CaptureRecord> findByUserAndSpawn(String userId, String spawnId) {
            return db.query("select * from capture_records where user_id = ? and spawn_id = ?",
                    MAPPER, userId, spawnId).stream().findFirst();
        }

        @Override
        public List<CaptureRecord> findByUser(String userId) {
            return db.query("select * from capture_records where user_id = ?"
                    + " order by captured_at", MAPPER, userId);
        }

        @Override
        public CaptureRecord save(CaptureRecord record) {
            try {
                int inserted = db.update("insert into capture_records (record_id, user_id,"
                                + " species_id, spawn_id, challenge_id, captured_at)"
                                + " select ?, ?, s.species_id, ?, ?, ? from spawns s"
                                + " where s.spawn_id = ?",
                        record.captureRecordId(), record.userId(), record.spawnId(),
                        record.challengeId(), utc(record.capturedAt()), record.spawnId());
                if (inserted == 0) {
                    throw new IllegalStateException("遭遇不存在，无法收录: " + record.spawnId());
                }
            } catch (DuplicateKeyException conflict) {
                throw new DuplicateRecordException(
                        "同一遭遇已收录: userId=" + record.userId() + ", spawnId=" + record.spawnId());
            }
            return record;
        }
    }

    private static OffsetDateTime utc(Instant time) {
        return time == null ? null : time.atOffset(ZoneOffset.UTC);
    }
}
