import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';

class ExpandableLocationPillV2 extends ConsumerWidget {
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  const ExpandableLocationPillV2({
    super.key,
    required this.expanded,
    required this.onExpandedChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPoint = ref.watch(selectedPointProvider);
    final selectedCtx = ref.watch(selectedContextProvider);
    final liveCtx = ref.watch(locationContextProvider);
    final location = selectedPoint != null ? (selectedCtx ?? liveCtx) : liveCtx;
    final region = location.regionName ?? '—';
    final district = location.districtName ?? '—';
    final mandal = location.mandalName ?? '—';
    final villageName = location.villageName?.trim();
    final pillText = (villageName != null && villageName.isNotEmpty)
        ? villageName
        : 'Village';

    TextSpan piece(String k, String v) => TextSpan(children: [
          TextSpan(
            text: '$k: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: v,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w800,
            ),
          ),
        ]);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => onExpandedChanged(!expanded),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.46,
                            ),
                            child: Text(
                              pillText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: !expanded
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.85,
                          ),
                          child: GestureDetector(
                            onTap: () {}, // prevent outside-tap dismiss
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.30),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.2,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  children: [
                                    piece('Mdl', mandal),
                                    TextSpan(
                                      text: '  |  ',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.35)),
                                    ),
                                    piece('Dst', district),
                                    TextSpan(
                                      text: '  |  ',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.35)),
                                    ),
                                    piece('Regn', region),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
