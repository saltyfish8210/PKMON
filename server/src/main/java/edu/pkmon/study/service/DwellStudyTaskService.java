package edu.pkmon.study.service;

import edu.pkmon.study.domain.*;
import edu.pkmon.study.dto.*;
import edu.pkmon.study.error.*;
import edu.pkmon.study.port.*;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

/**
 * 任务服务实现：把纯规则 {@link DwellEvaluator} 接到存储端口和遭遇端口上。
 *
 * <p>本阶段已验证部分：开始/结束幂等、活动任务唯一、样本采纳与拒绝、一次性触发、冷却拒绝。
 * 真实 HTTP 控制器、JDBC 存储和定位插件串联属于第三阶段，未在本类中声明为已完成。</p>
 */
public final class DwellStudyTaskService implements StudyTaskService {

    private final TaskRepository repository;
    private final SpawnGateway spawnGateway;
    private final DwellEvaluator evaluator;
    private final Clock clock;

    /**
     * @param repository 任务存储端口
     * @param spawnGateway 遭遇创建端口
     * @param evaluator 驻留规则
     * @param clock 服务器时钟，测试时注入固定时钟
     */
    public DwellStudyTaskService(TaskRepository repository, SpawnGateway spawnGateway,
            DwellEvaluator evaluator, Clock clock) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.spawnGateway = Objects.requireNonNull(spawnGateway, "spawnGateway");
        this.evaluator = Objects.requireNonNull(evaluator, "evaluator");
        this.clock = Objects.requireNonNull(clock, "clock");
    }

    @Override
    public synchronized TaskView startTask(String userId, String regionId, String requestId, String locationSource) {
        requireText(userId, "userId");
        requireText(regionId, "regionId");
        requireText(requestId, "requestId");
        if (!"SIMULATED".equals(locationSource) && !"GPS".equals(locationSource)) throw TaskException.badRequest("未知位置来源");
        Instant now = clock.instant();
        Region region = repository.findRegion(regionId)
                .orElseThrow(() -> TaskException.notFound("区域不存在"));
        if (!region.enabled()) {
            throw TaskException.stateConflict("区域未启用");
        }
        Optional<StudyTask> sameRequest = repository.findByStartRequest(userId, requestId);
        if (sameRequest.isPresent()) {
            if (!sameRequest.get().regionId().equals(regionId) || !sameRequest.get().locationSource().equals(locationSource)) {
                throw TaskException.requestConflict("同一请求编号对应不同区域");
            }
            return TaskView.of(sameRequest.get(), now);
        }
        Optional<StudyTask> active = repository.findActiveByUser(userId);
        if (active.isPresent()) {
            if (!active.get().locationSource().equals(locationSource)) throw TaskException.stateConflict("请先结束已有任务再切换定位来源");
            return TaskView.of(active.get(), now);
        }
        rejectDuringCooldown(userId, regionId, now);
        String taskId = UUID.randomUUID().toString();
        StudyTask task = new StudyTask(taskId, userId, regionId, requestId, locationSource,
                DwellState.start(taskId, evaluator.rules().requiredSeconds()), now, null, null);
        repository.insert(task);
        return TaskView.of(task, now);
    }

    @Override
    public synchronized SampleResult submitSample(String userId, String taskId, LocationSample sample) {
        requireText(userId, "userId");
        requireText(taskId, "taskId");
        Objects.requireNonNull(sample, "sample");
        Instant now = clock.instant();
        StudyTask task = requireOwned(userId, taskId);
        if (task.state().status() == TaskStatus.ENDED) {
            throw TaskException.stateConflict("任务已结束");
        }
        if (!task.locationSource().equals(sample.source())) throw TaskException.badRequest("样本来源与任务不一致");
        Optional<LocationSample> existing = repository.findSample(taskId, sample.sampleId());
        if (existing.isPresent()) {
            if (!existing.get().sameContent(sample)) {
                throw TaskException.requestConflict("同一 sampleId 的内容不同");
            }
            return new SampleResult(TaskView.of(task, now), false, RejectionReason.DUPLICATE_SAMPLE);
        }
        Region region = repository.findRegion(task.regionId())
                .orElseThrow(() -> TaskException.notFound("任务区域不存在"));
        DwellDecision decision = evaluator.onSample(task.state(), region, sample, now);
        StudyTask updated = task.withState(decision.state());
        if (decision.triggeredNow() && updated.spawnId() == null) {
            updated = updated.withSpawn(spawnGateway.createStudySpawn(userId, region.regionId(), taskId, now, sample.isSimulated()));
        }
        repository.save(updated);
        repository.saveSample(taskId, sample, decision.accepted(), decision.rejectionReason());
        return new SampleResult(TaskView.of(updated, now), decision.accepted(), decision.rejectionReason());
    }

    @Override
    public synchronized Optional<TaskView> currentTask(String userId) {
        requireText(userId, "userId");
        Instant now = clock.instant();
        Optional<StudyTask> active = repository.findActiveByUser(userId);
        if (active.isEmpty()) {
            return Optional.empty();
        }
        StudyTask task = active.get();
        DwellState ticked = evaluator.onTick(task.state(), now);
        if (!ticked.equals(task.state())) {
            task = task.withState(ticked);
            repository.save(task);
        }
        return Optional.of(TaskView.of(task, now));
    }

    @Override
    public synchronized TaskView endTask(String userId, String taskId, String requestId) {
        requireText(userId, "userId");
        requireText(taskId, "taskId");
        requireText(requestId, "requestId");
        Instant now = clock.instant();
        StudyTask task = requireOwned(userId, taskId);
        if (task.state().status() == TaskStatus.ENDED) {
            return TaskView.of(task, now);
        }
        StudyTask ended = task.withState(task.state().ended()).end(now);
        repository.save(ended);
        return TaskView.of(ended, now);
    }

    private StudyTask requireOwned(String userId, String taskId) {
        StudyTask task = repository.findById(taskId)
                .orElseThrow(() -> TaskException.notFound("任务不存在"));
        if (!task.userId().equals(userId)) {
            throw TaskException.notFound("任务不属于当前用户");
        }
        return task;
    }

    private void rejectDuringCooldown(String userId, String regionId, Instant now) {
        Optional<StudyTask> latest = repository.findLatestEnded(userId, regionId);
        if (latest.isEmpty() || latest.get().endedAt() == null) {
            return;
        }
        long sinceEnd = Duration.between(latest.get().endedAt(), now).getSeconds();
        if (sinceEnd < evaluator.rules().cooldownSeconds()) {
            throw TaskException.coolingDown("任务仍在冷却期");
        }
    }

    private static void requireText(String value, String name) {
        if (value == null || value.isBlank()) {
            throw TaskException.badRequest(name + " 不能为空");
        }
    }
}
