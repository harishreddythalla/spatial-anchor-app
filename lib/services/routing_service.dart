import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SearchResult {
  final String displayName;
  final String shortName;
  final LatLng location;

  SearchResult({
    required this.displayName,
    required this.shortName,
    required this.location,
  });
}

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;

  RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class RoutingService {
  static Future<List<SearchResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Try multiple query strategies in parallel
    final futures = await Future.wait([
      // Prefer scoped queries for better relevance, but keep this multi-state.
      _nominatim('$q, Telangana, India'),
      _nominatim('$q mandal, Telangana'),
      _nominatim('$q, Karnataka, India'),
      _nominatim('$q taluk, Karnataka'),
      _nominatim(q),
      // Nominatim is great for "search", but can be weak for prefix/autocomplete.
      // Photon tends to return better suggestions for partial inputs.
      _photon(q),
    ]);

    // Merge and deduplicate by name (to avoid 5x "Mylaram" from different APIs/coords)
    final seen = <String>{};
    final merged = <SearchResult>[];
    for (final results in futures) {
      for (final r in results) {
        // Use shortName as the primary dedup key since coordinates can vary 
        // slightly between nominatim and photon for the same village.
        final key = r.shortName.toLowerCase().trim();
        if (!seen.contains(key)) {
          seen.add(key);
          merged.add(r);
        }
      }
    }

    // Relevance filter: providers can return nearby administrative areas that
    // don't actually match the user's typed text.
    final qLower = q.toLowerCase();
    final tokens = qLower
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    bool matches(SearchResult r) {
      final s = '${r.shortName} ${r.displayName}'.toLowerCase();
      // Require all tokens to appear somewhere.
      for (final t in tokens) {
        if (!s.contains(t)) return false;
      }
      return true;
    }

    final filtered = merged.where(matches).toList();

    // Sort: prefix matches first, then shorter names.
    int score(SearchResult r) {
      final s1 = r.shortName.toLowerCase();
      final s2 = r.displayName.toLowerCase();
      if (s1.startsWith(qLower) || s2.startsWith(qLower)) return 0;
      if (s1.contains(qLower) || s2.contains(qLower)) return 1;
      return 2;
    }

    filtered.sort((a, b) {
      final sa = score(a), sb = score(b);
      if (sa != sb) return sa - sb;
      final la = a.shortName.length + a.displayName.length;
      final lb = b.shortName.length + b.displayName.length;
      return la - lb;
    });

    return filtered;
  }

  static Future<List<SearchResult>> _nominatim(String q) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}'
        '&format=json&limit=5&countrycodes=in&addressdetails=1',
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'SpatialAnchorMap/1.0',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final data = json.decode(resp.body) as List<dynamic>;
      return _parseResults(data);
    } catch (_) {
      return [];
    }
  }

  static Future<List<SearchResult>> _photon(String q) async {
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/api/'
        '?q=${Uri.encodeComponent(q)}'
        '&limit=5&lang=en',
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'SpatialAnchorMap/1.0',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final features = (data['features'] as List<dynamic>? ?? const []);
      return features.map((f) {
        final feature = f as Map<String, dynamic>;
        final props = (feature['properties'] as Map<String, dynamic>? ?? {});
        final geom = (feature['geometry'] as Map<String, dynamic>? ?? {});
        final coords = (geom['coordinates'] as List<dynamic>? ?? const []);
        if (coords.length < 2) {
          return null;
        }

        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();

        final name = (props['name'] as String?)?.trim();
        final city = (props['city'] as String?)?.trim();
        final state = (props['state'] as String?)?.trim();
        final country = (props['country'] as String?)?.trim();

        final displayParts = <String>[
          if (name != null && name.isNotEmpty) name,
          if (city != null && city.isNotEmpty) city,
          if (state != null && state.isNotEmpty) state,
          if (country != null && country.isNotEmpty) country,
        ];

        final display = displayParts.isNotEmpty ? displayParts.join(', ') : q;
        final short = [
          if (name != null && name.isNotEmpty) name,
          if (city != null && city.isNotEmpty) city,
        ].join(', ');

        return SearchResult(
          displayName: display,
          shortName: short.isNotEmpty ? short : display,
          location: LatLng(lat, lon),
        );
      }).whereType<SearchResult>().toList();
    } catch (_) {
      return [];
    }
  }

  static List<SearchResult> _parseResults(List<dynamic> data) {
    return data.map((item) {
      final name = item['display_name'] as String;
      final address = item['address'] as Map<String, dynamic>? ?? {};
      final parts = <String>[];
      for (final key in [
        'village',
        'town',
        'city',
        'suburb',
        'municipality',
        'county',
        'state_district',
        'state'
      ]) {
        final v = address[key];
        if (v != null && parts.length < 2) parts.add(v as String);
      }
      final short = parts.isNotEmpty
          ? parts.join(', ')
          : name.split(',').take(2).join(',').trim();
      return SearchResult(
        displayName: name,
        shortName: short,
        location: LatLng(
          double.parse(item['lat'] as String),
          double.parse(item['lon'] as String),
        ),
      );
    }).toList();
  }

  static Future<RouteResult?> getRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'SpatialAnchorMap/1.0',
      }).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;
      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      final points = coords.map((c) {
        final pair = c as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();
      return RouteResult(
        points: points,
        distanceKm: (route['distance'] as num).toDouble() / 1000,
        durationMinutes: ((route['duration'] as num).toDouble() / 60).round(),
      );
    } catch (_) {
      return null;
    }
  }
}
