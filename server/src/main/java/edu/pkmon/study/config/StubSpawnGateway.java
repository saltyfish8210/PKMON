package edu.pkmon.study.config;

import edu.pkmon.study.port.SpawnGateway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.util.UUID;

/**
 * 遭遇创建替身：只生成编号并记录日志，不创建真实遭遇记录。
 *
 * <p>这是接入孙虹毅 SpawnService 之前的临时实现。启用时日志每次触发都会出现 STUB 字样，
 * 演示与验收必须说明"遭遇为替身"，不能据此声称完整链路已通。</p>
 */
public final class StubSpawnGateway implements SpawnGateway {

    private static final Logger log = LoggerFactory.getLogger(StubSpawnGateway.class);

    @Override
    public String createStudySpawn(String userId, String regionId, String taskId, Instant now, boolean simulated) {
        String spawnId = UUID.randomUUID().toString();
        log.warn("STUB 遭遇：任务 {} 触发，仅生成编号 {}，未写入 spawn 表；接入 capture.SpawnService 后移除",
                taskId, spawnId);
        return spawnId;
    }
}
