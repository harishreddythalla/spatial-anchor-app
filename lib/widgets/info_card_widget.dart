import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_context.dart';
import '../providers/location_provider.dart';

class InfoCardWidget extends ConsumerWidget {
  const InfoCardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPoint = ref.watch(selectedPointProvider);
    final selectedCtx = ref.watch(selectedContextProvider);
    final liveCtx = ref.watch(locationContextProvider);
    final ctx =
        selectedPoint != null ? (selectedCtx ?? liveCtx) : (liveCtx as dynamic);

    if (ctx is! LocationContext) return const SizedBox.shrink();

    final region = ctx.regionName ?? '—';
    final district = ctx.districtName ?? '—';
    final village = ctx.villageName ?? '—';

    TextSpan row(String k, String v) => TextSpan(children: [
          TextSpan(
            text: '$k: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: v,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ]);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                children: [row('Region', region)],
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                children: [row('District', district)],
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                children: [row('Village', village)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

