package edu.pkmon.capture.service;

import edu.pkmon.capture.domain.Spawn;
import edu.pkmon.capture.domain.SpawnSourceType;
import edu.pkmon.capture.error.ApiErrorCode;
import edu.pkmon.capture.error.ApiException;
import edu.pkmon.capture.repository.Repositories.SpawnRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Duration;
import java.util.UUID;

/** 遭遇机会的创建与可用性判定。不判题、不发奖。 */
@Service
public class SpawnService {

    static final Duration SPAWN_TTL = Duration.ofMinutes(10);

    private final Clock clock;
    private final SpawnRepository spawns;
    private final boolean devSpawnEnabled;

    public SpawnService(Clock clock, SpawnRepository spawns,
                        @Value("${pkmon.capture.dev-spawn-enabled:true}") boolean devSpawnEnabled) {
        this.clock = clock;
        this.spawns = spawns;
        this.devSpawnEnabled = devSpawnEnabled;
    }

    /** 开发遭遇：只产生机会，不产生任何收录。正式环境必须由配置关闭。 */
    public Spawn createDevSpawn(String userId, String regionId, String speciesId) {
        if (!devSpawnEnabled) {
            throw new ApiException(ApiErrorCode.DEV_ONLY);
        }
        if (isBlank(regionId) || isBlank(speciesId)) {
            throw new ApiException(ApiErrorCode.INVALID_PARAM, "regionId 与 speciesId 不能为空");
        }
        Spawn spawn = new Spawn(UUID.randomUUID().toString(), userId, regionId, speciesId,
                SpawnSourceType.DEV_SIMULATED, clock.instant().plus(SPAWN_TTL));
        return spawns.save(spawn);
    }

    /** The task UUID is stable. A repeated trigger can only resolve to its original encounter. */
    public Spawn fromStudyTask(String user, String region, String task, java.time.Instant now, boolean simulated) {
        if (simulated && !devSpawnEnabled) throw new ApiException(ApiErrorCode.DEV_ONLY);
        String id = UUID.nameUUIDFromBytes(("study-spawn:" + task).getBytes(java.nio.charset.StandardCharsets.UTF_8)).toString();
        return spawns.findById(id).orElseGet(() -> spawns.save(new Spawn(id, user, region, "siege_lion",
                simulated ? SpawnSourceType.DEV_SIMULATED : SpawnSourceType.LOCATION, now.plus(SPAWN_TTL))));
    }

    /** 取一个属于该用户且未过期的遭遇；不存在与不属于本人一律按不存在处理。 */
    public Spawn requireUsable(String userId, String spawnId) {
        Spawn spawn = isBlank(spawnId) ? null : spawns.findById(spawnId).orElse(null);
        if (spawn == null || !spawn.userId().equals(userId)) {
            throw new ApiException(ApiErrorCode.NOT_FOUND);
        }
        if (!spawn.usableAt(clock.instant())) {
            throw new ApiException(ApiErrorCode.EXPIRED, "遭遇已过期，请重新遭遇");
        }
        return spawn;
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
