import 'package:latlong2/latlong.dart';

/// 校园地点（地图经纬度 / GCJ-02）。
///
/// 取点来源与日期：2026-11-25 用 OpenStreetMap 的公开地物坐标取出原始经纬度，
/// 再用 `gpsToMap()` 换算成地图经纬度；每个点都记录了来源地物名称，便于复核。
///
/// 待办：理科楼群尚未取到可靠坐标，当前第五个点先用「博雅塔」代替，
/// 后续在高德底图上取点后补上并更新本文件（不要凭印象填）。
class CampusPoint {
  const CampusPoint({
    required this.id,
    required this.name,
    required this.position,
    required this.radius,
    required this.source,
  });

  /// 英文短 id，用作地图标记 key。
  final String id;

  /// 中文名，显示在地图上。
  final String name;

  /// 地图经纬度（GCJ-02）。
  final LatLng position;

  /// 进入半径，米。
  final double radius;

  /// 坐标来源说明（地物名 + 取点日期）。
  final String source;
}

const List<CampusPoint> campusPoints = <CampusPoint>[
  CampusPoint(
    id: 'library',
    name: '图书馆',
    position: LatLng(39.991863, 116.309880),
    radius: 80,
    source: 'OSM 北京大学图书馆，2026-11-25 换算',
  ),
  CampusPoint(
    id: 'lake',
    name: '未名湖',
    position: LatLng(39.994330, 116.308210),
    radius: 120,
    source: 'OSM 未名湖南路/北路/石/西路 四点均值，2026-11-25 换算',
  ),
  CampusPoint(
    id: 'dorm',
    name: '宿舍区',
    position: LatLng(40.003065, 116.305994),
    radius: 150,
    source: 'OSM 学生宿舍 1-4 号楼四点均值，2026-11-25 换算',
  ),
  CampusPoint(
    id: 'east_gate',
    name: '东门',
    position: LatLng(39.992062, 116.315830),
    radius: 60,
    source: 'OSM 北京大学东门，2026-11-25 换算',
  ),
  CampusPoint(
    id: 'boya_tower',
    name: '博雅塔',
    position: LatLng(39.993917, 116.311881),
    radius: 60,
    source: 'OSM 博雅塔，2026-11-25 换算（暂代理科楼群）',
  ),
];

/// 按 id 取地点，找不到返回 null。
CampusPoint? campusPointById(String id) {
  for (final p in campusPoints) {
    if (p.id == id) return p;
  }
  return null;
}
