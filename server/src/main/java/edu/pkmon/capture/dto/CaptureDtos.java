package edu.pkmon.capture.dto;

import edu.pkmon.capture.domain.AnswerAttempt;
import edu.pkmon.capture.domain.Challenge;
import edu.pkmon.capture.domain.Question;
import edu.pkmon.capture.domain.Spawn;

import java.time.Instant;
import java.util.List;

/** 传输结构集合。对外 DTO 不含任何答案字段。 */
public final class CaptureDtos {

    private CaptureDtos() {
    }

    public record ApiEnvelope(int code, String message, Object data) {

        public static ApiEnvelope ok(Object data) {
            return new ApiEnvelope(0, "ok", data);
        }

        public static ApiEnvelope error(int code, String message) {
            return new ApiEnvelope(code, message, null);
        }
    }

    public record CreateSpawnRequest(String regionId, String speciesId) {
    }

    public record SpawnResponse(String spawnId, String regionId, String speciesId,
                                String sourceType, Instant expiresAt) {

        public static SpawnResponse from(Spawn spawn) {
            return new SpawnResponse(spawn.spawnId(), spawn.regionId(), spawn.speciesId(),
                    spawn.sourceType().name(), spawn.expiresAt());
        }
    }

    public record StartChallengeRequest(String spawnId) {
    }

    public record OptionView(String optionId, String text) {
    }

    public record ChallengeResponse(String challengeId, String spawnId, String speciesId,
                                    String speciesName, String questionId, String questionText,
                                    List<OptionView> options, Instant expiresAt, String sourceType) {

        public static ChallengeResponse of(Challenge challenge, Spawn spawn, String speciesName,
                                           Question question) {
            List<OptionView> views = question.options().stream()
                    .map(o -> new OptionView(o.optionId(), o.text()))
                    .toList();
            return new ChallengeResponse(challenge.challengeId(), spawn.spawnId(), spawn.speciesId(),
                    speciesName, question.questionId(), question.questionText(), views,
                    challenge.expiresAt(), spawn.sourceType().name());
        }
    }

    public record SubmitAnswerRequest(String challengeId, String requestId, String optionId) {
    }

    public record SubmitAnswerCommand(String challengeId, String requestId, String optionId) {
    }

    public record AnswerResponse(String challengeId, String requestId, String result,
                                 String captureRecordId, String speciesId) {
    }

    public record LastAttemptView(String requestId, String result, Instant submittedAt) {

        public static LastAttemptView from(AnswerAttempt attempt) {
            return attempt == null ? null
                    : new LastAttemptView(attempt.requestId(), attempt.result().name(),
                            attempt.submittedAt());
        }
    }

    public record ChallengeStatusResponse(String challengeId, String status, String captureRecordId,
                                          Instant expiresAt, LastAttemptView lastAttempt) {
    }

    public record CollectionSummaryResponse(int collectedSpeciesCount, int totalSpeciesCount,
                                            int captureCount) {
    }
}
