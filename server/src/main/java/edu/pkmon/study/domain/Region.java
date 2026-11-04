package edu.pkmon.study.domain;

/**
 * 可驻留区域。本阶段使用圆形围栏，中心点未确认时区域不可启用。
 *
 * @param regionId 业务键，例如 library_entrance
 * @param centerLatitude 中心纬度（与 coordinateSystem 一致）
 * @param centerLongitude 中心经度（与 coordinateSystem 一致）
 * @param enterRadiusMeters 进入半径（米）
 * @param exitRadiusMeters 退出半径（米）
 * @param enabled 是否启用
 */
public record Region(
        String regionId,
        double centerLatitude,
        double centerLongitude,
        double enterRadiusMeters,
        double exitRadiusMeters,
        boolean enabled,
        String coordinateSystem) {

    /** 区域是规则输入，半径必须自洽。 */
    public Region {
        if (!"GCJ02".equals(coordinateSystem) && !"WGS84".equals(coordinateSystem)) throw new IllegalArgumentException("Unsupported region coordinate system");
        if (!Double.isFinite(centerLatitude) || Math.abs(centerLatitude)>90 || !Double.isFinite(centerLongitude) || Math.abs(centerLongitude)>180) throw new IllegalArgumentException("Invalid region center");
        if (regionId == null || regionId.isBlank()) {
            throw new IllegalArgumentException("regionId 不能为空");
        }
        if (!(enterRadiusMeters > 0) || !(exitRadiusMeters >= enterRadiusMeters)) {
            throw new IllegalArgumentException("区域半径必须为正，且退出半径不小于进入半径");
        }
    }

    /**
     * 由全局规则构造一个使用默认半径的区域，供合成测试使用。
     *
     * @param regionId 区域业务键
     * @param latitude 中心纬度
     * @param longitude 中心经度
     * @param rules 规则参数
     * @return 区域
     */
    public static Region of(String regionId, double latitude, double longitude, DwellRules rules) {
        return new Region(regionId, latitude, longitude,
                rules.enterRadiusMeters(), rules.exitRadiusMeters(), true, "GCJ02");
    }
}
