package edu.pkmon.study.port;

import edu.pkmon.study.domain.*;

import java.util.Optional;

/**
 * 任务存储端口。第三阶段由胡豪按 data-dictionary 的 study_task、task_sample 建表后提供 JDBC 实现；
 * 本阶段只用内存实现验证规则与一次性触发，不声明已完成持久化。
 */
public interface TaskRepository {

    /**
     * 查找用户当前活动任务（WAITING/DWELLING/PAUSED/TRIGGERED）。
     *
     * @param userId 用户编号
     * @return 活动任务
     */
    Optional<StudyTask> findActiveByUser(String userId);

    /**
     * 按任务编号查找。
     *
     * @param taskId 任务编号
     * @return 任务
     */
    Optional<StudyTask> findById(String taskId);

    /**
     * 按开始请求编号查找，用于重复开始幂等。
     *
     * @param userId 用户编号
     * @param requestId 开始请求编号
     * @return 该请求创建的任务
     */
    Optional<StudyTask> findByStartRequest(String userId, String requestId);

    /**
     * 查找同用户同区域最近结束的任务，用于冷却判定。
     *
     * @param userId 用户编号
     * @param regionId 区域业务键
     * @return 最近结束的任务
     */
    Optional<StudyTask> findLatestEnded(String userId, String regionId);

    /**
     * 保存新任务。
     *
     * @param task 任务
     * @return 已保存任务
     */
    StudyTask insert(StudyTask task);

    /**
     * 更新任务。
     *
     * @param task 任务
     */
    void save(StudyTask task);

    /**
     * 查找区域定义。
     *
     * @param regionId 区域业务键
     * @return 区域
     */
    Optional<Region> findRegion(String regionId);

    /**
     * 查找任务下同一编号的样本，用于重复编号比较。
     *
     * @param taskId 任务编号
     * @param sampleId 样本编号
     * @return 已保存样本
     */
    Optional<LocationSample> findSample(String taskId, String sampleId);

    /**
     * 追加样本记录。
     *
     * @param taskId 任务编号
     * @param sample 样本
     * @param accepted 是否采纳
     * @param reason 未采纳原因
     */
    void saveSample(String taskId, LocationSample sample, boolean accepted, RejectionReason reason);
}
