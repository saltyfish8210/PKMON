package edu.pkmon.capture.service;

import edu.pkmon.capture.domain.CaptureRecord;
import edu.pkmon.capture.domain.Spawn;
import edu.pkmon.capture.domain.SpawnSourceType;
import edu.pkmon.capture.dto.CaptureDtos.BagResponse;
import edu.pkmon.capture.dto.CaptureDtos.CollectionSummaryResponse;
import edu.pkmon.capture.dto.CaptureDtos.DexResponse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 收藏三视图（概览／图鉴／背包）的口径一致性。
 *
 * <p>这些用例只验证业务口径，使用内存仓储替身与固定时钟，
 * 不代表真实持久化能力（持久化与重启验证见 JDBC 用例与浏览器验收记录）。
 */
class CollectionServiceTest {

    private static final String USER = "user-1";
    private static final String OTHER = "user-2";
    private static final String SPECIES = "siege_lion";
    private static final String REGION = "lib-campus";

    private final CaptureTestSupport support =
            new CaptureTestSupport(Instant.parse("2026-11-16T01:00:00Z"));

    private void seedCapture(String userId, String spawnId, Instant at) {
        support.spawns.save(new Spawn(spawnId, userId, REGION, SPECIES,
                SpawnSourceType.LOCATION, at.plusSeconds(600)));
        support.records.save(new CaptureRecord("rec-" + spawnId, userId, spawnId,
                "ch-" + spawnId, at));
    }

    @Test
    @DisplayName("TC-D01 无收录：图鉴返回全部目录条目且未解锁，背包为空")
    void emptyCollection() {
        DexResponse dex = support.collectionService.dex(USER);

        assertEquals(1, dex.totalSpeciesCount());
        assertEquals(0, dex.collectedSpeciesCount());
        assertEquals(1, dex.entries().size());
        assertEquals(SPECIES, dex.entries().get(0).speciesId());
        assertEquals("攻城狮", dex.entries().get(0).name());
        assertEquals(0, dex.entries().get(0).count());
        assertNull(dex.entries().get(0).firstCapturedAt());

        BagResponse bag = support.collectionService.bag(USER);
        assertEquals(0, bag.totalCount());
        assertEquals(0, bag.speciesCount());
        assertTrue(bag.entries().isEmpty());
    }

    @Test
    @DisplayName("TC-D02 收录一次：图鉴、背包与概览三者数字一致")
    void oneCaptureConsistentAcrossViews() {
        Instant capturedAt = Instant.parse("2026-11-16T02:30:00Z");
        seedCapture(USER, "spawn-a", capturedAt);

        DexResponse dex = support.collectionService.dex(USER);
        BagResponse bag = support.collectionService.bag(USER);
        CollectionSummaryResponse summary = support.collectionService.summary(USER);

        assertEquals(1, dex.collectedSpeciesCount());
        assertEquals(1, dex.entries().get(0).count());
        assertEquals(capturedAt, dex.entries().get(0).firstCapturedAt());

        assertEquals(1, bag.totalCount());
        assertEquals(1, bag.entries().size());
        assertEquals(SPECIES, bag.entries().get(0).speciesId());
        assertEquals("攻城狮", bag.entries().get(0).name());
        assertEquals(capturedAt, bag.entries().get(0).latestCapturedAt());

        assertEquals(1, summary.collectedSpeciesCount());
        assertEquals(1, summary.captureCount());
        assertEquals(1, summary.totalSpeciesCount());
    }

    @Test
    @DisplayName("TC-D03 重复收录同一物种：数量累加，首次收录时刻不变")
    void duplicateSpecies() {
        Instant first = Instant.parse("2026-11-16T02:00:00Z");
        Instant second = Instant.parse("2026-11-16T03:00:00Z");
        seedCapture(USER, "spawn-a", first);
        seedCapture(USER, "spawn-b", second);

        DexResponse dex = support.collectionService.dex(USER);
        BagResponse bag = support.collectionService.bag(USER);

        assertEquals(1, dex.collectedSpeciesCount());
        assertEquals(2, dex.entries().get(0).count());
        assertEquals(first, dex.entries().get(0).firstCapturedAt());

        assertEquals(2, bag.totalCount());
        assertEquals(1, bag.entries().size());
        assertEquals(second, bag.entries().get(0).latestCapturedAt());
    }

    @Test
    @DisplayName("TC-D04 跨用户隔离：他人收录不计入本人图鉴与背包")
    void isolationBetweenUsers() {
        seedCapture(OTHER, "spawn-x", Instant.parse("2026-11-16T02:00:00Z"));

        assertEquals(0, support.collectionService.dex(USER).collectedSpeciesCount());
        assertTrue(support.collectionService.bag(USER).entries().isEmpty());
        assertEquals(0, support.collectionService.summary(USER).captureCount());

        assertEquals(1, support.collectionService.bag(OTHER).totalCount());
    }

    @Test
    @DisplayName("TC-D05 遭遇已不存在：跳过该记录，不猜测物种")
    void recordWithoutSpawnIsSkipped() {
        support.records.save(new CaptureRecord("rec-orphan", USER, "spawn-missing",
                "ch-orphan", Instant.parse("2026-11-16T02:00:00Z")));

        assertEquals(0, support.collectionService.dex(USER).collectedSpeciesCount());
        assertTrue(support.collectionService.bag(USER).entries().isEmpty());
        assertEquals(1, support.collectionService.summary(USER).captureCount());
    }
}
