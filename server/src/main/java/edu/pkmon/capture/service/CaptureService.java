package edu.pkmon.capture.service;

import edu.pkmon.capture.domain.AnswerAttempt;
import edu.pkmon.capture.domain.AnswerResult;
import edu.pkmon.capture.domain.CaptureRecord;
import edu.pkmon.capture.domain.Challenge;
import edu.pkmon.capture.domain.ChallengeStatus;
import edu.pkmon.capture.domain.Question;
import edu.pkmon.capture.domain.Spawn;
import edu.pkmon.capture.dto.CaptureDtos.AnswerResponse;
import edu.pkmon.capture.dto.CaptureDtos.ChallengeResponse;
import edu.pkmon.capture.dto.CaptureDtos.ChallengeStatusResponse;
import edu.pkmon.capture.dto.CaptureDtos.LastAttemptView;
import edu.pkmon.capture.dto.CaptureDtos.SubmitAnswerCommand;
import edu.pkmon.capture.error.ApiErrorCode;
import edu.pkmon.capture.error.ApiException;
import edu.pkmon.capture.port.QuestionSource;
import edu.pkmon.capture.port.SpeciesCatalog;
import edu.pkmon.capture.repository.DuplicateRecordException;
import edu.pkmon.capture.repository.Repositories.AnswerAttemptRepository;
import edu.pkmon.capture.repository.Repositories.CaptureRecordRepository;
import edu.pkmon.capture.repository.Repositories.ChallengeRepository;
import edu.pkmon.capture.repository.Repositories.SpawnRepository;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * 答题捕获的核心业务。判定次序固定为：归属校验 → 幂等判定 → 有效性判定 → 结算。
 * 次序不得改动，理由见 design/design.txt 4.2 与 analysis/analysis.txt 5.3。
 *
 * 事务说明：submit 已加 @Transactional（胡豪 11/05，spring-tx 随数据源就绪），
 * 作答记录、收录记录、挑战状态在同一事务提交；任一写失败整体回滚，不落半截结算。
 */
@Service
public class CaptureService {

    static final Duration CHALLENGE_TTL = Duration.ofMinutes(5);

    private final Clock clock;
    private final SpawnRepository spawns;
    private final ChallengeRepository challenges;
    private final AnswerAttemptRepository attempts;
    private final CaptureRecordRepository records;
    private final QuestionSource questions;
    private final SpeciesCatalog species;

    public CaptureService(Clock clock, SpawnRepository spawns, ChallengeRepository challenges,
                          AnswerAttemptRepository attempts, CaptureRecordRepository records,
                          QuestionSource questions, SpeciesCatalog species) {
        this.clock = clock;
        this.spawns = spawns;
        this.challenges = challenges;
        this.attempts = attempts;
        this.records = records;
        this.questions = questions;
        this.species = species;
    }

    /** 取题：已收录则拒绝；已有未过期挑战则复用，不新建。 */
    public ChallengeResponse startChallenge(String userId, String spawnId) {
        Spawn spawn = requireUsableSpawn(userId, spawnId);
        Instant now = clock.instant();

        if (records.findByUserAndSpawn(userId, spawn.spawnId()).isPresent()) {
            throw new ApiException(ApiErrorCode.ALREADY_CAPTURED);
        }

        Optional<Challenge> reusable = challenges.findOpenByUserAndSpawn(userId, spawn.spawnId());
        if (reusable.isPresent()) {
            Challenge existing = reusable.get();
            if (existing.openAt(now)) {
                return toChallengeResponse(existing, spawn);
            }
            existing.markExpired();
            challenges.save(existing);
        }

        Question question = questions.findBySpeciesId(spawn.speciesId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.QUESTION_UNAVAILABLE));
        Challenge challenge = new Challenge(UUID.randomUUID().toString(), userId, spawn.spawnId(),
                question.questionId(), ChallengeStatus.OPEN, now.plus(CHALLENGE_TTL));
        challenges.save(challenge);
        return toChallengeResponse(challenge, spawn);
    }

    /** 提交作答。四步次序见类注释。 */
    @org.springframework.transaction.annotation.Transactional
    public AnswerResponse submit(String userId, SubmitAnswerCommand cmd) {
        if (cmd == null || isBlank(cmd.challengeId()) || isBlank(cmd.requestId())
                || isBlank(cmd.optionId())) {
            throw new ApiException(ApiErrorCode.INVALID_PARAM,
                    "challengeId、requestId、optionId 均不能为空");
        }

        // 第一步 归属校验
        Challenge challenge = challenges.findById(cmd.challengeId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND));
        if (!challenge.userId().equals(userId)) {
            throw new ApiException(ApiErrorCode.NOT_FOUND);
        }

        // 第二步 幂等判定（必须先于过期判定）
        Optional<AnswerAttempt> prior = attempts.findByUserAndRequestId(userId, cmd.requestId());
        if (prior.isPresent()) {
            return replay(userId, challenge, prior.get(), cmd);
        }

        // 第三步 有效性判定
        Spawn spawn = spawns.findById(challenge.spawnId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND));
        Instant now = clock.instant();
        if (challenge.expiredAt(now)) {
            if (challenge.status() == ChallengeStatus.OPEN) {
                challenge.markExpired();
                challenges.save(challenge);
            }
            throw new ApiException(ApiErrorCode.EXPIRED, "挑战已过期，请重新遭遇");
        }
        Question question = questions.findBySpeciesId(spawn.speciesId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.QUESTION_UNAVAILABLE));
        if (!question.hasOption(cmd.optionId())) {
            throw new ApiException(ApiErrorCode.INVALID_PARAM, "选项不属于该题");
        }

        // 第四步 结算
        if (question.isCorrect(cmd.optionId())) {
            CaptureRecord record = createOrReuseRecord(userId, challenge, now);
            challenge.markCaptured();
            challenges.save(challenge);
            recordAttempt(userId, challenge, cmd, AnswerResult.CORRECT, now);
            return new AnswerResponse(challenge.challengeId(), cmd.requestId(),
                    AnswerResult.CORRECT.name(), record.captureRecordId(), spawn.speciesId());
        }

        recordAttempt(userId, challenge, cmd, AnswerResult.WRONG, now);
        return new AnswerResponse(challenge.challengeId(), cmd.requestId(),
                AnswerResult.WRONG.name(), null, spawn.speciesId());
    }

    /** 状态查询：只读；顺带做惰性过期落库。 */
    public ChallengeStatusResponse status(String userId, String challengeId) {
        Challenge challenge = challenges.findById(challengeId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND));
        if (!challenge.userId().equals(userId)) {
            throw new ApiException(ApiErrorCode.NOT_FOUND);
        }
        if (challenge.status() == ChallengeStatus.OPEN && challenge.expiredAt(clock.instant())) {
            challenge.markExpired();
            challenges.save(challenge);
        }
        String captureRecordId = records.findByUserAndSpawn(userId, challenge.spawnId())
                .map(CaptureRecord::captureRecordId).orElse(null);
        LastAttemptView lastAttempt = attempts
                .findLatestByUserAndChallenge(userId, challengeId)
                .map(LastAttemptView::from)
                .orElse(null);
        return new ChallengeStatusResponse(challenge.challengeId(), challenge.status().name(),
                captureRecordId, challenge.expiresAt(), lastAttempt);
    }

    private AnswerResponse replay(String userId, Challenge challenge, AnswerAttempt prior,
                                  SubmitAnswerCommand cmd) {
        if (!prior.optionId().equals(cmd.optionId())) {
            throw new ApiException(ApiErrorCode.CONFLICT_REQUEST,
                    "同一 requestId 已提交过不同选项");
        }
        String captureRecordId = records.findByUserAndSpawn(userId, challenge.spawnId())
                .map(CaptureRecord::captureRecordId).orElse(null);
        String speciesId = spawns.findById(challenge.spawnId())
                .map(Spawn::speciesId).orElse(null);
        return new AnswerResponse(challenge.challengeId(), prior.requestId(),
                prior.result().name(), captureRecordId, speciesId);
    }

    /** 唯一约束冲突时回查已有记录并沿用，不重复发奖。 */
    private CaptureRecord createOrReuseRecord(String userId, Challenge challenge, Instant now) {
        Optional<CaptureRecord> existing = records.findByUserAndSpawn(userId, challenge.spawnId());
        if (existing.isPresent()) {
            return existing.get();
        }
        try {
            return records.save(new CaptureRecord(UUID.randomUUID().toString(), userId,
                    challenge.spawnId(), challenge.challengeId(), now));
        } catch (DuplicateRecordException conflict) {
            return records.findByUserAndSpawn(userId, challenge.spawnId())
                    .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND));
        }
    }

    /** 并发下同一 requestId 已被另一线程写入时，按“同一内容”处理，不重复记录。 */
    private void recordAttempt(String userId, Challenge challenge, SubmitAnswerCommand cmd,
                               AnswerResult result, Instant now) {
        try {
            attempts.save(new AnswerAttempt(UUID.randomUUID().toString(), userId,
                    challenge.challengeId(), cmd.requestId(), cmd.optionId(), result, now));
        } catch (DuplicateRecordException alreadyRecorded) {
            attempts.findByUserAndRequestId(userId, cmd.requestId())
                    .filter(existing -> existing.optionId().equals(cmd.optionId()))
                    .orElseThrow(() -> new ApiException(ApiErrorCode.CONFLICT_REQUEST));
        }
    }

    private ChallengeResponse toChallengeResponse(Challenge challenge, Spawn spawn) {
        Question question = questions.findBySpeciesId(spawn.speciesId())
                .orElseThrow(() -> new ApiException(ApiErrorCode.QUESTION_UNAVAILABLE));
        String speciesName = species.nameOf(spawn.speciesId()).orElse(spawn.speciesId());
        return ChallengeResponse.of(challenge, spawn, speciesName, question);
    }

    private Spawn requireUsableSpawn(String userId, String spawnId) {
        Spawn spawn = isBlank(spawnId) ? null : spawns.findById(spawnId).orElse(null);
        if (spawn == null || !spawn.userId().equals(userId)) {
            throw new ApiException(ApiErrorCode.NOT_FOUND);
        }
        if (!spawn.usableAt(clock.instant())) {
            throw new ApiException(ApiErrorCode.EXPIRED, "遭遇已过期，请重新遭遇");
        }
        return spawn;
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
