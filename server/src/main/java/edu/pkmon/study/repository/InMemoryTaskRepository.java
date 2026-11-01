package edu.pkmon.study.repository;

import edu.pkmon.study.domain.LocationSample;
import edu.pkmon.study.domain.Region;
import edu.pkmon.study.domain.RejectionReason;
import edu.pkmon.study.domain.StudyTask;
import edu.pkmon.study.port.TaskRepository;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 内存实现：第三阶段接 JDBC 前用于开发、演示与自动化测试。
 *
 * <p>不做数据库唯一约束，活动任务唯一与样本唯一由本类的同步方法与调用方行锁语义近似保证；
 * 并发触发保护在真实实现里必须由数据库约束兜底，不能依赖本类。</p>
 */
public final class InMemoryTaskRepository implements TaskRepository {

    private final Map<String, StudyTask> tasks = new ConcurrentHashMap<>();
    private final Map<String, Map<String, LocationSample>> samples = new ConcurrentHashMap<>();
    private volatile Region region;

    /**
     * @param region 初始区域，演示与测试使用；真实区域由胡豪的 region 表提供
     */
    public InMemoryTaskRepository(Region region) {
        this.region = region;
    }

    /**
     * 替换区域（测试与演示配置注入用）。
     *
     * @param region 新区域
     */
    public void setRegion(Region region) {
        this.region = region;
    }

    @Override
    public synchronized Optional<StudyTask> findActiveByUser(String userId) {
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
                .filter(t -> t.userId().equals(userId) && t.regionId().equals(regionId) && t.endedAt() != null)
                .max((a, b) -> a.endedAt().compareTo(b.endedAt()));
    }

    @Override
    public synchronized StudyTask insert(StudyTask task) {
        tasks.put(task.taskId(), task);
        return task;
    }

    @Override
    public void save(StudyTask task) {
        tasks.put(task.taskId(), task);
    }

    @Override
    public Optional<Region> findRegion(String regionId) {
        Region current = region;
        return current != null && current.regionId().equals(regionId) ? Optional.of(current) : Optional.empty();
    }

    @Override
    public Optional<LocationSample> findSample(String taskId, String sampleId) {
        return Optional.ofNullable(samples.getOrDefault(taskId, Map.of()).get(sampleId));
    }

    @Override
    public synchronized void saveSample(String taskId, LocationSample sample, boolean accepted,
            RejectionReason reason) {
        samples.computeIfAbsent(taskId, key -> new HashMap<>()).put(sample.sampleId(), sample);
    }
}
