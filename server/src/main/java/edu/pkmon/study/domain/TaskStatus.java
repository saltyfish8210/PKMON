package edu.pkmon.study.domain;

/**
 * 自习任务状态。取值与组内统一约定一致：WAITING、DWELLING、PAUSED、TRIGGERED、ENDED。
 */
public enum TaskStatus {
    /** 任务已创建，尚未确认有效驻留。 */
    WAITING,
    /** 已确认有效驻留，正在累计有效停留时长。 */
    DWELLING,
    /** 暂停累计，原因见 {@link PauseReason}。 */
    PAUSED,
    /** 已达到阈值并生成一次遭遇机会，时长与结果固定。 */
    TRIGGERED,
    /** 用户结束或任务终止。 */
    ENDED
}
