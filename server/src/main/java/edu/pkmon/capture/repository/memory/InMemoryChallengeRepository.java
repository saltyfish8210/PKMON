package edu.pkmon.capture.repository.memory;

import edu.pkmon.capture.domain.Challenge;
import edu.pkmon.capture.domain.ChallengeStatus;
import edu.pkmon.capture.repository.Repositories.ChallengeRepository;

import java.util.Comparator;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/** 内存替身：进程重启即丢失，不构成真实持久化。 */
public final class InMemoryChallengeRepository implements ChallengeRepository {

    private final ConcurrentMap<String, Challenge> byId = new ConcurrentHashMap<>();

    @Override
    public Optional<Challenge> findById(String challengeId) {
        return challengeId == null ? Optional.empty() : Optional.ofNullable(byId.get(challengeId));
    }

    @Override
    public Optional<Challenge> findOpenByUserAndSpawn(String userId, String spawnId) {
        return byId.values().stream()
                .filter(c -> c.userId().equals(userId))
                .filter(c -> c.spawnId().equals(spawnId))
                .filter(c -> c.status() == ChallengeStatus.OPEN)
                .max(Comparator.comparing(Challenge::expiresAt));
    }

    public java.util.List<String> recentQuestions(String userId) {
        return byId.values().stream().filter(item -> item.userId().equals(userId))
                .sorted(Comparator.comparing(Challenge::expiresAt).reversed()).limit(9).map(Challenge::questionId).toList();
    }

    @Override
    public Challenge save(Challenge challenge) {
        byId.put(challenge.challengeId(), challenge);
        return challenge;
    }
}
