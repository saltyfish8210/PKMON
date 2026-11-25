package edu.pkmon.capture.repository;

import edu.pkmon.capture.domain.AnswerAttempt;
import edu.pkmon.capture.domain.CaptureRecord;
import edu.pkmon.capture.domain.Challenge;
import edu.pkmon.capture.domain.Spawn;

import java.util.List;
import java.util.Optional;

/**
 * 本模块四个仓储接口。
 * 真实持久化实现待公共依赖（spring-jdbc/jpa 与数据源，主责胡豪）到位后接入；
 * repository.memory 下的实现是替身，只用于开发联调与单元测试，不代表真实存储。
 */
public final class Repositories {

    private Repositories() {
    }

    public interface SpawnRepository {
        Optional<Spawn> findById(String spawnId);

        List<Spawn> activeFor(String userId, java.time.Instant now);

        Spawn save(Spawn spawn);
    }

    public interface ChallengeRepository {
        Optional<Challenge> findById(String challengeId);

        Optional<Challenge> findOpenByUserAndSpawn(String userId, String spawnId);

        List<String> recentQuestions(String userId);

        Challenge save(Challenge challenge);
    }

    public interface AnswerAttemptRepository {
        Optional<AnswerAttempt> findByUserAndRequestId(String userId, String requestId);

        Optional<AnswerAttempt> findLatestByUserAndChallenge(String userId, String challengeId);

        /** 违反 (userId, requestId) 唯一时抛 DuplicateRecordException。 */
        AnswerAttempt save(AnswerAttempt attempt);
    }

    public interface CaptureRecordRepository {
        Optional<CaptureRecord> findByUserAndSpawn(String userId, String spawnId);

        List<CaptureRecord> findByUser(String userId);

        /** 违反 (userId, spawnId) 唯一时抛 DuplicateRecordException。 */
        CaptureRecord save(CaptureRecord record);
    }
}
