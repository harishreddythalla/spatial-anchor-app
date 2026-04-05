import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:maplibre/maplibre.dart';
import 'package:geobase/geobase.dart' as gb;
import 'package:latlong2/latlong.dart';

class RouteHighlightService {
  /// Queries the MapLibre controller for rendered features across the bounding box
  /// of the route, returning their IDs to be consumed by a declarative FillStyleLayer filter.
  static Future<List<Object>> getIntersectingFeatureIds(
      MapController mapController, List<LatLng> routePoints, {String layerId = 'villages-fill'}) async {
    if (routePoints.isEmpty) return [];

    try {
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      for (var p in routePoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      
      final sw = mapController.toScreenLocation(gb.Geographic.create(x: minLng, y: minLat));
      final ne = mapController.toScreenLocation(gb.Geographic.create(x: maxLng, y: maxLat));
      
      final rect = Rect.fromLTRB(
        sw.dx < ne.dx ? sw.dx : ne.dx,
        sw.dy < ne.dy ? sw.dy : ne.dy,
        sw.dx > ne.dx ? sw.dx : ne.dx,
        sw.dy > ne.dy ? sw.dy : ne.dy,
      );

      final features = mapController.featuresInRect(
        rect, 
        layerIds: [layerId],
      );

      List<Object> ids = [];
      for (var feature in features) {
        if (feature.id != null) {
          ids.add(feature.id!);
        }
      }
      
      return ids.toSet().toList(); // deduplicate
    } catch (e) {
      debugPrint("Highlight error: $e");
      return [];
    }
  }
}
