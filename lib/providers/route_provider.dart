import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/routing_service.dart';
import 'location_provider.dart';

// Keeps `MapScreen` aware of the bottom routing drawer state so it can keep the
// user location marker visible above the drawer.

class _BoolNotifier extends Notifier<bool> {
  final bool _initial;
  _BoolNotifier(this._initial);

  @override
  bool build() => _initial;
}

final routingPanelExpandedProvider =
    NotifierProvider<_BoolNotifier, bool>(() => _BoolNotifier(false));

// true = highlight villages (default), false = highlight mandals
final highlightVillagesProvider =
    NotifierProvider<_BoolNotifier, bool>(() => _BoolNotifier(true));

class RouteState {
  final RouteResult? result;
  final SearchResult? from;
  final SearchResult? to;
  final List<String> crossedMandals;
  final Set<String> highlightedMandals;
  final Set<String>? highlightedVillages;
  final List<LatLng>? highlightSampledPoints;

  const RouteState({
    this.result,
    this.from,
    this.to,
    this.crossedMandals = const <String>[],
    this.highlightedMandals = const <String>{},
    this.highlightedVillages = const <String>{},
    this.highlightSampledPoints = const <LatLng>[],
  });
}

class RouteNotifier extends Notifier<RouteState> {
  @override
  RouteState build() => const RouteState();

  static const _dist = Distance();

  String _villageKey(String village, String? mandal, String? district) {
    final v = village.trim().toLowerCase();
    final m = (mandal ?? '').trim().toLowerCase();
    final d = (district ?? '').trim().toLowerCase();
    return '$v|$m|$d';
  }

  List<LatLng> _sampleRouteByDistance(
    List<LatLng> points, {
    double stepMeters = 250,
  }) {
    if (points.isEmpty) return const [];
    if (points.length == 1) return [points.first];

    final sampled = <LatLng>[points.first];
    double acc = 0;
    for (int i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final segM = _dist.as(LengthUnit.Meter, a, b);
      acc += segM;
      if (acc >= stepMeters) {
        sampled.add(b);
        acc = 0;
      }
    }
    if (sampled.last != points.last) sampled.add(points.last);
    return sampled;
  }

  Future<void> setRoute(
    RouteResult result,
    SearchResult from,
    SearchResult to,
  ) async {
    final points = result.points;
    final sampled = _sampleRouteByDistance(points, stepMeters: 250);

    final crossedMandals = <String>[];
    final highlightedMandals = <String>{};
    final highlightedVillages = <String>{};

    final serviceAsync = ref.read(boundaryServiceProvider);
    serviceAsync.whenData((service) {
      for (final point in sampled) {
        final ctx = service.getLocationContext(point);
        if (ctx.villageName != null) {
          final key = _villageKey(
              ctx.villageName!, ctx.mandalName, ctx.districtName);
          highlightedVillages.add(key);
        }
        if (ctx.mandalName != null &&
            !highlightedMandals.contains(ctx.mandalName)) {
          highlightedMandals.add(ctx.mandalName!);
          crossedMandals.add(ctx.mandalName!);
        }
      }
    });

    state = RouteState(
      result: result,
      from: from,
      to: to,
      crossedMandals: crossedMandals,
      highlightedMandals: highlightedMandals,
      highlightedVillages: highlightedVillages,
      highlightSampledPoints: sampled,
    );
  }

  void clearRoute() => state = const RouteState();
}

final routeProvider = NotifierProvider<RouteNotifier, RouteState>(
  RouteNotifier.new,
);
