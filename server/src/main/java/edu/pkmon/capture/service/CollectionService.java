package edu.pkmon.capture.service;

import edu.pkmon.capture.domain.CaptureRecord;
import edu.pkmon.capture.domain.Spawn;
import edu.pkmon.capture.dto.CaptureDtos.BagEntryView;
import edu.pkmon.capture.dto.CaptureDtos.BagResponse;
import edu.pkmon.capture.dto.CaptureDtos.CollectionSummaryResponse;
import edu.pkmon.capture.dto.CaptureDtos.DexEntryView;
import edu.pkmon.capture.dto.CaptureDtos.DexResponse;
import edu.pkmon.capture.port.SpeciesCatalog;
import edu.pkmon.capture.repository.Repositories.CaptureRecordRepository;
import edu.pkmon.capture.repository.Repositories.SpawnRepository;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 收藏查询：概览、图鉴、背包三个只读视图，不写入、不发奖。
 *
 * <p>三者口径必须一致：都以 {@code capture_records}（已落库的收录事实）为唯一来源，
 * 通过遭遇取到物种，不读客户端上传的任何计数，也不依赖内存累加。
 */
@Service
public class CollectionService {

    private final SpawnRepository spawns;
    private final CaptureRecordRepository records;
    private final SpeciesCatalog species;

    public CollectionService(SpawnRepository spawns, CaptureRecordRepository records,
                             SpeciesCatalog species) {
        this.spawns = spawns;
        this.records = records;
        this.species = species;
    }

    public CollectionSummaryResponse summary(String userId) {
        List<CaptureRecord> captured = records.findByUser(userId);
        Map<String, List<Instant>> bySpecies = capturesBySpecies(captured);
        return new CollectionSummaryResponse(bySpecies.size(), species.totalSpeciesCount(),
                captured.size());
    }

    /**
     * 图鉴：列出目录中的全部物种，已收的带数量与首次收录时刻，未收的保留占位。
     * 顺序按物种目录顺序，不由收录时间决定，避免"新收的排最前"造成误解。
     */
    public DexResponse dex(String userId) {
        Map<String, List<Instant>> captures = capturesBySpecies(records.findByUser(userId));
        List<DexEntryView> entries = new ArrayList<>();
        int collected = 0;
        for (String speciesId : species.allSpeciesIds()) {
            List<Instant> times = captures.getOrDefault(speciesId, List.of());
            String name = species.nameOf(speciesId).orElse(speciesId);
            if (times.isEmpty()) {
                entries.add(new DexEntryView(speciesId, name, 0, null));
                continue;
            }
            collected++;
            Instant first = times.stream().min(Comparator.naturalOrder()).orElse(null);
            entries.add(new DexEntryView(speciesId, name, times.size(), first));
        }
        return new DexResponse(collected, species.totalSpeciesCount(), entries);
    }

    /**
     * 背包：只列出本人实际持有的物种，按最近一次收录时间倒序。
     */
    public BagResponse bag(String userId) {
        Map<String, List<Instant>> captures = capturesBySpecies(records.findByUser(userId));
        List<BagEntryView> entries = new ArrayList<>();
        int total = 0;
        for (Map.Entry<String, List<Instant>> entry : captures.entrySet()) {
            String speciesId = entry.getKey();
            List<Instant> times = entry.getValue();
            total += times.size();
            Instant latest = times.stream().max(Comparator.naturalOrder()).orElse(null);
            String name = species.nameOf(speciesId).orElse(speciesId);
            entries.add(new BagEntryView(speciesId, name, times.size(), latest));
        }
        entries.sort(Comparator.comparing(BagEntryView::latestCapturedAt,
                Comparator.nullsLast(Comparator.reverseOrder())));
        return new BagResponse(total, entries.size(), entries);
    }

    /** 物种 → 该物种的全部收录时刻；遭遇已不存在的记录一律跳过，不猜测物种。 */
    private Map<String, List<Instant>> capturesBySpecies(List<CaptureRecord> captured) {
        Map<String, List<Instant>> bySpecies = new LinkedHashMap<>();
        for (CaptureRecord record : captured) {
            spawns.findById(record.spawnId())
                    .map(Spawn::speciesId)
                    .ifPresent(speciesId -> bySpecies
                            .computeIfAbsent(speciesId, key -> new ArrayList<>())
                            .add(record.capturedAt()));
        }
        return bySpecies;
    }
}
