import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/routing_service.dart';
import '../providers/route_provider.dart';

class RoutingPanel extends ConsumerStatefulWidget {
  const RoutingPanel({super.key});
  @override
  ConsumerState<RoutingPanel> createState() => _RoutingPanelState();
}

class _RoutingPanelState extends ConsumerState<RoutingPanel> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  SearchResult? _from;
  SearchResult? _to;
  List<SearchResult> _fromResults = [];
  List<SearchResult> _toResults = [];
  bool _loadingFrom = false;
  bool _loadingTo = false;
  bool _routing = false;
  bool _expanded = false;
  Timer? _fromTimer;
  Timer? _toTimer;

  void _setExpanded(bool v) {
    if (_expanded == v) return;
    setState(() => _expanded = v);
    ref.read(routingPanelExpandedProvider.notifier).state = v;
  }

  void _swapFromTo() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;

      final tmpText = _fromCtrl.text;
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = tmpText;

      _fromResults = [];
      _toResults = [];
      _loadingFrom = false;
      _loadingTo = false;
    });
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromTimer?.cancel();
    _toTimer?.cancel();
    super.dispose();
  }

  void _searchFrom(String q) {
    _fromTimer?.cancel();
    setState(() {
      _from = null;
    });
    if (q.trim().length < 3) {
      setState(() => _fromResults = []);
      return;
    }
    setState(() => _loadingFrom = true);
    _fromTimer = Timer(const Duration(milliseconds: 400), () async {
      final r = await RoutingService.search(q.trim());
      if (mounted)
        setState(() {
          _fromResults = r;
          _loadingFrom = false;
        });
    });
  }

  void _searchTo(String q) {
    _toTimer?.cancel();
    setState(() {
      _to = null;
    });
    if (q.trim().length < 3) {
      setState(() => _toResults = []);
      return;
    }
    setState(() => _loadingTo = true);
    _toTimer = Timer(const Duration(milliseconds: 400), () async {
      final r = await RoutingService.search(q.trim());
      if (mounted)
        setState(() {
          _toResults = r;
          _loadingTo = false;
        });
    });
  }

  Future<void> _getRoute() async {
    if (_from == null || _to == null) return;
    setState(() => _routing = true);
    final result =
        await RoutingService.getRoute(_from!.location, _to!.location);
    setState(() => _routing = false);
    if (result != null && mounted) {
      await ref.read(routeProvider.notifier).setRoute(result, _from!, _to!);
      _setExpanded(false);
    }
  }

  void _clear() {
    ref.read(routeProvider.notifier).clearRoute();
    ref.read(routingPanelExpandedProvider.notifier).state = false;
    setState(() {
      _from = null;
      _to = null;
      _fromCtrl.clear();
      _toCtrl.clear();
      _fromResults = [];
      _toResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(routeProvider);
    final canRoute = _from != null && _to != null && !_routing;
    final bot = MediaQuery.of(context).padding.bottom;

    final padTop = _expanded ? 10.0 : 6.0;
    final padBottom = (_expanded ? 14.0 : 8.0) + bot;
    final handleMarginBottom = _expanded ? 10.0 : 6.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: EdgeInsets.fromLTRB(14, padTop, 14, padBottom),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
                child: Container(
              width: 36,
              height: 4,
              margin: EdgeInsets.only(bottom: handleMarginBottom),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            )),

            // COLLAPSED
            if (!_expanded) ...[
              if (route.result != null)
                _summary(route)
              else
                GestureDetector(
                  onTap: () => _setExpanded(true),
                  child: const Row(children: [
                    Icon(Icons.directions, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Plan Route',
                        style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Spacer(),
                    Icon(Icons.keyboard_arrow_up,
                        color: Colors.white38, size: 20),
                  ]),
                ),
            ],

            // EXPANDED
            if (_expanded) ...[
              Row(children: [
                const Icon(Icons.directions,
                    color: Colors.blueAccent, size: 16),
                const SizedBox(width: 6),
                const Text('Route Planner',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const Spacer(),
                if (route.result != null)
                  GestureDetector(
                    onTap: _clear,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ),
                GestureDetector(
                  onTap: () => _setExpanded(false),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white54, size: 20),
                ),
              ]),
              const SizedBox(height: 10),
              // Highlight mode toggle — shown when a route is active
              if (route.result != null) _highlightToggleRow(),
              const SizedBox(height: 12),

              // FROM field
              _field(
                ctrl: _fromCtrl,
                hint: 'From: Ghatkesar, Hyderabad...',
                icon: Icons.trip_origin,
                color: const Color.fromARGB(255, 37, 139, 90),
                loading: _loadingFrom,
                selected: _from != null,
                onChanged: _searchFrom,
                onClear: () => setState(() {
                  _from = null;
                  _fromCtrl.clear();
                  _fromResults = [];
                }),
              ),

              // FROM results — ALWAYS shown when available
              if (_fromResults.isNotEmpty && _from == null)
                _results(_fromResults, Colors.greenAccent, (r) {
                  setState(() {
                    _from = r;
                    _fromCtrl.text = r.shortName;
                    _fromResults = [];
                  });
                }),

              const SizedBox(height: 8),

              // TO field + reverse icon (right side)
              Row(
                children: [
                  Expanded(
                    child: _field(
                      ctrl: _toCtrl,
                      hint: 'To: Warangal, Karimnagar...',
                      icon: Icons.location_on,
                      color: Colors.redAccent,
                      loading: _loadingTo,
                      selected: _to != null,
                      onChanged: _searchTo,
                      onClear: () => setState(() {
                        _to = null;
                        _toCtrl.clear();
                        _toResults = [];
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _swapFromTo,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.swap_vert,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),

              // TO results — ALWAYS shown when available
              if (_toResults.isNotEmpty && _to == null)
                _results(_toResults, Colors.redAccent, (r) {
                  setState(() {
                    _to = r;
                    _toCtrl.text = r.shortName;
                    _toResults = [];
                  });
                }),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canRoute ? Colors.blueAccent : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: canRoute ? _getRoute : null,
                  icon: _routing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.directions, size: 18),
                  label: Text(
                    _routing
                        ? 'Getting route…'
                        : canRoute
                            ? 'Get Route'
                            : _from == null
                                ? 'Select FROM location'
                                : 'Select TO location',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summary(RouteState route) {
    final highlightVillages = ref.watch(highlightVillagesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          const Icon(Icons.directions, color: Colors.blueAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${route.result!.distanceKm.toStringAsFixed(1)} km  •  '
              '${route.result!.durationMinutes} min',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => _setExpanded(true),
            child: const Icon(Icons.edit, color: Colors.white38, size: 16),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _clear,
            child: const Icon(Icons.close, color: Colors.white38, size: 18),
          ),
        ]),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 26), // Align with text above
            Expanded(
              child: route.crossedMandals.isNotEmpty
                  ? Text(
                      'via ${route.crossedMandals.take(3).join(", ")}'
                      '${route.crossedMandals.length > 3 ? " +${route.crossedMandals.length - 3}" : ""}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const SizedBox.shrink(),
            ),
            _highlightToggle(highlightVillages),
          ],
        ),
      ],
    );
  }

  /// Small pill toggle: Mandals | Villages
  Widget _highlightToggle(bool highlightVillages) => GestureDetector(
        onTap: () => ref
            .read(highlightVillagesProvider.notifier)
            .state = !highlightVillages,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _toggleLabel('Mandals', !highlightVillages),
            const SizedBox(width: 4),
            _toggleLabel('Villages', highlightVillages),
          ]),
        ),
      );

  Widget _toggleLabel(String text, bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );

  Widget _highlightToggleRow() {
    final highlightVillages = ref.watch(highlightVillagesProvider);
    return Row(
      children: [
        const Icon(Icons.layers_outlined, color: Colors.white38, size: 13),
        const SizedBox(width: 6),
        Text('Highlight:',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        const SizedBox(width: 8),
        _highlightToggle(highlightVillages),
      ],
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    required Color color,
    required bool loading,
    required bool selected,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : Colors.white12),
        ),
        child: Row(children: [
          const SizedBox(width: 10),
          Icon(icon,
              color: selected ? color : color.withValues(alpha: 0.7), size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
            controller: ctrl,
            onChanged: onChanged,
            style:
                TextStyle(color: selected ? color : Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )),
          if (loading)
            const Padding(
                padding: EdgeInsets.only(right: 10),
                child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white38)))
          else if (ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.close, color: Colors.white38, size: 16)),
            ),
        ]),
      );

  Widget _results(List<SearchResult> items, Color accent,
          ValueChanged<SearchResult> onTap) =>
      Container(
        margin: const EdgeInsets.only(top: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: items.take(5).toList().asMap().entries.map((e) {
            final r = e.value;
            final last = e.key == items.take(5).length - 1;
            return InkWell(
              onTap: () => onTap(r),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    border: last
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Colors.white10))),
                child: Row(children: [
                  Icon(Icons.place, color: accent, size: 13),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.shortName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                          r.displayName
                              .split(',')
                              .skip(1)
                              .take(2)
                              .join(',')
                              .trim(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  Icon(Icons.north_west,
                      color: accent.withValues(alpha: 0.4), size: 11),
                ]),
              ),
            );
          }).toList(),
        ),
      );
}
