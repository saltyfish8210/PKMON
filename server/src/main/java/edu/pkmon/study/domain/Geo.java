package edu.pkmon.study.domain;

/**
 * 球面距离计算。规则测试只使用合成距离，不依赖真实校园轨迹。
 */
public final class Geo {

    /** 地球平均半径（米），WGS84 均值取整。 */
    private static final double EARTH_RADIUS_METERS = 6_371_000d;

    private Geo() {
    }

    /**
     * 用 haversine 公式计算两点间地表距离。
     *
     * @param lat1 第一点纬度（度）
     * @param lon1 第一点经度（度）
     * @param lat2 第二点纬度（度）
     * @param lon2 第二点经度（度）
     * @return 距离（米）
     */
    public static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1, Math.sqrt(a)));
    }

    /**
     * 按正北方向偏移给定距离，供合成样本构造使用。
     *
     * @param latitude 起点纬度（度）
     * @param longitude 起点经度（度）
     * @param meters 向北偏移距离（米），负值向南
     * @return 纬度偏移后的坐标
     */
    public static double latitudeOffset(double latitude, double meters) {
        return latitude + Math.toDegrees(meters / EARTH_RADIUS_METERS);
    }
}
