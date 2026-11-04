package edu.pkmon.study.port;

import edu.pkmon.study.domain.*;

import java.time.Instant;

/**
 * 遭遇创建端口。任务触发后由孙虹毅的 SpawnService 在事务内创建一次 STUDY 来源遭遇，
 * study_task.triggered_spawn_id 与 spawn.task_id 双向确认唯一。
 */
public interface SpawnGateway {

    /**
     * 为任务创建一次遭遇。
     *
     * @param userId 用户编号
     * @param regionId 区域业务键
     * @param taskId 任务编号，数据库唯一约束保证一个任务最多一条
     * @param now 服务器时间
     * @return 新建的遭遇编号
     */
    String createStudySpawn(String userId, String regionId, String taskId, Instant now, boolean simulated);
}
