package edu.pkmon.study.domain;

import java.time.Instant;
import java.util.Objects;

/**
 * 一次位置输入。字段名与接口一致，接口只接受 GCJ02。
 *
 * @param sampleId 客户端生成的一次采样编号，任务内唯一
 * @param latitude 纬度（GCJ02）
 * @param longitude 经度（GCJ02）
 * @param accuracyMeters 水平精度（米）
 * @param sampledAt 采样时刻（UTC）
 * @param coordinateSystem 坐标系标签，接口候选只接受 GCJ02
 * @param source 来源，GPS 或 SIMULATED
 */
public record LocationSample(
        String sampleId,
        double latitude,
        double longitude,
        double accuracyMeters,
        Instant sampledAt,
        String coordinateSystem,
        String source) {

    /** 必填字段缺失时直接拒绝，不能进入规则计算。 */
    public LocationSample {
        Objects.requireNonNull(sampleId, "sampleId");
        Objects.requireNonNull(sampledAt, "sampledAt");
        Objects.requireNonNull(coordinateSystem, "coordinateSystem");
        Objects.requireNonNull(source, "source");
        if (sampleId.isBlank()) {
            throw new IllegalArgumentException("sampleId 不能为空");
        }
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            throw new IllegalArgumentException("经纬度超出范围");
        }
        if (Double.isNaN(accuracyMeters) || accuracyMeters < 0) {
            throw new IllegalArgumentException("accuracyMeters 不能为负");
        }
    }

    /**
     * 判断坐标系是否可直接参与距离计算。
     *
     * @return 标签为 GCJ02 时为 true
     */
    public boolean isGcj02() {
        return "GCJ02".equalsIgnoreCase(coordinateSystem);
    }

    /**
     * 判断来源是否为模拟定位。
     *
     * @return 来源为 SIMULATED 时为 true
     */
    public boolean isSimulated() {
        return "SIMULATED".equalsIgnoreCase(source);
    }

    /**
     * 判断两个样本的业务内容是否相同，用于重复 sampleId 的幂等比较。
     *
     * @param other 另一个样本
     * @return 除编号外字段完全一致时为 true
     */
    public boolean sameContent(LocationSample other) {
        return other != null
                && Double.compare(latitude, other.latitude) == 0
                && Double.compare(longitude, other.longitude) == 0
                && Double.compare(accuracyMeters, other.accuracyMeters) == 0
                && sampledAt.equals(other.sampledAt)
                && coordinateSystem.equalsIgnoreCase(other.coordinateSystem)
                && source.equalsIgnoreCase(other.source);
    }
}
