package edu.pkmon.study.domain;

/**
 * 驻留规则参数。全部由服务端配置注入，客户端不能指定阈值或奖励条件。
 *
 * @param enterRadiusMeters 进入半径（米）
 * @param exitRadiusMeters 退出半径（米），用于缓冲区判定
 * @param maxAccuracyMeters 可采纳样本的最大精度（米）
 * @param maxSampleAgeSeconds 样本允许的最大年龄（秒）
 * @param maxFutureSkewSeconds 样本时间允许超前服务器的时间（秒），0～该值的偏差截到服务器当前时间
 * @param maxSampleGapSeconds 相邻合格样本允许的最大间隔（秒），超过即失联
 * @param requiredSeconds 触发所需的累计有效停留（秒）
 * @param cooldownSeconds 结束后的任务冷却（秒）
 */
public record DwellRules(
        double enterRadiusMeters,
        double exitRadiusMeters,
        double maxAccuracyMeters,
        int maxSampleAgeSeconds,
        int maxFutureSkewSeconds,
        int maxSampleGapSeconds,
        long requiredSeconds,
        long cooldownSeconds) {

    /** 参数只要不自洽就无法给出确定结论，因此构造时直接拒绝。 */
    public DwellRules {
        if (!(enterRadiusMeters > 0) || !(exitRadiusMeters >= enterRadiusMeters)) {
            throw new IllegalArgumentException("半径必须为正，且退出半径不小于进入半径");
        }
        if (!(maxAccuracyMeters > 0) || !(maxAccuracyMeters < enterRadiusMeters)) {
            throw new IllegalArgumentException("精度上限必须为正且小于进入半径");
        }
        if (maxSampleAgeSeconds <= 0 || maxFutureSkewSeconds < 0 || maxSampleGapSeconds <= 0) {
            throw new IllegalArgumentException("样本时间与间隔参数必须为正");
        }
        if (requiredSeconds <= 0 || cooldownSeconds < 0) {
            throw new IllegalArgumentException("阈值与冷却必须为正");
        }
    }

    /**
     * 正式演示使用 600 秒阈值。
     *
     * @return 正式参数
     */
    public static DwellRules production() {
        return new DwellRules(80, 100, 50, 30, 5, 30, 600, 1800);
    }

    /**
     * 自动化测试使用 60 秒阈值，其余参数与正式一致。
     *
     * @return 测试参数
     */
    public static DwellRules testRules() {
        return new DwellRules(80, 100, 50, 30, 5, 30, 60, 1800);
    }
}
