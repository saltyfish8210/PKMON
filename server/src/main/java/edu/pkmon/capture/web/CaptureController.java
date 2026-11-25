package edu.pkmon.capture.web;

import edu.pkmon.capture.dto.CaptureDtos.AnswerResponse;
import edu.pkmon.capture.dto.CaptureDtos.ApiEnvelope;
import edu.pkmon.capture.dto.CaptureDtos.ChallengeResponse;
import edu.pkmon.capture.dto.CaptureDtos.ChallengeStatusResponse;
import edu.pkmon.capture.dto.CaptureDtos.StartChallengeRequest;
import edu.pkmon.capture.dto.CaptureDtos.SubmitAnswerCommand;
import edu.pkmon.capture.dto.CaptureDtos.SubmitAnswerRequest;
import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.capture.service.CaptureService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 取题、作答、状态查询。userId 只从 CurrentUserProvider 取得，不接受请求体传入。 */
@RestController
@RequestMapping("/api/v1/capture")
public class CaptureController {

    private final CaptureService captureService;
    private final CurrentUserProvider currentUser;

    public CaptureController(CaptureService captureService, CurrentUserProvider currentUser) {
        this.captureService = captureService;
        this.currentUser = currentUser;
    }

    @PostMapping("/challenge")
    public ApiEnvelope startChallenge(@RequestBody StartChallengeRequest request) {
        String userId = currentUser.currentUserId();
        ChallengeResponse response = captureService.startChallenge(userId, request.spawnId());
        return ApiEnvelope.ok(response);
    }

    @PostMapping("/answer")
    public ApiEnvelope submitAnswer(@RequestBody SubmitAnswerRequest request) {
        String userId = currentUser.currentUserId();
        AnswerResponse response = captureService.submit(userId,
                new SubmitAnswerCommand(request.challengeId(), request.requestId(),
                        request.optionId()));
        return ApiEnvelope.ok(response);
    }

    public record StatusRequest(String challengeId) {}

    @PostMapping("/status")
    public ApiEnvelope status(@RequestBody StatusRequest request) {
        if (request.challengeId() == null || request.challengeId().isBlank()) throw new IllegalArgumentException("challengeId 不能为空");
        return status(request.challengeId());
    }

    @GetMapping("/challenges/{challengeId}")
    public ApiEnvelope status(@PathVariable String challengeId) {
        String userId = currentUser.currentUserId();
        ChallengeStatusResponse response = captureService.status(userId, challengeId);
        return ApiEnvelope.ok(response);
    }
}
