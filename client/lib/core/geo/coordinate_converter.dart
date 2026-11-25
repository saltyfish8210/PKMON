library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// 两套经纬度之间的换算。
///
/// 同一栋楼有两套门牌号：
///   * 手机 GPS 给的是「GPS 原始经纬度」（WGS-84，国际通用）；
///   * 高德、腾讯等国内地图用的是「地图经纬度」（GCJ-02，加了偏移）。
/// 两者在北大附近差约 500 米，所以手机数据上地图前必须换一次。
///
/// 使用规则（三条，别搞反）：
///   1. 手机链路：geolocator 给的是 GPS 原始经纬度 → 先 [gpsToMap] 再上图、再上传。
///   2. 地图点选：点击地图拿到的已经是地图经纬度 → 不要再换。
///   3. 上报服务端时 coordinateSystem 填 GCJ02，source 填 GPS 或 SIMULATED。

const double _a = 6378245.0;
const double _ee = 0.00669342162296594323;

bool _outOfChina(double lat, double lng) =>
    lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;

double _transformLat(double x, double y) {
  var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
  ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
  ret += (160.0 * math.sin(y / 12.0 * math.pi) + 320 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
  return ret;
}

double _transformLng(double x, double y) {
  var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
  ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
  ret += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) * 2.0 / 3.0;
  ret += (150.0 * math.sin(x / 12.0 * math.pi) + 300.0 * math.sin(x / 30.0 * math.pi)) * 2.0 / 3.0;
  return ret;
}

/// 手机 GPS 原始经纬度 → 地图经纬度。画地图、上报服务端都用它的结果。
LatLng gpsToMap(double lat, double lng) {
  if (_outOfChina(lat, lng)) return LatLng(lat, lng);
  var dLat = _transformLat(lng - 105.0, lat - 35.0);
  var dLng = _transformLng(lng - 105.0, lat - 35.0);
  final radLat = lat / 180.0 * math.pi;
  var magic = math.sin(radLat);
  magic = 1 - _ee * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * math.pi);
  dLng = (dLng * 180.0) / (_a / sqrtMagic * math.cos(radLat) * math.pi);
  return LatLng(lat + dLat, lng + dLng);
}

/// 地图经纬度 → 手机 GPS 原始经纬度。
///
/// 平时用不到：只在把地图上取的点贴到别的地图工具里核对时才用。
LatLng mapToGps(double lat, double lng) {
  if (_outOfChina(lat, lng)) return LatLng(lat, lng);
  final g = gpsToMap(lat, lng);
  return LatLng(lat * 2 - g.latitude, lng * 2 - g.longitude);
}
