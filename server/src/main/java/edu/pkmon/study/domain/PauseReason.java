package edu.pkmon.study.domain;

/**
 * 任务暂停原因。仅在 {@link TaskStatus#PAUSED} 时有值。
 */
public enum PauseReason {
    /** 连续两次超出退出半径。 */
    OUTSIDE,
    /** 距最后一个合格样本超过失联阈值。 */
    NO_SIGNAL
}
