package edu.pkmon.study.config;

import edu.pkmon.study.domain.DwellRules;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 自习任务的规则参数，全部可由配置文件覆盖，客户端不可指定。
 *
 * <p>默认值与 design.txt 第八节一致：进入 80 米、退出 100 米、精度 50 米、样本年龄 30 秒、
 * 未来偏差 5 秒、间隔 30 秒、阈值 600 秒、冷却 1800 秒。测试 profile 覆盖 required-seconds=60。</p>
 */
@ConfigurationProperties(prefix = "pkmon.study.rules")
public class StudyRulesProperties {

    private double enterRadiusMeters = 80;
    private double exitRadiusMeters = 100;
    private double maxAccuracyMeters = 50;
    private int maxSampleAgeSeconds = 30;
    private int maxFutureSkewSeconds = 5;
    private int maxSampleGapSeconds = 30;
    private long requiredSeconds = 600;
    private long cooldownSeconds = 1800;

    /**
     * 转成不可变的规则参数，构造时校验自洽性。
     *
     * @return 规则参数
     */
    public DwellRules toRules() {
        return new DwellRules(enterRadiusMeters, exitRadiusMeters, maxAccuracyMeters, maxSampleAgeSeconds,
                maxFutureSkewSeconds, maxSampleGapSeconds, requiredSeconds, cooldownSeconds);
    }

    public double getEnterRadiusMeters() {
        return enterRadiusMeters;
    }

    public void setEnterRadiusMeters(double value) {
        this.enterRadiusMeters = value;
    }

    public double getExitRadiusMeters() {
        return exitRadiusMeters;
    }

    public void setExitRadiusMeters(double value) {
        this.exitRadiusMeters = value;
    }

    public double getMaxAccuracyMeters() {
        return maxAccuracyMeters;
    }

    public void setMaxAccuracyMeters(double value) {
        this.maxAccuracyMeters = value;
    }

    public int getMaxSampleAgeSeconds() {
        return maxSampleAgeSeconds;
    }

    public void setMaxSampleAgeSeconds(int value) {
        this.maxSampleAgeSeconds = value;
    }

    public int getMaxFutureSkewSeconds() {
        return maxFutureSkewSeconds;
    }

    public void setMaxFutureSkewSeconds(int value) {
        this.maxFutureSkewSeconds = value;
    }

    public int getMaxSampleGapSeconds() {
        return maxSampleGapSeconds;
    }

    public void setMaxSampleGapSeconds(int value) {
        this.maxSampleGapSeconds = value;
    }

    public long getRequiredSeconds() {
        return requiredSeconds;
    }

    public void setRequiredSeconds(long value) {
        this.requiredSeconds = value;
    }

    public long getCooldownSeconds() {
        return cooldownSeconds;
    }

    public void setCooldownSeconds(long value) {
        this.cooldownSeconds = value;
    }
}
