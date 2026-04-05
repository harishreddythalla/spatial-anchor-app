import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_screen.dart';
import 'screens/state_selector_screen.dart';
import 'services/state_download_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SpatialAnchorApp()));
}

class SpatialAnchorApp extends StatefulWidget {
  const SpatialAnchorApp({super.key});

  @override
  State<SpatialAnchorApp> createState() => _SpatialAnchorAppState();
}

class _SpatialAnchorAppState extends State<SpatialAnchorApp> {
  bool _loading = true;
  bool _showSetup = false;

  @override
  void initState() {
    super.initState();
    // Defer init until after the first frame so the splash screen
    // is guaranteed to render on Android before any blocking work starts.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await StateDownloadService.instance.init();
    final prefs = await SharedPreferences.getInstance();
    final setupComplete = prefs.getBool('setup_complete') ?? false;
    if (mounted) {
      setState(() {
        _showSetup = !setupComplete;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spatial Anchor Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: _loading
          ? const _SplashScreen()
          : _showSetup
              ? StateSelectorScreen(
                  onDone: () => setState(() => _showSetup = false),
                )
              : const MapScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: Colors.white24, size: 48),
            SizedBox(height: 16),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Loading map data…',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
