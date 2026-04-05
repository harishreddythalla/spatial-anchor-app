import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrl =
    'https://github.com/harishreddythalla/spatial-anchor-data/releases/download/v2.0';

class StateInfo {
  final String id;
  final String name;
  final String filename;
  final double sizeMb;
  final String? tilesFilename;
  final double? tilesSizeMb;
  bool isDownloaded;
  bool isTilesDownloaded;
  bool isDownloading;
  double progress;

  StateInfo({
    required this.id,
    required this.name,
    required this.filename,
    required this.sizeMb,
    this.tilesFilename,
    this.tilesSizeMb,
    this.isDownloaded = false,
    this.isTilesDownloaded = false,
    this.isDownloading = false,
    this.progress = 0,
  });

  factory StateInfo.fromJson(Map<String, dynamic> j) => StateInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        filename: j['filename'] as String,
        sizeMb: (j['size_mb'] as num).toDouble(),
        tilesFilename: (j['tiles_filename'] as String?)?.trim(),
        tilesSizeMb: j['tiles_size_mb'] == null
            ? null
            : (j['tiles_size_mb'] as num).toDouble(),
      );
}

class StateDownloadService {
  static StateDownloadService? _instance;
  static StateDownloadService get instance =>
      _instance ??= StateDownloadService._();
  StateDownloadService._();

  List<StateInfo> _states = [];
  List<StateInfo> get states => _states;

  Future<void> init() async {
    // Load manifest from bundled assets
    final raw = await rootBundle.loadString('assets/data/manifest.json');
    final list = json.decode(raw) as List<dynamic>;
    _states =
        list.map((e) => StateInfo.fromJson(e as Map<String, dynamic>)).toList();

    // Check which are already downloaded
    final prefs = await SharedPreferences.getInstance();
    for (final s in _states) {
      s.isDownloaded = prefs.getBool('downloaded_${s.id}') ?? false;
      s.isTilesDownloaded = prefs.getBool('tiles_downloaded_${s.id}') ?? false;
      // Verify file actually exists and size matches manifest
      if (s.isDownloaded) {
        final file = await _stateFile(s.id);
        if (!await file.exists()) {
          s.isDownloaded = false;
          await prefs.setBool('downloaded_${s.id}', false);
        } else {
          final sizeBytes = await file.length();
          final actualMb = sizeBytes / (1024 * 1024);
          if ((actualMb - s.sizeMb).abs() > 2.0) {
            // File is corrupted or outdated (we reverted to original clean geometries)
            s.isDownloaded = false;
            await prefs.setBool('downloaded_${s.id}', false);
            try { await file.delete(); } catch (_) {}
          }
        }
      }
      if (s.isTilesDownloaded && s.tilesFilename != null) {
        final file = await _tilesFile(s.id);
        if (!await file.exists()) {
          s.isTilesDownloaded = false;
          await prefs.setBool('tiles_downloaded_${s.id}', false);
        }
      }
    }
  }

  Future<File> _stateFile(String stateId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/boundaries/$stateId.geojson');
  }

  Future<File> _tilesFile(String stateId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/boundary_tiles/$stateId.pmtiles');
  }

  Future<String?> tilesPathIfExists(String stateId) async {
    try {
      final file = await _tilesFile(stateId);
      if (await file.exists()) return file.path;
    } catch (_) {}
    return null;
  }

  Future<int?> downloadedBytes(String stateId) async {
    try {
      final file = await _stateFile(stateId);
      if (!await file.exists()) return null;
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  Future<double?> downloadedMb(String stateId) async {
    final b = await downloadedBytes(stateId);
    if (b == null) return null;
    return b / (1024 * 1024);
  }

  Future<double> totalDownloadedMb() async {
    double total = 0;
    for (final s in _states.where((x) => x.isDownloaded == true)) {
      final mb = await downloadedMb(s.id);
      if (mb != null) total += mb;
    }
    return total;
  }

  Future<void> download(
    StateInfo state, {
    required void Function(double) onProgress,
    required void Function() onDone,
    required void Function(String) onError,
  }) async {
    state.isDownloading = true;
    state.progress = 0;

    try {
      Future<void> downloadFile(
        Uri uri,
        File outFile, {
        required double progressStart,
        required double progressEnd,
      }) async {
        final request = http.Request('GET', uri);
        final response = await request.send();
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        final contentLength = response.contentLength ?? 0;
        var received = 0;
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            final p = received / contentLength;
            state.progress = progressStart + (progressEnd - progressStart) * p;
            onProgress(state.progress);
          }
        }
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(bytes);
      }

      // 1) Download GeoJSON
      await downloadFile(
        Uri.parse('$_baseUrl/${state.filename}'),
        await _stateFile(state.id),
        progressStart: 0.0,
        progressEnd: state.tilesFilename != null ? 0.7 : 1.0,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('downloaded_${state.id}', true);
      state.isDownloaded = true;

      // 2) Download PMTiles overlay (optional)
      if (state.tilesFilename != null) {
        await downloadFile(
          Uri.parse('$_baseUrl/${state.tilesFilename}'),
          await _tilesFile(state.id),
          progressStart: 0.7,
          progressEnd: 1.0,
        );
        await prefs.setBool('tiles_downloaded_${state.id}', true);
        state.isTilesDownloaded = true;
      }

      state.isDownloading = false;
      state.progress = 1.0;
      onDone();
    } catch (e) {
      state.isDownloading = false;
      state.isDownloaded = false;
      state.isTilesDownloaded = false;
      onError(e.toString());
    }
  }

  Future<void> delete(StateInfo state) async {
    final file = await _stateFile(state.id);
    if (await file.exists()) await file.delete();
    final tiles = await _tilesFile(state.id);
    if (await tiles.exists()) await tiles.delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('downloaded_${state.id}', false);
    await prefs.setBool('tiles_downloaded_${state.id}', false);
    state.isDownloaded = false;
    state.isTilesDownloaded = false;
  }

  /// Returns merged GeoJSON string from all downloaded states
  Future<String> loadDownloadedBoundaries() async {
    final allFeatures = <dynamic>[];

    for (final state in _states.where((s) => s.isDownloaded)) {
      try {
        final file = await _stateFile(state.id);
        final raw = await file.readAsString();
        final data = json.decode(raw) as Map<String, dynamic>;
        allFeatures.addAll(data['features'] as List);
      } catch (_) {}
    }

    return json.encode({
      'type': 'FeatureCollection',
      'features': allFeatures,
    });
  }

  bool get hasAnyDownloaded => _states.any((s) => s.isDownloaded);
  bool get hasAnyTilesDownloaded =>
      _states.any((s) => s.isTilesDownloaded && s.tilesFilename != null);
}
