package edu.pkmon.study.domain;

import java.time.Instant;

/**
 * 任务聚合：驻留状态加任务级元数据，对应 study_task 一行。
 *
 * @param taskId 任务编号（UUID）
 * @param userId 所属用户
 * @param regionId 区域业务键
 * @param startRequestId 开始任务的请求编号，用于重复开始幂等
 * @param locationSource GPS 或 SIMULATED
 * @param state 驻留评估状态
 * @param startedAt 开始时间
 * @param endedAt 结束时间，未结束为 null
 * @param spawnId 触发后生成的遭遇编号
 */
public record StudyTask(
        String taskId,
        String userId,
        String regionId,
        String startRequestId,
        String locationSource,
        DwellState state,
        Instant startedAt,
        Instant endedAt,
        String spawnId) {

    /**
     * 用新状态替换驻留部分。
     *
     * @param newState 新状态
     * @return 更新后的聚合
     */
    public StudyTask withState(DwellState newState) {
        return new StudyTask(taskId, userId, regionId, startRequestId, locationSource,
                newState, startedAt, endedAt, spawnId);
    }

    /**
     * 记录首次触发产生的遭遇。
     *
     * @param newSpawnId 遭遇编号
     * @return 更新后的聚合
     */
    public StudyTask withSpawn(String newSpawnId) {
        return new StudyTask(taskId, userId, regionId, startRequestId, locationSource,
                state, startedAt, endedAt, newSpawnId);
    }

    /**
     * 结束任务。
     *
     * @param at 结束时间
     * @return 更新后的聚合
     */
    public StudyTask end(Instant at) {
        return new StudyTask(taskId, userId, regionId, startRequestId, locationSource,
                state, startedAt, at, spawnId);
    }
}
