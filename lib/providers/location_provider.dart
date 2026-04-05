import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_context.dart';
import '../services/boundary_service.dart';
import '../services/gps_service.dart';

// ── Boundary Service ──────────────────────────────────────────────────────────

final boundaryServiceProvider = FutureProvider<BoundaryService>((ref) async {
  final service = BoundaryService();
  await service.load();
  return service;
});

// ── GPS Stream ────────────────────────────────────────────────────────────────

final gpsStreamProvider = StreamProvider<LatLng>((ref) async* {
  final granted = await GpsService.requestPermission();
  if (!granted) return;
  yield* GpsService.stream();
});

// ── Location Context ──────────────────────────────────────────────────────────

final locationContextProvider =
    NotifierProvider<LocationContextNotifier, LocationContext>(
  LocationContextNotifier.new,
);

class LocationContextNotifier extends Notifier<LocationContext> {
  @override
  LocationContext build() {
    ref.listen<AsyncValue<LatLng>>(gpsStreamProvider, (_, next) {
      next.whenData((point) {
        // Update position + breadcrumb
        ref.read(userPositionProvider.notifier).state = point;
        ref.read(breadcrumbProvider.notifier).addPoint(point);
        // Update boundary context
        ref.read(boundaryServiceProvider).whenData((service) {
          state = service.getLocationContext(point);
        });
      });
    });
    return LocationContext.unknown;
  }
}

// ── Breadcrumb ────────────────────────────────────────────────────────────────

const int kMaxBreadcrumbPoints = 360; // 30 min @ 5 sec intervals

final breadcrumbProvider =
    NotifierProvider<BreadcrumbNotifier, List<LatLng>>(
  BreadcrumbNotifier.new,
);

class BreadcrumbNotifier extends Notifier<List<LatLng>> {
  @override
  List<LatLng> build() => [];

  void addPoint(LatLng point) {
    final updated = [...state, point];
    state = updated.length > kMaxBreadcrumbPoints
        ? updated.sublist(updated.length - kMaxBreadcrumbPoints)
        : updated;
  }

  void clear() => state = [];
}

// ── Compass ───────────────────────────────────────────────────────────────────

final compassProvider = StreamProvider<double>((ref) {
  return (FlutterCompass.events ?? const Stream.empty())
      .map((e) => e.heading ?? 0.0);
});

// ── User State ────────────────────────────────────────────────────────────────

class _NullableLatLngNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;
}

class _DoubleNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
}

final userPositionProvider =
    NotifierProvider<_NullableLatLngNotifier, LatLng?>(
  _NullableLatLngNotifier.new,
);

final userHeadingProvider =
    NotifierProvider<_DoubleNotifier, double>(
  _DoubleNotifier.new,
);

// ── Map Selection (tap-to-inspect) ────────────────────────────────────────────

class _NullableLocationContextNotifier extends Notifier<LocationContext?> {
  @override
  LocationContext? build() => null;
}

final selectedPointProvider =
    NotifierProvider<_NullableLatLngNotifier, LatLng?>(
  _NullableLatLngNotifier.new,
);

final selectedContextProvider =
    NotifierProvider<_NullableLocationContextNotifier, LocationContext?>(
  _NullableLocationContextNotifier.new,
);
