import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_context.dart';
import 'state_download_service.dart';

class _BBox {
  final double minLat, maxLat, minLng, maxLng;
  const _BBox(this.minLat, this.maxLat, this.minLng, this.maxLng);
  bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  double centerLat() => (minLat + maxLat) / 2;
  double centerLng() => (minLng + maxLng) / 2;
}

class _BoundaryFeature {
  final String? regionName;
  final String? villageName;
  final String? mandalName;
  final String? districtName;
  final _BBox bbox;
  final List<List<LatLng>> rings;

  const _BoundaryFeature({
    this.regionName,
    this.villageName,
    this.mandalName,
    this.districtName,
    required this.bbox,
    required this.rings,
  });
}

class BoundaryService {
  List<_BoundaryFeature> _features = [];
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> load({
    String assetPath = 'assets/data/fallback_detection.geojson',
  }) async {
    if (_isLoaded) return;

    String raw;

    // Try to load from downloaded state files first
    try {
      final downloadService = StateDownloadService.instance;
      if (downloadService.hasAnyDownloaded) {
        raw = await downloadService.loadDownloadedBoundaries();
      } else {
        raw = await rootBundle.loadString(assetPath);
      }
    } catch (_) {
      raw = await rootBundle.loadString(assetPath);
    }

    final data = json.decode(raw) as Map<String, dynamic>;
    final featureList = data['features'] as List<dynamic>;
    _features = featureList
        .map((f) => _parseFeature(f as Map<String, dynamic>))
        .whereType<_BoundaryFeature>()
        .toList();
    _isLoaded = true;
  }

  LocationContext getLocationContext(LatLng point) {
    assert(_isLoaded, 'Call load() before getLocationContext()');
    final lat = point.latitude;
    final lng = point.longitude;

    LocationContext? foundVillage;
    LocationContext? bestMandal;
    LocationContext? bestDistrict;

    // Pass 1: exact ray-cast
    for (final feature in _features) {
      if (!feature.bbox.contains(lat, lng)) continue;
      for (final ring in feature.rings) {
        if (_rayCast(lat, lng, ring)) {
          final ctx = LocationContext(
            regionName: feature.regionName,
            villageName: feature.villageName,
            mandalName: feature.mandalName,
            districtName: feature.districtName,
          );
          if (feature.villageName != null) foundVillage ??= ctx;
          if (feature.mandalName != null) bestMandal ??= ctx;
          if (feature.districtName != null) bestDistrict ??= ctx;
          break;
        }
      }
    }

    if (foundVillage != null) {
      return LocationContext(
        regionName: bestDistrict?.regionName ??
            bestMandal?.regionName ??
            foundVillage.regionName,
        villageName: foundVillage.villageName,
        mandalName: bestMandal?.mandalName ?? foundVillage.mandalName,
        districtName: bestDistrict?.districtName ?? foundVillage.districtName,
      );
    }

    if (bestMandal != null) return bestMandal;
    if (bestDistrict != null) return bestDistrict;

    // Pass 2: nearest-centroid fallback
    _BoundaryFeature? nearestMandal;
    _BoundaryFeature? nearestDistrict;
    double nearestMandalDist = double.infinity;
    double nearestDistrictDist = double.infinity;

    for (final feature in _features) {
      final clat = feature.bbox.centerLat();
      final clng = feature.bbox.centerLng();
      final dist = sqrt(pow(clat - lat, 2) + pow(clng - lng, 2));

      if (feature.mandalName != null && dist < nearestMandalDist) {
        nearestMandalDist = dist;
        nearestMandal = feature;
      }
      if (feature.districtName != null && dist < nearestDistrictDist) {
        nearestDistrictDist = dist;
        nearestDistrict = feature;
      }
    }

    if (nearestMandal != null && nearestMandalDist < 0.2) {
      return LocationContext(
        regionName: nearestMandal.regionName,
        mandalName: nearestMandal.mandalName,
        districtName: nearestDistrict?.districtName,
      );
    }

    return LocationContext.unknown;
  }

  bool _rayCast(double lat, double lng, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      if (((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  _BoundaryFeature? _parseFeature(Map<String, dynamic> feature) {
    try {
      final props = feature['properties'] as Map<String, dynamic>?;
      final geom = feature['geometry'] as Map<String, dynamic>?;
      if (props == null || geom == null) return null;

      final type = geom['type'] as String;
      final coords = geom['coordinates'] as List<dynamic>;
      final List<List<LatLng>> allRings = [];

      if (type == 'Polygon') {
        if (coords.isNotEmpty) {
          final ring = _parseRing(coords[0] as List<dynamic>);
          if (ring.length >= 3) allRings.add(ring);
        }
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          final rings = poly as List<dynamic>;
          if (rings.isNotEmpty) {
            final ring = _parseRing(rings[0] as List<dynamic>);
            if (ring.length >= 3) allRings.add(ring);
          }
        }
      } else {
        return null;
      }

      if (allRings.isEmpty) return null;

      double minLat = double.infinity,
          maxLat = double.negativeInfinity,
          minLng = double.infinity,
          maxLng = double.negativeInfinity;

      for (final ring in allRings) {
        for (final p in ring) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }
      }

      return _BoundaryFeature(
        regionName: _str(props, ['state', 'STATE', 'State', 'NAME_1']),
        villageName: _str(props, ['village', 'VILLAGE', 'Village', 'NAME_4']),
        mandalName: _str(
            props, ['mandal', 'MANDAL', 'Mandal', 'taluk', 'TALUK', 'NAME_3']),
        districtName:
            _str(props, ['district', 'DISTRICT', 'District', 'NAME_2']),
        bbox: _BBox(minLat, maxLat, minLng, maxLng),
        rings: allRings,
      );
    } catch (e) {
      return null;
    }
  }

  List<LatLng> _parseRing(List<dynamic> ring) {
    return ring.map((c) {
      final coord = c as List<dynamic>;
      return LatLng(
        (coord[1] as num).toDouble(),
        (coord[0] as num).toDouble(),
      );
    }).toList();
  }

  String? _str(Map<String, dynamic> props, List<String> keys) {
    for (final k in keys) {
      final v = props[k];
      if (v != null &&
          v.toString().trim().isNotEmpty &&
          v.toString() != 'null') {
        var val = v.toString().trim();
        // Skip unnamed OSM boundaries like "n.a.(2050)" or "N.A.(1897)"
        if (RegExp(r'^[Nn]\.?[Aa]\.?\s*\(\d+\)$').hasMatch(val)) return null;
        
        // Strip out prefixed 'Ward 3', 'Ward No 4' from village strings
        val = val.replaceFirst(RegExp(r'^[Ww]ard\s+(?:No\.?\s*)?\d+\s+', caseSensitive: false), '').trim();
        
        return val;
      }
    }
    return null;
  }
}
