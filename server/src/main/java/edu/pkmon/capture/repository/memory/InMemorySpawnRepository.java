package edu.pkmon.capture.repository.memory;

import edu.pkmon.capture.domain.Spawn;
import edu.pkmon.capture.repository.Repositories.SpawnRepository;

import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/** 内存替身：进程重启即丢失，不构成真实持久化。 */
public final class InMemorySpawnRepository implements SpawnRepository {

    private final ConcurrentMap<String, Spawn> byId = new ConcurrentHashMap<>();

    @Override
    public Optional<Spawn> findById(String spawnId) {
        return spawnId == null ? Optional.empty() : Optional.ofNullable(byId.get(spawnId));
    }

    public java.util.List<Spawn> activeFor(String userId, java.time.Instant now) {
        return byId.values().stream().filter(item -> item.userId().equals(userId) && item.usableAt(now)).toList();
    }

    @Override
    public Spawn save(Spawn spawn) {
        byId.put(spawn.spawnId(), spawn);
        return spawn;
    }
}
