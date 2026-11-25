# 地图组件交接（闫昕 → 余星晨、冉昕霖）

**交付日期**：2026-11-26
**代码位置**：分支 `stage3`，提交 `b10d7f5` 之后
**分支拉取**：`git fetch origin && git checkout stage3 && git pull`

## 一、给你什么

| 文件 | 作用 |
|---|---|
| `client/lib/features/map/tile_source.dart` | 瓦片地址（矢量/卫星/OSM 三选一），已实测可访问，不需要 key |
| `client/lib/features/map/map_view.dart` | 地图组件本体 + `MapViewController` |
| `client/lib/core/geo/campus_points.dart` | 5 个校园地点（地图经纬度） |
| `client/lib/core/geo/coordinate_converter.dart` | `gpsToMap()` / `mapToGps()` |
| `client/lib/features/map/map_demo_page.dart` | 开发演示页，路由 `/#/map-demo`，可直接看效果 |

## 二、怎么用（三行）

```dart
final controller = MapViewController();
MapView(controller: controller, onTap: (LatLng p) => print(p));   // 铺满容器即可
controller.moveTo(LatLng(39.991863, 116.309880), 17);              // 飞到图书馆
```

组件参数：`initialCenter`、`initialZoom`、`markers`、`trackPoints`、`myLocation`、`style`、`onTap`、`showCampusPoints`。
控制器方法：`moveTo(point, zoom)`、`resetToCampus()`。

## 三、给余星晨（地图容器与点选）

- 把 `MapView` 放进你的满幅容器即可，控件（缩放/回中心/图层切换）套在外层 `Stack`。
- 点选：直接用 `onTap` 给的 `LatLng`，**它已经是地图经纬度，不要再换算**。
- 图层切换：改 `style` 参数（`TileStyle.vector` / `satellite`），不要自己拼 URL。

## 四、给冉昕霖（定位订阅）

- `MapView.myLocation` 传一个 `LatLng` 就会画出"我在这里"的点。
- 手机 GPS 数据进地图前必须 `gpsToMap(lat, lng)`；模拟数据（电脑点选）直接传，不要再换。
- 上报服务端时 `coordinateSystem` 填 `GCJ02`，`source` 填 `GPS` 或 `SIMULATED`。

## 五、验收（你拿到后自己验一遍）

1. 拉 `stage3`，`flutter pub get`，`flutter build web --release --no-web-resources-cdn --no-pub`。
2. 浏览器打开 `/#/map-demo`：能看到北大校园底图与「未名湖」「博雅塔」名牌。
3. 点地图任意位置：底部显示坐标，并算出离最近校园地点的距离。
4. 右上角切换卫星图、点"回到校园中心"都正常。

## 六、已知限制

- **理科楼群坐标未取到**：`campus_points.dart` 里第五个点用「博雅塔」代理，注释已标明。取到真坐标后替换即可。
- 校园名牌在缩小到 zoom 15 以下时可能重叠，属显示问题，不影响坐标正确性。
