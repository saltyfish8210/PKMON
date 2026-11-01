package edu.pkmon.study.service;

import edu.pkmon.study.domain.*;
import edu.pkmon.study.dto.*;
import edu.pkmon.study.error.*;
import edu.pkmon.study.port.*;

import java.util.Optional;

/**
 * 自习任务服务端口，对应四个 study 接口。
 */
public interface StudyTaskService {

    /**
     * 开始任务。同一用户已有活动任务时返回该任务。
     *
     * @param userId 当前用户
     * @param regionId 区域业务键
     * @param requestId 开始请求编号，重复使用视为同一次开始
     * @param locationSource GPS 或 SIMULATED
     * @return 任务视图
     */
    TaskView startTask(String userId, String regionId, String requestId, String locationSource);

    /**
     * 提交一条位置样本。
     *
     * @param userId 当前用户
     * @param taskId 任务编号
     * @param sample 位置样本
     * @return 任务视图与样本采纳结果
     */
    SampleResult submitSample(String userId, String taskId, LocationSample sample);

    /**
     * 查询当前活动任务，查询时同样推进失联判定。
     *
     * @param userId 当前用户
     * @return 活动任务，没有时为 empty
     */
    Optional<TaskView> currentTask(String userId);

    /**
     * 结束任务，重复调用返回同一最终状态。
     *
     * @param userId 当前用户
     * @param taskId 任务编号
     * @param requestId 结束请求编号
     * @return 任务视图
     */
    TaskView endTask(String userId, String taskId, String requestId);
}
