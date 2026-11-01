package edu.pkmon.study.dto;

import edu.pkmon.study.domain.*;

/**
 * 提交样本的返回：任务视图加本次样本是否采纳。
 *
 * @param task 处理后的任务视图
 * @param sampleAccepted 样本是否参与判定
 * @param rejectionReason 未采纳原因，采纳时为 null
 */
public record SampleResult(TaskView task, boolean sampleAccepted, RejectionReason rejectionReason) {
}
