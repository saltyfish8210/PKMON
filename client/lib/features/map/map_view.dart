import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo/campus_points.dart';
import '../../core/tokens.dart';
import 'tile_source.dart';

/// 真实校园地图组件。
///
/// 给其他页面用的公开能力只有三类：
///   * 显示：中心点、缩放级别、要画的标记、轨迹；
///   * 交互：点一下地图，回调告诉你点到的经纬度（已经是地图经纬度，不要再换算）；
///   * 控制：`MapViewController` 提供 moveTo / 回到校园中心。
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    this.controller,
    this.initialCenter,
    this.initialZoom = 16.5,
    this.markers = const <Marker>[],
    this.trackPoints = const <LatLng>[],
    this.myLocation,
    this.style = TileStyle.vector,
    this.onTap,
    this.showCampusPoints = true,
  });

  final MapViewController? controller;

  /// 初始中心，默认北大校园中心。
  final LatLng? initialCenter;
  final double initialZoom;

  /// 额外标记（精灵、我的位置等由调用方传入）。
  final List<Marker> markers;
  final List<LatLng> trackPoints;
  final LatLng? myLocation;
  final TileStyle style;

  /// 点地图回调：参数是地图经纬度。
  final void Function(LatLng point)? onTap;

  /// 是否画出内置的校园地点标记（图书馆、未名湖、宿舍区、东门、博雅塔）。
  final bool showCampusPoints;

  @override
  State<MapView> createState() => MapViewState();
}

/// 外部控制器：让页面能"回到校园中心"或"飞到某个地点"。
class MapViewController {
  MapViewState? _state;

  void _attach(MapViewState state) => _state = state;
  void _detach(MapViewState state) {
    if (identical(_state, state)) _state = null;
  }

  /// 移动到某个经纬度。
  void moveTo(LatLng point, {double zoom = 17}) => _state?.moveTo(point, zoom);

  /// 回到校园中心。
  void resetToCampus() => _state?.moveTo(campusCenter, 16.5);
}

/// 校园中心（地图经纬度）。
const LatLng campusCenter = LatLng(39.9955, 116.3100);

class MapViewState extends State<MapView> {
  final MapController _map = MapController();

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  void moveTo(LatLng point, double zoom) {
    _map.move(point, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialCenter ?? campusCenter;
    final campusMarkers = widget.showCampusPoints
        ? campusPoints
            .map(
              (p) => Marker(
                point: p.position,
                width: 120,
                height: 46,
                child: _CampusLabel(name: p.name),
              ),
            )
            .toList()
        : const <Marker>[];

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: widget.initialZoom,
        minZoom: 14,
        maxZoom: 19,
        onTap: (tapPosition, point) => widget.onTap?.call(point),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: tileUrlFor(widget.style),
          subdomains: subdomainsFor(widget.style),
          userAgentPackageName: 'edu.pkmon.app',
          tileProvider: NetworkTileProvider(),
        ),
        if (widget.trackPoints.length > 1)
          PolylineLayer(
            polylines: <Polyline>[
              Polyline(
                points: widget.trackPoints,
                strokeWidth: 4,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
            ],
          ),
        MarkerLayer(markers: campusMarkers),
        if (widget.markers.isNotEmpty) MarkerLayer(markers: widget.markers),
        if (widget.myLocation != null)
          MarkerLayer(
            markers: <Marker>[
              Marker(
                point: widget.myLocation!,
                width: 40,
                height: 40,
                child: const _MyLocationDot(),
              ),
            ],
          ),
        RichAttributionWidget(
          attributions: <SourceAttribution>[
            TextSourceAttribution(attributionFor(widget.style)),
          ],
        ),
      ],
    );
  }
}

class _CampusLabel extends StatelessWidget {
  const _CampusLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF2C7A6B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              fontSize: 12,
              height: 1.1,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(width: 2, height: 6, color: const Color(0xFF2C7A6B)),
      ],
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      ),
    );
  }
}
