package edu.pkmon.study;

import edu.pkmon.demo.PkmonApplication;
import edu.pkmon.study.domain.DwellState;
import edu.pkmon.study.domain.LocationSample;
import edu.pkmon.study.domain.Region;
import edu.pkmon.study.domain.RejectionReason;
import edu.pkmon.study.domain.StudyTask;
import edu.pkmon.study.domain.TaskStatus;
import edu.pkmon.study.port.TaskRepository;
import edu.pkmon.study.repository.JdbcTaskRepository;
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
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * JdbcTaskRepository 验收（胡豪 11/05）：在独立测试库 pkmon_test 上强制启用 JDBC 实现，
 * 覆盖建库迁移后的读写往返、幂等约束、结束与冷却查询、样本落库。
 * 各用例编号互不相同，与同库其他测试互不干扰。时间使用固定 Instant，避免精度截断造成假失败。
 */
@SpringBootTest(classes = PkmonApplication.class)
@ActiveProfiles("test")
@TestPropertySource(properties = {
        "pkmon.study.in-memory-store=false",
        "pkmon.capture.in-memory-store=false"})
class JdbcTaskRepositoryTest {

    private static final Instant T0 = Instant.parse("2026-11-05T10:00:00Z");

    @Autowired
    private TaskRepository repository;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    @DisplayName("装配：pkmon.study.in-memory-store=false 时使用 JDBC 实现")
    void jdbcImplementationWired() {
        assertTrue(repository instanceof JdbcTaskRepository,
                "应为 JDBC 实现，实际：" + repository.getClass());
    }

    @Test
    @DisplayName("区域：V2 种子提供 library_entrance，半径 80/100 且启用")
    void regionFromSeed() {
        Optional<Region> region = repository.findRegion("library_entrance");
        assertTrue(region.isPresent());
        assertEquals(80.0, region.get().enterRadiusMeters());
        assertEquals(100.0, region.get().exitRadiusMeters());
        assertTrue(region.get().enabled());
    }

    @Test
    @DisplayName("任务读写往返：insert 后 findById / findActiveByUser / findByStartRequest 均可查")
    void taskRoundTrip() {
        insertUser("user-jdbc-study-1");
        StudyTask task = newTask("task-jdbc-study-1", "user-jdbc-study-1", "req-jdbc-study-1");
        repository.insert(task);

        assertEquals(Optional.of(task), repository.findById("task-jdbc-study-1"));
        assertEquals(Optional.of(task), repository.findActiveByUser("user-jdbc-study-1"));
        assertEquals(Optional.of(task),
                repository.findByStartRequest("user-jdbc-study-1", "req-jdbc-study-1"));
        // 用户隔离：他人查不到
        assertTrue(repository.findActiveByUser("user-jdbc-study-other").isEmpty());
    }

    @Test
    @DisplayName("幂等约束：(userId, startRequestId) 重复开始沿用已有任务，不抛异常不新建")
    void duplicateStartRequestReused() {
        insertUser("user-jdbc-study-2");
        StudyTask first = newTask("task-jdbc-study-2a", "user-jdbc-study-2", "req-jdbc-study-2");
        repository.insert(first);

        StudyTask duplicate = newTask("task-jdbc-study-2b", "user-jdbc-study-2", "req-jdbc-study-2");
        StudyTask result = repository.insert(duplicate);

        assertEquals(first.taskId(), result.taskId());
        assertEquals(Optional.of(first), repository.findActiveByUser("user-jdbc-study-2"));
        assertTrue(repository.findById("task-jdbc-study-2b").isEmpty());
    }

    @Test
    @DisplayName("结束与冷却：save 落库 ENDED 后不再算活动任务，findLatestEnded 可查")
    void endAndCooldownQueries() {
        insertUser("user-jdbc-study-3");
        StudyTask task = newTask("task-jdbc-study-3", "user-jdbc-study-3", "req-jdbc-study-3");
        repository.insert(task);

        // 与 service 行为一致：状态推进到 ENDED 且记录 endedAt（StudyTask.end 只写 endedAt）
        StudyTask ended = task.withState(task.state().ended()).end(T0.plusSeconds(600));
        repository.save(ended);

        assertTrue(repository.findActiveByUser("user-jdbc-study-3").isEmpty());
        Optional<StudyTask> latest = repository.findLatestEnded("user-jdbc-study-3", "library_entrance");
        assertTrue(latest.isPresent());
        assertEquals("task-jdbc-study-3", latest.get().taskId());
        assertEquals(TaskStatus.ENDED, latest.get().state().status());
        assertEquals(T0.plusSeconds(600), latest.get().endedAt());
    }

    @Test
    @DisplayName("样本落库：采纳与拒收都记录；(taskId, sampleId) 重复写入只留一条")
    void sampleRoundTripAndDuplicate() {
        insertUser("user-jdbc-study-4");
        StudyTask task = newTask("task-jdbc-study-4", "user-jdbc-study-4", "req-jdbc-study-4");
        repository.insert(task);

        LocationSample accepted = new LocationSample("sample-jdbc-study-4a",
                39.9042, 116.4074, 10.0, T0.plusSeconds(10), "GCJ02", "SIMULATED");
        repository.saveSample(task.taskId(), accepted, true, null);
        assertEquals(Optional.of(accepted), repository.findSample(task.taskId(), "sample-jdbc-study-4a"));

        LocationSample rejected = new LocationSample("sample-jdbc-study-4b",
                39.9042, 116.4074, 80.0, T0.plusSeconds(20), "GCJ02", "SIMULATED");
        repository.saveSample(task.taskId(), rejected, false, RejectionReason.LOW_ACCURACY);

        // 重复写入同一样本编号：不抛异常，仍只有一条
        repository.saveSample(task.taskId(), accepted, true, null);
        Integer count = jdbc.queryForObject(
                "select count(*) from location_samples where task_id = ?", Integer.class, task.taskId());
        assertEquals(2, count.intValue());
        String reason = jdbc.queryForObject(
                "select rejection_reason from location_samples where task_id = ? and sample_id = ?",
                String.class, task.taskId(), "sample-jdbc-study-4b");
        assertEquals("LOW_ACCURACY", reason);
        assertFalse(reason == null);
    }

    private StudyTask newTask(String taskId, String userId, String requestId) {
        return new StudyTask(taskId, userId, "library_entrance", requestId, "SIMULATED",
                DwellState.start(taskId, 600), T0, null, null);
    }

    private void insertUser(String userId) {
        jdbc.update("insert into users (user_id, username, password_hash, nickname, created_at)"
                        + " values (?, ?, ?, ?, ?)",
                userId, "name-" + userId, "$2a$10$testhash", "测试用户",
                OffsetDateTime.now(ZoneOffset.UTC));
    }
}
