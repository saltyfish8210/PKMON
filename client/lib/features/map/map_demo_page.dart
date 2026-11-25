import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo/campus_points.dart';
import '../../core/tokens.dart';
import 'map_view.dart';
import 'tile_source.dart';

/// 真实地图开发演示页：验证底图、校园标记、点选坐标。
///
/// 用途：第一周先把"真实底图出图 + 点地图拿坐标"跑通，供后续页面复用。
class MapDemoPage extends StatefulWidget {
  const MapDemoPage({super.key});

  @override
  State<MapDemoPage> createState() => _MapDemoPageState();
}

class _MapDemoPageState extends State<MapDemoPage> {
  final MapViewController _controller = MapViewController();
  LatLng? _picked;
  TileStyle _style = TileStyle.vector;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('真实地图（开发演示）'),
        actions: <Widget>[
          IconButton(
            tooltip: _style == TileStyle.vector ? '切换卫星图' : '切换矢量图',
            icon: Icon(_style == TileStyle.vector ? Icons.satellite_alt_outlined : Icons.map_outlined),
            onPressed: () => setState(() {
              _style = _style == TileStyle.vector ? TileStyle.satellite : TileStyle.vector;
            }),
          ),
          IconButton(
            tooltip: '回到校园中心',
            icon: const Icon(Icons.my_location),
            onPressed: () => _controller.resetToCampus(),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: MapView(
              controller: _controller,
              myLocation: _picked,
              style: _style,
              onTap: (point) => setState(() => _picked = point),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _picked == null ? '点一下地图，试试能不能拿到坐标' : '你点的位置：${_picked!.latitude.toStringAsFixed(6)}, ${_picked!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _picked == null
                          ? '地图经纬度（GCJ-02），点哪里就显示哪里；手机 GPS 需要先 gpsToMap() 换算。'
                          : _nearestHint(_picked!),
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _nearestHint(LatLng p) {
    CampusPoint? best;
    var bestMeters = double.infinity;
    for (final c in campusPoints) {
      final d = _distanceMeters(p, c.position);
      if (d < bestMeters) {
        bestMeters = d;
        best = c;
      }
    }
    if (best == null) return '校园地点数据未加载';
    return '离「${best.name}」约 ${bestMeters.toStringAsFixed(0)} 米（判定半径 ${best.radius.toStringAsFixed(0)} 米）';
  }

  /// 两点间距离（米），球面近似，校园尺度足够。
  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }
}
