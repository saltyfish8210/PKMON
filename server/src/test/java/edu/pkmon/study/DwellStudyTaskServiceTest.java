package edu.pkmon.study;

import edu.pkmon.study.domain.*;
import edu.pkmon.study.dto.*;
import edu.pkmon.study.error.*;
import edu.pkmon.study.port.*;
import edu.pkmon.study.service.*;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 任务服务测试：用内存存储替身和遭遇替身验证幂等、冷却与一次性触发。
 */
class DwellStudyTaskServiceTest {

    private static final Instant BASE = Instant.parse("2026-10-19T02:00:00Z");
    private static final String USER = "user-1";

    private MutableClock clock;
    private InMemoryTaskRepository repository;
    private CountingSpawnGateway spawnGateway;
    private DwellStudyTaskService service;

    @BeforeEach
    void setUp() {
        clock = new MutableClock(BASE);
        DwellRules rules = DwellRules.testRules();
        repository = new InMemoryTaskRepository(Region.of("library_entrance", 39.9042, 116.4074, rules));
        spawnGateway = new CountingSpawnGateway();
        service = new DwellStudyTaskService(repository, spawnGateway, new DwellEvaluator(rules), clock);
    }

    private LocationSample sample(String id, long seconds, double metersNorth) {
        return new LocationSample(id, Geo.latitudeOffset(39.9042, metersNorth), 116.4074, 10,
                BASE.plusSeconds(seconds), "GCJ02", "GPS");
    }

    @Test
    @DisplayName("开始任务创建 WAITING 记录，重复开始返回同一任务")
    void startIsIdempotent() {
        TaskView first = service.startTask(USER, "library_entrance", UUID.randomUUID().toString(), "GPS");
        clock.advanceSeconds(5);
        TaskView second = service.startTask(USER, "library_entrance", UUID.randomUUID().toString(), "GPS");

        assertEquals(TaskStatus.WAITING, first.status());
        assertEquals(60, first.requiredSeconds());
        assertEquals(first.taskId(), second.taskId());
    }

    @Test
    @DisplayName("结束任务幂等，结束后进入冷却期并拒绝重新开始")
    void endIsIdempotentAndCoolDownApplies() {
        TaskView task = service.startTask(USER, "library_entrance", "req-start", "GPS");
        TaskView ended = service.endTask(USER, task.taskId(), "req-end");
        TaskView endedAgain = service.endTask(USER, task.taskId(), "req-end-2");

        assertEquals(TaskStatus.ENDED, ended.status());
        assertEquals(ended.status(), endedAgain.status());
        assertTrue(service.currentTask(USER).isEmpty());

        TaskException cooling = assertThrows(TaskException.class,
                () -> service.startTask(USER, "library_entrance", "req-start-2", "GPS"));
        assertEquals(40904, cooling.code());

        clock.advanceSeconds(1800);
        TaskView restarted = service.startTask(USER, "library_entrance", "req-start-3", "GPS");
        assertFalse(restarted.taskId().equals(task.taskId()));
    }

    @Test
    @DisplayName("达到阈值只创建一个遭遇，后续样本不再触发")
    void triggerCreatesExactlyOneSpawn() {
        TaskView task = service.startTask(USER, "library_entrance", "req-start", "GPS");
        long[] times = {0, 10, 20, 30, 40, 50, 60, 69, 70, 80, 90};
        TaskView last = task;
        for (int i = 0; i < times.length; i++) {
            clock.set(BASE.plusSeconds(times[i]));
            SampleResult result = service.submitSample(USER, task.taskId(), sample("s" + i, times[i], 0));
            last = result.task();
        }

        assertEquals(TaskStatus.TRIGGERED, last.status());
        assertEquals(60, last.effectiveSeconds());
        assertNotNull(last.spawnId());
        assertEquals(1, spawnGateway.created);
    }

    @Test
    @DisplayName("重复 sampleId 内容一致返回 accepted=false，内容不同返回 40902")
    void duplicateSampleIdIsIdempotentOrConflicts() {
        TaskView task = service.startTask(USER, "library_entrance", "req-start", "GPS");
        clock.set(BASE.plusSeconds(10));
        SampleResult first = service.submitSample(USER, task.taskId(), sample("dup", 10, 0));
        SampleResult replay = service.submitSample(USER, task.taskId(), sample("dup", 10, 0));

        assertTrue(first.sampleAccepted());
        assertFalse(replay.sampleAccepted());
        assertEquals(RejectionReason.DUPLICATE_SAMPLE, replay.rejectionReason());

        TaskException conflict = assertThrows(TaskException.class,
                () -> service.submitSample(USER, task.taskId(), sample("dup", 20, 0)));
        assertEquals(40902, conflict.code());
    }

    @Test
    @DisplayName("查询当前任务时按注入时钟推进失联暂停")
    void currentTaskAdvancesNoSignal() {
        TaskView task = service.startTask(USER, "library_entrance", "req-start", "GPS");
        service.submitSample(USER, task.taskId(), sample("a", 0, 0));
        service.submitSample(USER, task.taskId(), sample("b", 10, 0));
        clock.set(BASE.plusSeconds(41));

        TaskView current = service.currentTask(USER).orElseThrow();
        assertEquals(TaskStatus.PAUSED, current.status());
        assertEquals(PauseReason.NO_SIGNAL, current.pauseReason());
    }

    @Test
    @DisplayName("他人的任务不可见，返回 40401")
    void otherUserTaskIsNotFound() {
        TaskView task = service.startTask(USER, "library_entrance", "req-start", "GPS");
        TaskException notFound = assertThrows(TaskException.class,
                () -> service.submitSample("user-2", task.taskId(), sample("x", 0, 0)));
        assertEquals(40401, notFound.code());
        assertNull(repository.findActiveByUser("user-2").orElse(null));
    }

    /** 可手动推进的时钟替身。 */
    static final class MutableClock extends Clock {
        private Instant current;

        MutableClock(Instant start) {
            this.current = start;
        }

        void set(Instant instant) {
            this.current = instant;
        }

        void advanceSeconds(long seconds) {
            this.current = current.plusSeconds(seconds);
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return current;
        }
    }

    /** 内存存储替身，只实现规则测试需要的行为。 */
    static final class InMemoryTaskRepository implements TaskRepository {
        private final Map<String, StudyTask> tasks = new HashMap<>();
        private final Map<String, Map<String, LocationSample>> samples = new HashMap<>();
        private final Region region;

        InMemoryTaskRepository(Region region) {
            this.region = region;
        }

        @Override
        public Optional<StudyTask> findActiveByUser(String userId) {
            return tasks.values().stream()
                    .filter(t -> t.userId().equals(userId) && t.state().isActive())
                    .findFirst();
        }

        @Override
        public Optional<StudyTask> findById(String taskId) {
            return Optional.ofNullable(tasks.get(taskId));
        }

        @Override
        public Optional<StudyTask> findByStartRequest(String userId, String requestId) {
            return tasks.values().stream()
                    .filter(t -> t.userId().equals(userId) && t.startRequestId().equals(requestId))
                    .findFirst();
        }

        @Override
        public Optional<StudyTask> findLatestEnded(String userId, String regionId) {
            return tasks.values().stream()
                    .filter(t -> t.userId().equals(userId) && t.regionId().equals(regionId)
                            && t.endedAt() != null)
                    .max((a, b) -> a.endedAt().compareTo(b.endedAt()));
        }

        @Override
        public StudyTask insert(StudyTask task) {
            tasks.put(task.taskId(), task);
            return task;
        }

        @Override
        public void save(StudyTask task) {
            tasks.put(task.taskId(), task);
        }

        @Override
        public Optional<Region> findRegion(String regionId) {
            return region.regionId().equals(regionId) ? Optional.of(region) : Optional.empty();
        }

        @Override
        public Optional<LocationSample> findSample(String taskId, String sampleId) {
            return Optional.ofNullable(samples.getOrDefault(taskId, Map.of()).get(sampleId));
        }

        @Override
        public void saveSample(String taskId, LocationSample sample, boolean accepted, RejectionReason reason) {
            samples.computeIfAbsent(taskId, key -> new HashMap<>()).put(sample.sampleId(), sample);
        }
    }

    /** 遭遇端口替身，只统计调用次数。 */
    static final class CountingSpawnGateway implements SpawnGateway {
        private int created;

        @Override
        public String createStudySpawn(String userId, String regionId, String taskId, Instant now, boolean simulated) {
            created++;
            return "spawn-" + created;
        }
    }
}
