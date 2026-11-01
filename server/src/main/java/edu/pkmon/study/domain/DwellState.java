package edu.pkmon.study.domain;

import java.time.Instant;
import java.util.Objects;

/**
 * 驻留评估的输入与输出状态，与 study_task 表字段一一对应。
 *
 * <p>规则实现不依赖数据库、网络和真实等待时间：只有 {@link DwellEvaluator} 用注入的服务器时间推进该状态。</p>
 *
 * @param taskId 任务编号
 * @param status 当前任务状态
 * @param pauseReason 暂停原因，非 PAUSED 时为 null
 * @param effectiveSeconds 已认可的有效停留秒数
 * @param requiredSeconds 触发所需秒数，创建任务时由服务端写入
 * @param insideCount 进入半径内连续合格样本数，用于确认进入或恢复
 * @param outsideCount 连续超出退出半径的样本数，第二次暂停
 * @param chainValid 是否处于已确认的累计链中
 * @param lastAcceptedAt 最后一个合格样本的采样时刻，用于失联判定
 * @param lastSampledAt 最后一个合格样本的原始采样时刻，用于乱序判定
 * @param lastLatitude 最后一个合格样本纬度
 * @param lastLongitude 最后一个合格样本经度
 * @param lastSampleInside 最后一个合格样本是否在进入半径内
 * @param lastSampleId 最后一个合格样本编号，用于重复判定
 * @param triggered 是否已触发过遭遇
 */
public record DwellState(
        String taskId,
        TaskStatus status,
        PauseReason pauseReason,
        long effectiveSeconds,
        long requiredSeconds,
        int insideCount,
        int outsideCount,
        boolean chainValid,
        Instant lastAcceptedAt,
        Instant lastSampledAt,
        Double lastLatitude,
        Double lastLongitude,
        boolean lastSampleInside,
        String lastSampleId,
        boolean triggered) {

    /** 状态必须能自解释，避免出现 PAUSED 无原因之类的组合。 */
    public DwellState {
        Objects.requireNonNull(taskId, "taskId");
        Objects.requireNonNull(status, "status");
        if (status != TaskStatus.PAUSED && pauseReason != null) {
            throw new IllegalArgumentException("只有 PAUSED 可以带暂停原因");
        }
        if (status == TaskStatus.PAUSED && pauseReason == null) {
            throw new IllegalArgumentException("PAUSED 必须带暂停原因");
        }
        if (effectiveSeconds < 0 || requiredSeconds <= 0) {
            throw new IllegalArgumentException("时长必须为非负且阈值必须为正");
        }
        if (insideCount < 0 || outsideCount < 0) {
            throw new IllegalArgumentException("计数不能为负");
        }
    }

    /**
     * 创建一个尚未收到任何样本的新任务状态。
     *
     * @param taskId 任务编号
     * @param requiredSeconds 触发阈值
     * @return WAITING 初始状态
     */
    public static DwellState start(String taskId, long requiredSeconds) {
        return new DwellState(taskId, TaskStatus.WAITING, null, 0, requiredSeconds,
                0, 0, false, null, null, null, null, false, null, false);
    }

    /**
     * 任务是否仍可能产生新的累计或触发。
     *
     * @return TRIGGERED 与 ENDED 之外为 true
     */
    public boolean isActive() {
        return status != TaskStatus.TRIGGERED && status != TaskStatus.ENDED;
    }

    /**
     * 结束任务，保留已认可时长与样本记录，清空暂停原因。
     *
     * @return ENDED 状态
     */
    public DwellState ended() {
        return new DwellState(taskId, TaskStatus.ENDED, null, effectiveSeconds, requiredSeconds,
                insideCount, outsideCount, false, lastAcceptedAt, lastSampledAt,
                lastLatitude, lastLongitude, lastSampleInside, lastSampleId, triggered);
    }
}
