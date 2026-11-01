package edu.pkmon.study.dto;

import edu.pkmon.study.domain.PauseReason;
import edu.pkmon.study.domain.RejectionReason;
import edu.pkmon.study.domain.TaskStatus;

import java.time.Instant;

/**
 * 自习任务的请求与响应形状。只做传输，不含业务判断；校验在控制器与服务层完成。
 */
public final class StudyDtos {

    private StudyDtos() {
    }

    /**
     * 开始任务请求。
     *
     * @param regionId 区域业务键
     * @param requestId 开始请求编号，重试沿用
     * @param locationSource GPS 或 SIMULATED
     */
    public record StartTaskRequest(String regionId, String requestId, String locationSource) {
    }

    /**
     * 位置样本请求。数值字段用包装类型以便把缺失字段与非法值区分出来。
     *
     * @param sampleId 采样编号
     * @param latitude 纬度（GCJ02）
     * @param longitude 经度（GCJ02）
     * @param accuracyMeters 水平精度（米）
     * @param sampledAt ISO 8601 采样时刻（UTC）
     * @param coordinateSystem 坐标系标签
     * @param source GPS 或 SIMULATED
     */
    public record SampleRequest(String sampleId, Double latitude, Double longitude, Double accuracyMeters,
            String sampledAt, String coordinateSystem, String source) {
    }

    /**
     * 结束任务请求。
     *
     * @param requestId 结束请求编号
     */
    public record EndTaskRequest(String requestId) {
    }

    /**
     * 当前任务响应。
     *
     * @param task 活动任务，没有时为 null
     */
    public record CurrentTaskResponse(TaskView task) {
    }

    /**
     * 提交样本的响应：TaskView 字段打平，另加样本是否采纳与拒绝原因。
     *
     * @param taskId 任务编号
     * @param regionId 区域业务键
     * @param status 任务状态
     * @param pauseReason 暂停原因
     * @param effectiveSeconds 已认可秒数
     * @param requiredSeconds 阈值
     * @param spawnId 遭遇编号
     * @param serverTime 服务器时间
     * @param sampleAccepted 样本是否参与判定
     * @param rejectionReason 未采纳原因
     */
    public record SampleResponse(String taskId, String regionId, TaskStatus status, PauseReason pauseReason,
            long effectiveSeconds, long requiredSeconds, String spawnId, Instant serverTime,
            boolean sampleAccepted, RejectionReason rejectionReason) {

        /**
         * 由视图与样本结果拼装。
         *
         * @param view 任务视图
         * @param sampleAccepted 样本是否采纳
         * @param reason 未采纳原因
         * @return 响应
         */
        public static SampleResponse of(TaskView view, boolean sampleAccepted, RejectionReason reason) {
            return new SampleResponse(view.taskId(), view.regionId(), view.status(), view.pauseReason(),
                    view.effectiveSeconds(), view.requiredSeconds(), view.spawnId(), view.serverTime(),
                    sampleAccepted, reason);
        }
    }
}
