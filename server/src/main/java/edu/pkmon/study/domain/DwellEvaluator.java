package edu.pkmon.study.domain;

import java.time.Duration;
import java.time.Instant;
import java.util.Objects;

/**
 * 自习驻留的纯规则实现（规则来源：docs/stage2/members/dongxinyu/design/design.txt）。
 *
 * <p>输入为旧状态、位置样本、区域、注入的服务器时间和规则参数；输出为新状态与触发决定。不访问数据库、
 * 网络和真实时钟，因此 59/60/61 秒边界可以用固定时间瞬间验证，不需要真实等待十分钟。</p>
 *
 * <p>规则摘要：</p>
 * <ul>
 *   <li>首个进入半径内的合格样本只作为候选；第二条连续合格样本确认 DWELLING，并从第二条样本时刻开始累计。</li>
 *   <li>已确认 DWELLING 时，只有前后两条合格样本都在退出半径内且间隔不超过 30 秒才累计该间隔。</li>
 *   <li>第一次超出退出半径不计该段；连续第二次超出暂停为 OUTSIDE；缓冲区（进入与退出半径之间）保持已确认状态。</li>
 *   <li>超过 30 秒没有合格样本时，由 {@link #onTick(DwellState, Instant)} 推进为 NO_SIGNAL，不依赖新样本到达。</li>
 *   <li>恢复或再次进入同样需要两条合格样本，期间不补算。</li>
 *   <li>达到阈值只触发一次；触发后状态与有效时长固定。</li>
 * </ul>
 */
public final class DwellEvaluator {

    private final DwellRules rules;

    /**
     * @param rules 规则参数，必须为正且自洽
     */
    public DwellEvaluator(DwellRules rules) {
        this.rules = Objects.requireNonNull(rules, "rules");
    }

    /**
     * 读取当前规则参数。
     *
     * @return 规则参数
     */
    public DwellRules rules() {
        return rules;
    }

    /**
     * 处理一条位置样本。
     *
     * @param state 旧状态
     * @param region 任务区域
     * @param sample 位置样本
     * @param now 服务器当前时间，由注入的 Clock 提供
     * @return 新状态与触发决定
     */
    public DwellDecision onSample(DwellState state, Region region, LocationSample sample, Instant now) {
        Objects.requireNonNull(state, "state");
        Objects.requireNonNull(region, "region");
        Objects.requireNonNull(sample, "sample");
        Objects.requireNonNull(now, "now");

        if (state.status() == TaskStatus.ENDED) {
            return DwellDecision.rejected(state, RejectionReason.TASK_ENDED);
        }
        if (sample.sampledAt().isAfter(now.plusSeconds(rules.maxFutureSkewSeconds()))) {
            return DwellDecision.rejected(state, RejectionReason.FUTURE_SAMPLE);
        }
        if (sample.sampledAt().isBefore(now.minusSeconds(rules.maxSampleAgeSeconds()))) {
            return DwellDecision.rejected(state, RejectionReason.SAMPLE_TOO_OLD);
        }
        Instant sampledAt = sample.sampledAt().isAfter(now) ? now : sample.sampledAt();
        if (sample.accuracyMeters() > rules.maxAccuracyMeters()) {
            return DwellDecision.rejected(state, RejectionReason.LOW_ACCURACY);
        }
        if (!region.coordinateSystem().equalsIgnoreCase(sample.coordinateSystem())) {
            return DwellDecision.rejected(state, RejectionReason.UNSUPPORTED_COORDINATE_SYSTEM);
        }
        if (sample.sampleId().equals(state.lastSampleId())) {
            return DwellDecision.rejected(state, RejectionReason.DUPLICATE_SAMPLE);
        }
        if (state.lastSampledAt() != null && !sampledAt.isAfter(state.lastSampledAt())) {
            return DwellDecision.rejected(state, RejectionReason.OUT_OF_ORDER);
        }

        double distance = Geo.distanceMeters(region.centerLatitude(), region.centerLongitude(),
                sample.latitude(), sample.longitude());
        boolean inside = distance <= region.enterRadiusMeters();
        boolean withinExit = distance <= region.exitRadiusMeters();
        long gapSeconds = state.lastAcceptedAt() == null
                ? 0
                : Math.max(0, Duration.between(state.lastAcceptedAt(), sampledAt).getSeconds());
        boolean continuous = state.lastAcceptedAt() != null && gapSeconds <= rules.maxSampleGapSeconds();

        Acc acc = new Acc(state);
        switch (state.status()) {
            case WAITING -> handleWaiting(acc, inside, withinExit, continuous);
            case DWELLING -> handleDwelling(acc, inside, withinExit, continuous, gapSeconds);
            case PAUSED -> handlePaused(acc, inside, withinExit, continuous);
            case TRIGGERED -> {
                // 触发结果固定，后续样本只更新样本记录，不改变时长与状态。
            }
            case ENDED -> throw new IllegalStateException("ENDED 已在入口处拒绝");
        }

        acc.lastSampledAt = sampledAt;
        acc.lastAcceptedAt = sampledAt;
        acc.lastLatitude = sample.latitude();
        acc.lastLongitude = sample.longitude();
        acc.lastSampleInside = inside;
        acc.lastSampleId = sample.sampleId();

        long accumulated = acc.effectiveSeconds - state.effectiveSeconds();
        boolean triggeredNow = acc.status == TaskStatus.TRIGGERED && !state.triggered();
        return DwellDecision.accepted(acc.toState(), triggeredNow, accumulated);
    }

    /**
     * 不依赖新样本，按注入时间推进失联判定。
     *
     * @param state 旧状态
     * @param now 服务器当前时间
     * @return 新状态；未超时时原样返回
     */
    public DwellState onTick(DwellState state, Instant now) {
        Objects.requireNonNull(state, "state");
        Objects.requireNonNull(now, "now");
        boolean watching = state.status() == TaskStatus.WAITING || state.status() == TaskStatus.DWELLING;
        if (!watching || state.lastAcceptedAt() == null) {
            return state;
        }
        if (Duration.between(state.lastAcceptedAt(), now).getSeconds() <= rules.maxSampleGapSeconds()) {
            return state;
        }
        Acc acc = new Acc(state);
        acc.status = TaskStatus.PAUSED;
        acc.pauseReason = PauseReason.NO_SIGNAL;
        acc.chainValid = false;
        acc.insideCount = 0;
        acc.outsideCount = 0;
        return acc.toState();
    }

    private void handleWaiting(Acc acc, boolean inside, boolean withinExit, boolean continuous) {
        if (!continuous) {
            acc.insideCount = inside ? 1 : 0;
            acc.outsideCount = 0;
            acc.chainValid = false;
            return;
        }
        if (inside) {
            acc.insideCount++;
            acc.outsideCount = 0;
            if (acc.insideCount >= 2) {
                acc.status = TaskStatus.DWELLING;
                acc.chainValid = true;
            }
            return;
        }
        acc.insideCount = 0;
        acc.outsideCount = withinExit ? 0 : Math.min(acc.outsideCount + 1, 2);
    }

    private void handleDwelling(Acc acc, boolean inside, boolean withinExit, boolean continuous, long gapSeconds) {
        if (!continuous) {
            acc.status = TaskStatus.PAUSED;
            acc.pauseReason = PauseReason.NO_SIGNAL;
            acc.chainValid = false;
            acc.insideCount = inside ? 1 : 0;
            acc.outsideCount = 0;
            return;
        }
        if (!withinExit) {
            acc.outsideCount++;
            acc.insideCount = 0;
            if (acc.outsideCount >= 2) {
                acc.status = TaskStatus.PAUSED;
                acc.pauseReason = PauseReason.OUTSIDE;
                acc.chainValid = false;
            }
            return;
        }
        acc.effectiveSeconds += gapSeconds;
        acc.outsideCount = 0;
        acc.insideCount = inside ? acc.insideCount + 1 : 0;
        if (acc.effectiveSeconds >= rules.requiredSeconds()) {
            acc.effectiveSeconds = rules.requiredSeconds();
            acc.triggered = true;
            acc.status = TaskStatus.TRIGGERED;
            acc.pauseReason = null;
        }
    }

    private void handlePaused(Acc acc, boolean inside, boolean withinExit, boolean continuous) {
        if (!continuous) {
            acc.pauseReason = PauseReason.NO_SIGNAL;
            acc.chainValid = false;
            acc.insideCount = inside ? 1 : 0;
            acc.outsideCount = 0;
            return;
        }
        if (inside) {
            acc.insideCount++;
            if (acc.insideCount >= 2) {
                acc.status = TaskStatus.DWELLING;
                acc.pauseReason = null;
                acc.chainValid = true;
                acc.outsideCount = 0;
            }
            return;
        }
        acc.insideCount = 0;
        acc.outsideCount = withinExit ? 0 : Math.min(acc.outsideCount + 1, 2);
    }

    /** 评估过程中的可变累加器，只在一次调用内使用。 */
    private static final class Acc {
        private TaskStatus status;
        private PauseReason pauseReason;
        private long effectiveSeconds;
        private final long requiredSeconds;
        private int insideCount;
        private int outsideCount;
        private boolean chainValid;
        private Instant lastAcceptedAt;
        private Instant lastSampledAt;
        private Double lastLatitude;
        private Double lastLongitude;
        private boolean lastSampleInside;
        private String lastSampleId;
        private boolean triggered;
        private final String taskId;

        private Acc(DwellState state) {
            this.taskId = state.taskId();
            this.status = state.status();
            this.pauseReason = state.pauseReason();
            this.effectiveSeconds = state.effectiveSeconds();
            this.requiredSeconds = state.requiredSeconds();
            this.insideCount = state.insideCount();
            this.outsideCount = state.outsideCount();
            this.chainValid = state.chainValid();
            this.lastAcceptedAt = state.lastAcceptedAt();
            this.lastSampledAt = state.lastSampledAt();
            this.lastLatitude = state.lastLatitude();
            this.lastLongitude = state.lastLongitude();
            this.lastSampleInside = state.lastSampleInside();
            this.lastSampleId = state.lastSampleId();
            this.triggered = state.triggered();
        }

        private DwellState toState() {
            return new DwellState(taskId, status, pauseReason, effectiveSeconds, requiredSeconds,
                    insideCount, outsideCount, chainValid, lastAcceptedAt, lastSampledAt,
                    lastLatitude, lastLongitude, lastSampleInside, lastSampleId, triggered);
        }
    }
}
