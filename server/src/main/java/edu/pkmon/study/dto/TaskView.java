package edu.pkmon.study.dto;

import edu.pkmon.study.domain.*;

import java.time.Instant;

/**
 * 任务对外视图，字段与 api-contract 的 TaskView 一致，序列化后直接作为 data 返回。
 *
 * @param taskId 任务编号
 * @param regionId 区域业务键
 * @param status 任务状态
 * @param pauseReason 暂停原因
 * @param effectiveSeconds 已认可有效停留秒数
 * @param requiredSeconds 触发阈值
 * @param spawnId 已生成的遭遇，未触发时为 null
 * @param serverTime 服务器当前时间
 */
public record TaskView(
        String taskId,
        String regionId,
        TaskStatus status,
        PauseReason pauseReason,
        long effectiveSeconds,
        long requiredSeconds,
        String spawnId,
        Instant serverTime) {

    /**
     * 由聚合状态生成视图。
     *
     * @param task 任务聚合
     * @param now 服务器时间
     * @return 任务视图
     */
    public static TaskView of(StudyTask task, Instant now) {
        DwellState state = task.state();
        return new TaskView(task.taskId(), task.regionId(), state.status(), state.pauseReason(),
                state.effectiveSeconds(), state.requiredSeconds(), task.spawnId(), now);
    }
}
