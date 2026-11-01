package edu.pkmon.study;

import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.study.domain.LocationSample;
import edu.pkmon.study.domain.PauseReason;
import edu.pkmon.study.domain.RejectionReason;
import edu.pkmon.study.domain.TaskStatus;
import edu.pkmon.study.dto.SampleResult;
import edu.pkmon.study.dto.TaskView;
import edu.pkmon.study.error.StudyExceptionHandler;
import edu.pkmon.study.error.TaskException;
import edu.pkmon.study.service.StudyTaskService;
import edu.pkmon.study.web.StudyController;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.Instant;
import java.util.Optional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 控制器层测试：字段校验、统一信封、业务错误映射。使用 standalone MockMvc 与假服务，
 * 不启动 Spring 上下文、不连数据库。
 */
class StudyControllerTest {

    private static final Instant NOW = Instant.parse("2026-11-01T02:00:00Z");
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        StudyTaskService service = new StudyTaskService() {
            @Override
            public TaskView startTask(String userId, String regionId, String requestId, String locationSource) {
                return new TaskView("task-1", regionId, TaskStatus.WAITING, null, 0, 60, null, NOW);
            }

            @Override
            public SampleResult submitSample(String userId, String taskId, LocationSample sample) {
                throw TaskException.stateConflict("任务已结束");
            }

            @Override
            public Optional<TaskView> currentTask(String userId) {
                return Optional.empty();
            }

            @Override
            public TaskView endTask(String userId, String taskId, String requestId) {
                return new TaskView(taskId, "library_entrance", TaskStatus.ENDED, null, 20, 60, null, NOW);
            }
        };
        CurrentUserProvider user = () -> "user-1";
        mvc = MockMvcBuilders.standaloneSetup(new StudyController(service, user))
                .setControllerAdvice(new StudyExceptionHandler())
                .build();
    }

    @Test
    @DisplayName("开始任务返回统一信封与 TaskView")
    void startTaskReturnsEnvelope() throws Exception {
        mvc.perform(post("/api/v1/study/tasks")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"regionId\":\"library_entrance\",\"requestId\":\"r-1\",\"locationSource\":\"GPS\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.taskId").value("task-1"))
                .andExpect(jsonPath("$.data.status").value("WAITING"))
                .andExpect(jsonPath("$.data.requiredSeconds").value(60));
    }

    @Test
    @DisplayName("缺少 requestId 返回 400 与 40001")
    void startTaskRejectsMissingRequestId() throws Exception {
        mvc.perform(post("/api/v1/study/tasks")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"regionId\":\"library_entrance\",\"locationSource\":\"GPS\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(40001));
    }

    @Test
    @DisplayName("sampledAt 非 ISO 8601 返回 40001")
    void sampleRejectsBadTimestamp() throws Exception {
        mvc.perform(post("/api/v1/study/tasks/task-1/samples")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"sampleId\":\"s-1\",\"latitude\":39.9,\"longitude\":116.4,"
                                + "\"accuracyMeters\":10,\"sampledAt\":\"2026/11/01 10:00\","
                                + "\"coordinateSystem\":\"GCJ02\",\"source\":\"GPS\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(40001));
    }

    @Test
    @DisplayName("任务已结束时提交样本返回 409 与 40903")
    void sampleOnEndedTaskReturnsConflict() throws Exception {
        mvc.perform(post("/api/v1/study/tasks/task-1/samples")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"sampleId\":\"s-1\",\"latitude\":39.9,\"longitude\":116.4,"
                                + "\"accuracyMeters\":10,\"sampledAt\":\"2026-11-01T02:00:10Z\","
                                + "\"coordinateSystem\":\"GCJ02\",\"source\":\"GPS\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value(40903));
    }

    @Test
    @DisplayName("没有活动任务时 data.task 为 null")
    void currentTaskIsNullWhenAbsent() throws Exception {
        mvc.perform(get("/api/v1/study/tasks/current"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.task").doesNotExist());
    }

    @Test
    @DisplayName("结束任务返回 ENDED 与最终时长")
    void endTaskReturnsEnded() throws Exception {
        mvc.perform(post("/api/v1/study/tasks/task-1/end")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requestId\":\"r-2\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ENDED"))
                .andExpect(jsonPath("$.data.effectiveSeconds").value(20));
    }

    @Test
    @DisplayName("拒绝原因与暂停原因按枚举名序列化")
    void enumsSerializeByName() throws Exception {
        StudyTaskService service = new StudyTaskService() {
            @Override
            public TaskView startTask(String userId, String regionId, String requestId, String locationSource) {
                return new TaskView("task-1", regionId, TaskStatus.PAUSED, PauseReason.NO_SIGNAL, 10, 60, null, NOW);
            }

            @Override
            public SampleResult submitSample(String userId, String taskId, LocationSample sample) {
                TaskView view = new TaskView(taskId, "library_entrance", TaskStatus.DWELLING, null, 20, 60, null, NOW);
                return new SampleResult(view, false, RejectionReason.LOW_ACCURACY);
            }

            @Override
            public Optional<TaskView> currentTask(String userId) {
                return Optional.empty();
            }

            @Override
            public TaskView endTask(String userId, String taskId, String requestId) {
                return new TaskView(taskId, "library_entrance", TaskStatus.ENDED, null, 0, 60, null, NOW);
            }
        };
        MockMvc local = MockMvcBuilders.standaloneSetup(new StudyController(service, () -> "user-1"))
                .setControllerAdvice(new StudyExceptionHandler())
                .build();
        local.perform(post("/api/v1/study/tasks/task-1/samples")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"sampleId\":\"s-1\",\"latitude\":39.9,\"longitude\":116.4,"
                                + "\"accuracyMeters\":60,\"sampledAt\":\"2026-11-01T02:00:10Z\","
                                + "\"coordinateSystem\":\"GCJ02\",\"source\":\"GPS\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sampleAccepted").value(false))
                .andExpect(jsonPath("$.data.rejectionReason").value("LOW_ACCURACY"));
    }
}
