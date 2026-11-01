package edu.pkmon.study.domain;

/**
 * 位置样本未被采纳的原因。写入 task_sample.rejection_reason，并随接口 sampleAccepted=false 返回。
 */
public enum RejectionReason {
    /** 样本时间晚于服务器时间超过容忍偏差。 */
    FUTURE_SAMPLE,
    /** 样本时间早于服务器时间超过最大样本年龄。 */
    SAMPLE_TOO_OLD,
    /** 精度低于要求，不能参与累计。 */
    LOW_ACCURACY,
    /** 坐标系不是 GCJ02，不能参与累计。 */
    UNSUPPORTED_COORDINATE_SYSTEM,
    /** 同一任务内重复的 sampleId 且内容一致，不重复累计。 */
    DUPLICATE_SAMPLE,
    /** 样本时间不晚于上一个已采纳样本，按乱序丢弃。 */
    OUT_OF_ORDER,
    /** 任务已结束，不再接受样本。 */
    TASK_ENDED
}
