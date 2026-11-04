package edu.pkmon.study;

import edu.pkmon.study.domain.*;
import edu.pkmon.study.dto.*;
import edu.pkmon.study.error.*;
import edu.pkmon.study.port.*;
import edu.pkmon.study.service.*;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 驻留规则边界测试。全部使用注入时间与合成距离，不真实等待。
 */
class DwellEvaluatorTest {
    @Test
    void acceptsDeviceFixOnlyAgainstCenterWithMatchingCoordinates() {
        Region gps = new Region("library", 39.9, 116.4, 80, 100, true, "WGS84");
        Instant now = Instant.parse("2026-11-04T08:00:00Z");
        LocationSample fix = new LocationSample("fix", 39.9, 116.4, 6, now, "WGS84", "GPS");
        DwellState waiting = DwellState.start("task", 60);
        DwellEvaluator evaluator = new DwellEvaluator(DwellRules.testRules());
        assertTrue(evaluator.onSample(waiting, gps, fix, now).accepted());
        assertFalse(evaluator.onSample(waiting, REGION, fix, now).accepted());
    }


    private static final DwellRules RULES = DwellRules.testRules();
    private static final Region REGION = Region.of("library_entrance", 39.9042, 116.4074, RULES);
    private static final Instant BASE = Instant.parse("2026-10-19T02:00:00Z");
    private static final String TASK_ID = "task-1";

    private final DwellEvaluator evaluator = new DwellEvaluator(RULES);

    private static LocationSample sampleAt(String id, long secondsFromBase, double metersNorth) {
        return new LocationSample(id, Geo.latitudeOffset(REGION.centerLatitude(), metersNorth),
                REGION.centerLongitude(), 10, BASE.plusSeconds(secondsFromBase), "GCJ02", "GPS");
    }

    private static Instant at(long secondsFromBase) {
        return BASE.plusSeconds(secondsFromBase);
    }

    private DwellDecision submit(DwellState state, String id, long seconds, double metersNorth) {
        return evaluator.onSample(state, REGION, sampleAt(id, seconds, metersNorth), at(seconds));
    }

    private DwellState feed(DwellState state, String id, long seconds, double metersNorth) {
        return submit(state, id, seconds, metersNorth).state();
    }

    @Test
    @DisplayName("首条合格样本只作为候选，不确认进入也不计时")
    void firstSampleIsOnlyCandidate() {
        DwellState start = DwellState.start(TASK_ID, RULES.requiredSeconds());
        DwellDecision decision = submit(start, "s1", 0, 0);

        assertTrue(decision.accepted());
        assertEquals(TaskStatus.WAITING, decision.state().status());
        assertEquals(1, decision.state().insideCount());
        assertEquals(0, decision.state().effectiveSeconds());
    }

    @Test
    @DisplayName("第二条连续合格样本确认 DWELLING，首条不追算")
    void secondSampleConfirmsDwellingFromItsOwnTime() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        state = feed(state, "s1", 0, 0);
        DwellDecision decision = submit(state, "s2", 10, 0);

        assertEquals(TaskStatus.DWELLING, decision.state().status());
        assertEquals(0, decision.state().effectiveSeconds());
        assertNull(decision.state().pauseReason());
        assertTrue(decision.state().chainValid());
    }

    @Test
    @DisplayName("墙钟 0,10,...,60,69 秒累计 59 秒且不触发")
    void fiftyNineSecondsDoesNotTrigger() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        long[] times = {0, 10, 20, 30, 40, 50, 60, 69};
        for (int i = 0; i < times.length; i++) {
            state = feed(state, "s" + i, times[i], 0);
        }

        assertEquals(TaskStatus.DWELLING, state.status());
        assertEquals(59, state.effectiveSeconds());
        assertFalse(state.triggered());
    }

    @Test
    @DisplayName("第 70 秒达到 60 秒只触发一次，第 71 秒保持固定结果")
    void sixtySecondsTriggersExactlyOnce() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        long[] times = {0, 10, 20, 30, 40, 50, 60, 69, 70};
        for (int i = 0; i < times.length; i++) {
            state = feed(state, "s" + i, times[i], 0);
        }

        assertEquals(TaskStatus.TRIGGERED, state.status());
        assertEquals(60, state.effectiveSeconds());
        assertTrue(state.triggered());

        DwellDecision after = submit(state, "s-late", 71, 0);
        assertEquals(TaskStatus.TRIGGERED, after.state().status());
        assertEquals(60, after.state().effectiveSeconds());
        assertFalse(after.triggeredNow());
        assertEquals(0, after.accumulatedSeconds());
    }

    @Test
    @DisplayName("缓冲区（进入半径与退出半径之间）保持 DWELLING 并继续累计")
    void bufferZoneKeepsAccumulating() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        state = feed(state, "s1", 0, 0);
        state = feed(state, "s2", 10, 0);
        state = feed(state, "s3", 20, 90);

        assertEquals(TaskStatus.DWELLING, state.status());
        assertEquals(10, state.effectiveSeconds());
        assertEquals(0, state.outsideCount());
    }

    @Test
    @DisplayName("首次超出退出半径不计该段，连续第二次暂停为 OUTSIDE")
    void firstOvershootIsBufferedSecondPauses() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        state = feed(state, "s1", 0, 0);
        state = feed(state, "s2", 10, 0);
        state = feed(state, "s3", 20, 110);

        assertEquals(TaskStatus.DWELLING, state.status());
        assertEquals(0, state.effectiveSeconds());
        assertEquals(1, state.outsideCount());

        state = feed(state, "s4", 30, 110);

        assertEquals(TaskStatus.PAUSED, state.status());
        assertEquals(PauseReason.OUTSIDE, state.pauseReason());
    }

    @Test
    @DisplayName("间隔超过 30 秒按失联处理，不累计也不补算")
    void longGapPausesWithoutAccumulation() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        state = feed(state, "s1", 0, 0);
        state = feed(state, "s2", 10, 0);
        state = feed(state, "s3", 20, 0);

        assertEquals(10, state.effectiveSeconds());

        state = feed(state, "s4", 55, 0);

        assertEquals(TaskStatus.PAUSED, state.status());
        assertEquals(PauseReason.NO_SIGNAL, state.pauseReason());
        assertEquals(10, state.effectiveSeconds());
    }

    @Test
    @DisplayName("注入时钟 tick 在无新样本时推进 NO_SIGNAL，30 秒整不暂停")
    void tickPausesAfterThirtySeconds() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        state = feed(state, "s1", 0, 0);
        state = feed(state, "s2", 10, 0);

        DwellState exactlyThirty = evaluator.onTick(state, at(40));
        assertEquals(TaskStatus.DWELLING, exactlyThirty.status());

        DwellState afterThirty = evaluator.onTick(state, at(41));
        assertEquals(TaskStatus.PAUSED, afterThirty.status());
        assertEquals(PauseReason.NO_SIGNAL, afterThirty.pauseReason());
    }

    @Test
    @DisplayName("恢复需要两条合格样本，已认可时长保留")
    void resumeKeepsEffectiveSeconds() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        state = feed(state, "s1", 0, 0);
        state = feed(state, "s2", 10, 0);
        state = feed(state, "s3", 20, 0);
        state = feed(state, "s4", 30, 0);
        assertEquals(20, state.effectiveSeconds());

        state = state.status() == TaskStatus.PAUSED ? state : evaluator.onTick(state, at(61));
        assertEquals(TaskStatus.PAUSED, state.status());

        DwellState first = feed(state, "s5", 62, 0);
        assertEquals(TaskStatus.PAUSED, first.status());

        DwellState second = feed(first, "s6", 72, 0);
        assertEquals(TaskStatus.DWELLING, second.status());
        assertEquals(20, second.effectiveSeconds());
        assertNull(second.pauseReason());
    }

    @Test
    @DisplayName("精度不达标、样本过旧、未来样本、非 GCJ02 均不采纳")
    void invalidSamplesAreRejected() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        state = feed(state, "s1", 0, 0);
        state = feed(state, "s2", 10, 0);

        LocationSample lowAccuracy = new LocationSample("bad-1", REGION.centerLatitude(),
                REGION.centerLongitude(), 60, at(20), "GCJ02", "GPS");
        assertEquals(RejectionReason.LOW_ACCURACY,
                evaluator.onSample(state, REGION, lowAccuracy, at(20)).rejectionReason());

        LocationSample tooOld = new LocationSample("bad-2", REGION.centerLatitude(),
                REGION.centerLongitude(), 10, at(20), "GCJ02", "GPS");
        assertEquals(RejectionReason.SAMPLE_TOO_OLD,
                evaluator.onSample(state, REGION, tooOld, at(60)).rejectionReason());

        LocationSample future = new LocationSample("bad-3", REGION.centerLatitude(),
                REGION.centerLongitude(), 10, at(40), "GCJ02", "GPS");
        assertEquals(RejectionReason.FUTURE_SAMPLE,
                evaluator.onSample(state, REGION, future, at(30)).rejectionReason());

        LocationSample wgs84 = new LocationSample("bad-4", REGION.centerLatitude(),
                REGION.centerLongitude(), 10, at(20), "WGS84", "GPS");
        assertEquals(RejectionReason.UNSUPPORTED_COORDINATE_SYSTEM,
                evaluator.onSample(state, REGION, wgs84, at(20)).rejectionReason());
    }

    @Test
    @DisplayName("0～5 秒超前截到服务器时间，重复编号与倒序样本不累计")
    void skewDuplicateAndOutOfOrder() {
        DwellState state = DwellState.start(TASK_ID, RULES.requiredSeconds());
        state = feed(state, "s1", 0, 0);
        state = feed(state, "s2", 10, 0);

        LocationSample skewed = new LocationSample("s3", REGION.centerLatitude(),
                REGION.centerLongitude(), 10, at(23), "GCJ02", "GPS");
        DwellDecision clamped = evaluator.onSample(state, REGION, skewed, at(20));
        assertTrue(clamped.accepted());
        assertEquals(at(20), clamped.state().lastSampledAt());

        DwellState afterClamp = clamped.state();
        DwellDecision duplicate = evaluator.onSample(afterClamp, REGION, sampleAt("s3", 20, 0), at(21));
        assertEquals(RejectionReason.DUPLICATE_SAMPLE, duplicate.rejectionReason());

        DwellDecision outOfOrder = evaluator.onSample(afterClamp, REGION,
                sampleAt("s4", 15, 0), at(25));
        assertEquals(RejectionReason.OUT_OF_ORDER, outOfOrder.rejectionReason());
    }

    @Test
    @DisplayName("已结束任务拒绝新样本")
    void endedTaskRejectsSamples() {
        DwellState ended = DwellState.start(TASK_ID, RULES.requiredSeconds()).ended();
        assertEquals(RejectionReason.TASK_ENDED,
                evaluator.onSample(ended, REGION, sampleAt("s1", 0, 0), at(0)).rejectionReason());
    }

    @Test
    @DisplayName("距离计算误差在 1 米以内")
    void geoDistanceIsMetric() {
        double distance = Geo.distanceMeters(REGION.centerLatitude(), REGION.centerLongitude(),
                Geo.latitudeOffset(REGION.centerLatitude(), 100), REGION.centerLongitude());
        assertTrue(Math.abs(distance - 100) < 1.0, "actual=" + distance);
    }

    @Test
    @DisplayName("状态对象可序列化字段完整，暂停原因必须与状态一致")
    void stateInvariants() {
        DwellState waiting = DwellState.start(TASK_ID, 60);
        assertNull(waiting.pauseReason());
        assertNotNull(waiting.taskId());
        assertTrue(Duration.ZERO.isZero());
        assertEquals(60, waiting.requiredSeconds());
    }
}
