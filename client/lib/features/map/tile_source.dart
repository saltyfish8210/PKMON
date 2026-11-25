/// 地图瓦片地址。
///
/// 坐标系说明：高德用的是「地图经纬度」（GCJ-02），全国地图服务统一这套；
/// 手机 GPS 给的是「GPS 原始经纬度」（WGS-84），两者差约 500 米，
/// 手机数据必须先用 `gpsToMap()` 换算再画到这张地图上。
///
/// 实测（2026-11-25）：三个地址均可直接访问，无需 key。
library;

enum TileStyle { vector, satellite, osm }

const String _vectorUrl =
    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';
const String _satelliteUrl =
    'https://webst0{s}.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}';
const String _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// 返回瓦片地址模板。
String tileUrlFor(TileStyle style) {
  switch (style) {
    case TileStyle.satellite:
      return _satelliteUrl;
    case TileStyle.osm:
      return _osmUrl;
    case TileStyle.vector:
      return _vectorUrl;
  }
}

/// 子域列表：高德用 1-4 分摊请求。
List<String> subdomainsFor(TileStyle style) {
  switch (style) {
    case TileStyle.osm:
      return const <String>[];
    case TileStyle.satellite:
    case TileStyle.vector:
      return const <String>['1', '2', '3', '4'];
  }
}

/// 矢量图显示中文地名；卫星图不显示。
String attributionFor(TileStyle style) {
  switch (style) {
    case TileStyle.osm:
      return '© OpenStreetMap contributors';
    case TileStyle.satellite:
    case TileStyle.vector:
      return '© 高德地图';
  }
}
