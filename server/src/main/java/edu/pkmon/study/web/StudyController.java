package edu.pkmon.study.web;

import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.common.api.ApiResponse;
import edu.pkmon.study.domain.LocationSample;
import edu.pkmon.study.dto.SampleResult;
import edu.pkmon.study.dto.StudyDtos.CurrentTaskResponse;
import edu.pkmon.study.dto.StudyDtos.EndTaskRequest;
import edu.pkmon.study.dto.StudyDtos.SampleRequest;
import edu.pkmon.study.dto.StudyDtos.SampleResponse;
import edu.pkmon.study.dto.StudyDtos.StartTaskRequest;
import edu.pkmon.study.dto.TaskView;
import edu.pkmon.study.error.TaskException;
import edu.pkmon.study.service.StudyTaskService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.time.format.DateTimeParseException;

/**
 * 自习任务接口：开始、提交样本、查询当前、结束。
 *
 * <p>userId 只从 {@link CurrentUserProvider} 取得，任何请求体都不接受 userId；业务判断全部在
 * {@link StudyTaskService}，本类只做字段校验、时间解析与错误映射。</p>
 */
@RestController
@RequestMapping("/api/v1/study")
public class StudyController {

    private final StudyTaskService studyTaskService;
    private final CurrentUserProvider currentUser;

    /**
     * @param studyTaskService 任务服务
     * @param currentUser 当前用户端口（认证接入前由开发期请求头替身提供）
     */
    public StudyController(StudyTaskService studyTaskService, CurrentUserProvider currentUser) {
        this.studyTaskService = studyTaskService;
        this.currentUser = currentUser;
    }

    /**
     * 开始自习任务。
     *
     * @param request 区域、请求号与位置来源
     * @return 任务视图
     */
    @PostMapping("/tasks")
    public ApiResponse<TaskView> startTask(@RequestBody StartTaskRequest request) {
        String userId = currentUser.currentUserId();
        require(request.regionId(), "regionId");
        require(request.requestId(), "requestId");
        require(request.locationSource(), "locationSource");
        return ApiResponse.ok(studyTaskService.startTask(userId, request.regionId(),
                request.requestId(), request.locationSource()));
    }

    /**
     * 提交一条位置样本。
     *
     * @param taskId 任务编号
     * @param request 样本字段
     * @return 任务视图加样本采纳结果
     */
    @PostMapping("/tasks/{taskId}/samples")
    public ApiResponse<SampleResponse> submitSample(@PathVariable String taskId,
            @RequestBody SampleRequest request) {
        String userId = currentUser.currentUserId();
        LocationSample sample = toSample(request);
        SampleResult result = studyTaskService.submitSample(userId, taskId, sample);
        return ApiResponse.ok(SampleResponse.of(result.task(), result.sampleAccepted(),
                result.rejectionReason()));
    }

    /**
     * 查询当前活动任务；没有活动任务时 task 为 null。
     *
     * @return 当前任务
     */
    @GetMapping("/tasks/current")
    public ApiResponse<CurrentTaskResponse> currentTask() {
        String userId = currentUser.currentUserId();
        return ApiResponse.ok(new CurrentTaskResponse(studyTaskService.currentTask(userId).orElse(null)));
    }

    /**
     * 结束任务。
     *
     * @param taskId 任务编号
     * @param request 结束请求号
     * @return 最终任务视图
     */
    @PostMapping("/tasks/{taskId}/end")
    public ApiResponse<TaskView> endTask(@PathVariable String taskId, @RequestBody EndTaskRequest request) {
        String userId = currentUser.currentUserId();
        require(request.requestId(), "requestId");
        return ApiResponse.ok(studyTaskService.endTask(userId, taskId, request.requestId()));
    }

    private static LocationSample toSample(SampleRequest request) {
        require(request.sampleId(), "sampleId");
        require(request.sampledAt(), "sampledAt");
        require(request.coordinateSystem(), "coordinateSystem");
        require(request.source(), "source");
        if (request.latitude() == null || request.longitude() == null || request.accuracyMeters() == null) {
            throw TaskException.badRequest("latitude、longitude、accuracyMeters 不能为空");
        }
        Instant sampledAt;
        try {
            sampledAt = Instant.parse(request.sampledAt());
        } catch (DateTimeParseException e) {
            throw TaskException.badRequest("sampledAt 必须是 ISO 8601 UTC，例如 2026-11-01T02:00:10Z");
        }
        try {
            return new LocationSample(request.sampleId(), request.latitude(), request.longitude(),
                    request.accuracyMeters(), sampledAt, request.coordinateSystem(), request.source());
        } catch (IllegalArgumentException e) {
            throw TaskException.badRequest(e.getMessage());
        }
    }

    private static void require(String value, String field) {
        if (value == null || value.isBlank()) {
            throw TaskException.badRequest(field + " 不能为空");
        }
    }
}
