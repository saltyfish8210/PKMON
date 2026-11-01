package edu.pkmon.study.domain;

/**
 * 一次样本处理的结果。
 *
 * @param state 处理后的状态
 * @param accepted 样本是否参与了规则判定
 * @param rejectionReason 未采纳原因，accepted 为 true 时为 null
 * @param triggeredNow 本次处理是否刚刚达到阈值
 * @param accumulatedSeconds 本次新增的有效停留秒数
 */
public record DwellDecision(
        DwellState state,
        boolean accepted,
        RejectionReason rejectionReason,
        boolean triggeredNow,
        long accumulatedSeconds) {

    /**
     * 构造未采纳的结果。
     *
     * @param state 原状态
     * @param reason 未采纳原因
     * @return 未采纳结果
     */
    public static DwellDecision rejected(DwellState state, RejectionReason reason) {
        return new DwellDecision(state, false, reason, false, 0);
    }

    /**
     * 构造已采纳的结果。
     *
     * @param state 处理后状态
     * @param triggeredNow 是否刚刚触发
     * @param accumulatedSeconds 本次新增秒数
     * @return 已采纳结果
     */
    public static DwellDecision accepted(DwellState state, boolean triggeredNow, long accumulatedSeconds) {
        return new DwellDecision(state, true, null, triggeredNow, accumulatedSeconds);
    }
}
