import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/location_provider.dart';
import '../models/location_context.dart';

class ContextBanner extends ConsumerWidget {
  const ContextBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(boundaryServiceProvider);
    final gpsAsync = ref.watch(gpsStreamProvider);
    final selectedPoint = ref.watch(selectedPointProvider);
    final selectedCtx = ref.watch(selectedContextProvider);
    final liveCtx = ref.watch(locationContextProvider);
    final locationCtx = selectedPoint != null ? (selectedCtx ?? liveCtx) : liveCtx;

    return Positioned(
      // Leave space for the top-left menu icon.
      top: MediaQuery.of(context).padding.top + 62,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _borderColor(serviceAsync, gpsAsync),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: _buildContent(
          context,
          ref,
          serviceAsync,
          gpsAsync,
          locationCtx,
          selectedPoint != null,
        ),
      ),
    );
  }

  Color _borderColor(AsyncValue serviceAsync, AsyncValue gpsAsync) {
    if (serviceAsync is AsyncLoading) return Colors.orange;
    if (gpsAsync is AsyncLoading) return Colors.orange.withOpacity(0.5);
    if (gpsAsync is AsyncError) return Colors.redAccent;
    return Colors.blueAccent;
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue serviceAsync,
    AsyncValue gpsAsync,
    dynamic locationCtx,
    bool isSelected,
  ) {
    // Boundaries still loading
    if (serviceAsync is AsyncLoading) return _shimmer();

    // Boundary load failed
    if (serviceAsync is AsyncError) {
      return _iconRow(
          Icons.error_outline, Colors.redAccent, 'Failed to load boundaries');
    }

    // Waiting for first GPS fix
    if (gpsAsync is AsyncLoading) {
      return _iconRow(
          Icons.gps_not_fixed, Colors.orange, 'Waiting for GPS fix…');
    }

    // GPS permission denied or error
    if (gpsAsync is AsyncError) {
      return _iconRow(
          Icons.location_off, Colors.redAccent, 'Location access denied');
    }

    // All good — show context
    final ctx = locationCtx as LocationContext;
    final isKnown = ctx.isKnown;
    final parts = ctx.labeledParts;

    String? pick(String label) {
      for (final p in parts) {
        if (p.$1 == label) return p.$2;
      }
      return null;
    }

    // Two-line compact layout. Always show all labels; use '—' when missing.
    final region = pick('Region') ?? '—';
    final district = pick('District') ?? '—';
    final mandal = pick('Mandal') ?? '—';
    final village = pick('Village') ?? '—';

    Widget kv(String k, String v) => RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.25,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(
                text: '$k: ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: v),
            ],
          ),
        );

    return Row(
      children: [
        Icon(
          isSelected ? Icons.place : (isKnown ? Icons.location_on : Icons.location_searching),
          color: isSelected ? Colors.cyanAccent : (isKnown ? Colors.blueAccent : Colors.grey),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: !isKnown
              ? Text(
                  ctx.displayString,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: kv('Region', region)),
                        const SizedBox(width: 10),
                        Expanded(child: kv('District', district)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(child: kv('Mandal', mandal)),
                        const SizedBox(width: 10),
                        Expanded(child: kv('Village', village)),
                      ],
                    ),
                  ],
                ),
        ),
        if (isSelected)
          GestureDetector(
            onTap: () {
              ref.read(selectedPointProvider.notifier).state = null;
              ref.read(selectedContextProvider.notifier).state = null;
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(Icons.close, color: Colors.white70, size: 18),
            ),
          ),
      ],
    );
  }

  Widget _shimmer() => Shimmer.fromColors(
        baseColor: Colors.grey.shade800,
        highlightColor: Colors.grey.shade500,
        child: Container(
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

  Widget _iconRow(IconData icon, Color color, String text) => Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      );
}
