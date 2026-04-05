import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/state_download_service.dart';

class StateSelectorScreen extends StatefulWidget {
  final VoidCallback onDone;
  const StateSelectorScreen({super.key, required this.onDone});

  @override
  State<StateSelectorScreen> createState() => _StateSelectorScreenState();
}

class _StateSelectorScreenState extends State<StateSelectorScreen> {
  bool _loading = true;
  final Set<String> _selected = {};
  final Map<String, bool> _downloading = {};
  final Map<String, double> _progress = {};
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await StateDownloadService.instance.init();
    // Pre-select already downloaded states
    for (final s in StateDownloadService.instance.states) {
      if (s.isDownloaded) _selected.add(s.id);
    }
    setState(() => _loading = false);
  }

  Future<void> _downloadSelected() async {
    final toDownload = StateDownloadService.instance.states
        .where((s) => _selected.contains(s.id) && !s.isDownloaded)
        .toList();

    for (final state in toDownload) {
      setState(() {
        _downloading[state.id] = true;
        _progress[state.id] = 0;
        _errors.remove(state.id);
      });

      await StateDownloadService.instance.download(
        state,
        onProgress: (p) => setState(() => _progress[state.id] = p),
        onDone: () => setState(() {
          _downloading[state.id] = false;
          _progress[state.id] = 1.0;
        }),
        onError: (e) => setState(() {
          _downloading[state.id] = false;
          _errors[state.id] = e;
        }),
      );
    }

    // Mark setup complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_complete', true);
    widget.onDone();
  }

  bool get _anyDownloading => _downloading.values.any((v) => v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🗺️', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        const Text(
                          'Spatial Anchor Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Download boundary data for the states you want to navigate.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // State list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: StateDownloadService.instance.states.length,
                      itemBuilder: (context, i) {
                        final state = StateDownloadService.instance.states[i];
                        final isSelected = _selected.contains(state.id);
                        final isDownloading = _downloading[state.id] == true;
                        final progress = _progress[state.id] ?? 0.0;
                        final error = _errors[state.id];
                        final isDone = state.isDownloaded;

                        return GestureDetector(
                          onTap: _anyDownloading
                              ? null
                              : () => setState(() {
                                    if (isSelected) {
                                      _selected.remove(state.id);
                                    } else {
                                      _selected.add(state.id);
                                    }
                                  }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blueAccent.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blueAccent.withOpacity(0.5)
                                    : Colors.white12,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  // Checkbox
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blueAccent
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blueAccent
                                            : Colors.white38,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            color: Colors.white, size: 14)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(state.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            )),
                                        Text(
                                          '${state.sizeMb} MB',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.4),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status badge
                                  if (isDone && !isDownloading)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('✓ Ready',
                                          style: TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  if (error != null)
                                    const Icon(Icons.error_outline,
                                        color: Colors.redAccent, size: 18),
                                ]),

                                // Progress bar
                                if (isDownloading) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.white12,
                                      valueColor: const AlwaysStoppedAnimation(
                                          Colors.blueAccent),
                                      minHeight: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(progress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 11),
                                  ),
                                ],

                                if (error != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Failed: $error',
                                      style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 11)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_selected.isEmpty)
                          Text(
                            'Select at least one state to continue',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selected.isNotEmpty && !_anyDownloading
                                      ? Colors.blueAccent
                                      : Colors.grey.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _selected.isNotEmpty && !_anyDownloading
                                ? _downloadSelected
                                : null,
                            child: _anyDownloading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white)),
                                      SizedBox(width: 10),
                                      Text('Downloading...',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  )
                                : Text(
                                    StateDownloadService.instance.states.any(
                                            (s) =>
                                                _selected.contains(s.id) &&
                                                !s.isDownloaded)
                                        ? 'Download & Continue'
                                        : 'Continue',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
