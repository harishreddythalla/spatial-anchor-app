import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart';
import 'package:geobase/geobase.dart' as gb;
import 'providers/location_provider.dart';
import 'providers/route_provider.dart';
import 'services/state_download_service.dart';
import 'services/route_highlight_service.dart';
import 'widgets/routing_panel.dart';
import 'widgets/state_manager_drawer.dart';
import 'widgets/expandable_location_pill.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapController? _mapController;
  StyleController? _styleController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const LatLng _defaultCenter = LatLng(17.3850, 78.4867);
  
  bool _followUser = true;
  double _currentZoom = 10;
  bool _showVillages = true;
  bool _locationPopupExpanded = false;
  
  List<Object> _highlightedFids = [];
  bool _highlightLayerAdded = false;

  void _onMapCreated(MapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded(StyleController style) {
    _styleController = style;
    _updateHighlightLayer();
  }

  void _updateHighlightLayer() {
    if (_styleController == null) return;
    
    if (_highlightLayerAdded) {
      _styleController!.removeLayer('villages-hl');
      _highlightLayerAdded = false;
    }
    
    if (_highlightedFids.isNotEmpty) {
      _styleController!.addLayer(
        FillStyleLayer(
          id: 'villages-hl',
          sourceId: 'admin-boundaries',
          sourceLayerId: 'villages',
          filter: ['in', 'id', ..._highlightedFids],
          paint: const {
            'fill-color': 'rgba(255, 235, 59, 0.6)',
          }
        ),
      );
      _highlightLayerAdded = true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<AsyncValue<LatLng>>(gpsStreamProvider, (_, next) {
        next.whenData((point) {
          if (ref.read(routeProvider).result != null) return;
          if (_followUser && _mapController != null) {
            _mapController!.animateCamera(
              center: gb.Geographic.create(x: point.longitude, y: point.latitude),
              nativeDuration: const Duration(milliseconds: 300)
            );
          }
        });
      });
      
      ref.listenManual<RouteState>(routeProvider, (_, next) {
        final res = next.result;
        if (res == null) {
          setState(() {
            _highlightedFids = [];
            _updateHighlightLayer();
          });
          return;
        }
        if (res.points.isNotEmpty && _mapController != null) {
          _followUser = false;
          _mapController!.fitBounds(
             bounds: LngLatBounds.fromPoints(
                 res.points.map((p) => gb.Geographic.create(x: p.longitude, y: p.latitude)).toList()
             ),
             padding: const EdgeInsets.only(top: 140, bottom: 260, left: 36, right: 36)
          );
          
          RouteHighlightService.getIntersectingFeatureIds(_mapController!, res.points)
              .then((ids) {
            if (mounted && ids.isNotEmpty) {
              setState(() {
                _highlightedFids = ids;
                _updateHighlightLayer();
              });
            }
          });
        }
      });
    });
  }

  Future<String> _loadDynamicStyle() async {
    String styleStr = await rootBundle.loadString('assets/map_style.json');
    final stateService = StateDownloadService.instance;
    final downloadedStates = stateService.states.where((s) => s.isDownloaded || s.isTilesDownloaded).toList();
    if (downloadedStates.isNotEmpty) {
      final pmtilesPath = await stateService.tilesPathIfExists(downloadedStates.first.id);
      if (pmtilesPath != null) {
        styleStr = styleStr.replaceAll('pmtiles://{PMTILES_PATH}', 'pmtiles://$pmtilesPath');
      }
    }
    return styleStr;
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(userPositionProvider);
    final panelExpanded = ref.watch(routingPanelExpandedProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      drawer: const StateManagerDrawer(),
      body: Stack(
        children: [
          FutureBuilder<String>(
            future: _loadDynamicStyle(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              return MapLibreMap(
                options: MapOptions(
                  initStyle: snapshot.data!,
                  initCenter: gb.Geographic.create(x: _defaultCenter.longitude, y: _defaultCenter.latitude),
                  initZoom: 10,
                ),
                onMapCreated: _onMapCreated,
                onStyleLoaded: _onStyleLoaded,
                onEvent: (event) {
                  if (event is MapEventCameraIdle && _mapController != null) {
                    final cam = _mapController!.camera;
                    if (cam != null && (cam.zoom - _currentZoom).abs() > 0.5) {
                      setState(() => _currentZoom = cam.zoom);
                    }
                  } else if (event is MapEventClick) {
                    ref.read(selectedPointProvider.notifier).state = 
                        LatLng(event.point.lat, event.point.lon);
                  }
                },
              );
            }
          ),
          
          if (_locationPopupExpanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _locationPopupExpanded = false),
                child: const SizedBox.expand(),
              ),
            ),
            
          // Top-left hamburger
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 8,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu, color: Colors.white70, size: 20),
              ),
            ),
          ),
          
          // Villages toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 12,
            child: GestureDetector(
              onTap: _currentZoom > 11
                  ? () {
                      setState(() => _showVillages = !_showVillages);
                      // Toggle specific layer visibility if Mapbox supports dynamic expressions
                    }
                  : null,
              child: Opacity(
                opacity: _currentZoom > 11 ? 1 : 0.45,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_showVillages ? const Color(0xFF00695C) : Colors.black).withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.villa_outlined, color: Colors.white70, size: 10),
                      SizedBox(width: 2),
                      Text('Villages', style: TextStyle(color: Colors.white, fontSize: 8)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          ExpandableLocationPillV2(
            expanded: _locationPopupExpanded,
            onExpandedChanged: (v) => setState(() => _locationPopupExpanded = v),
          ),
          const RoutingPanel(),
          
          Positioned(
            bottom: panelExpanded ? 280 : 100,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('z${_currentZoom.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ),
          
          if (!_followUser && position != null)
            Positioned(
              bottom: panelExpanded ? 280 : 100,
              right: 16,
              child: FloatingActionButton.small(
                backgroundColor: Colors.black87,
                onPressed: () {
                  setState(() => _followUser = true);
                  if (_mapController != null) {
                    _mapController!.animateCamera(center: gb.Geographic.create(x: position.longitude, y: position.latitude));
                  }
                },
                child: const Icon(Icons.my_location, color: Colors.blueAccent),
              ),
            ),
        ],
      ),
    );
  }
}
