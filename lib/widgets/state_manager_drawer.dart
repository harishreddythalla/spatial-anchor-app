import 'package:flutter/material.dart';
import '../services/state_download_service.dart';

class StateManagerDrawer extends StatefulWidget {
  const StateManagerDrawer({super.key});

  @override
  State<StateManagerDrawer> createState() => _StateManagerDrawerState();
}

class _StateManagerDrawerState extends State<StateManagerDrawer> {
  bool _loading = true;
  String? _globalError;
  final Map<String, String> _errors = {};
  final Map<String, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await StateDownloadService.instance.init();
    } catch (e) {
      _globalError = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _download(StateInfo state) async {
    setState(() {
      _errors.remove(state.id);
      _progress[state.id] = 0;
      state.isDownloading = true;
      state.progress = 0;
    });

    await StateDownloadService.instance.download(
      state,
      onProgress: (p) => mounted ? setState(() => _progress[state.id] = p) : null,
      onDone: () => mounted
          ? setState(() {
              state.isDownloading = false;
              _progress[state.id] = 1;
            })
          : null,
      onError: (e) => mounted
          ? setState(() {
              state.isDownloading = false;
              _errors[state.id] = e;
            })
          : null,
    );
  }

  Future<void> _delete(StateInfo state) async {
    await StateDownloadService.instance.delete(state);
    if (!mounted) return;
    setState(() {});
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      );

  Widget _stateTile(StateInfo state, {required bool downloaded}) {
    final isDownloading = state.isDownloading;
    final err = _errors[state.id];
    final prog = _progress[state.id] ?? state.progress;

    return InkWell(
      onTap: (!downloaded && !isDownloading) ? () => _download(state) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<double?>(
                        future: downloaded
                            ? StateDownloadService.instance.downloadedMb(state.id)
                            : null,
                        builder: (context, snap) {
                          final used = snap.data;
                          final label = downloaded && used != null
                              ? '${used.toStringAsFixed(1)} MB on device'
                              : '${state.sizeMb.toStringAsFixed(1)} MB';
                          return Text(
                            label,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (downloaded && !isDownloading)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    onPressed: () => _delete(state),
                    child: const Text('Remove',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  )
                else if (!downloaded)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isDownloading ? null : () => _download(state),
                    child: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Download',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800)),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('✓ Ready',
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: prog == 0 ? null : prog,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  minHeight: 6,
                ),
              ),
            ],
            if (err != null) ...[
              const SizedBox(height: 6),
              Text(
                err,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0A0A1A),
      child: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.menu, color: Colors.white70, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Offline States',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close,
                              color: Colors.white70, size: 18),
                        ),
                      ],
                    ),
                  ),
                  if (_globalError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        _globalError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  FutureBuilder<double>(
                    future: StateDownloadService.instance.totalDownloadedMb(),
                    builder: (context, snap) {
                      final total = snap.data;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Text(
                          total == null
                              ? 'Storage used: …'
                              : 'Storage used: ${total.toStringAsFixed(1)} MB',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(
                    child: Builder(builder: (context) {
                      final all = StateDownloadService.instance.states;
                      final downloaded = all.where((s) => s.isDownloaded).toList()
                        ..sort((a, b) => a.name.compareTo(b.name));
                      final available = all.where((s) => !s.isDownloaded).toList()
                        ..sort((a, b) => a.name.compareTo(b.name));

                      return ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _sectionTitle('DOWNLOADED'),
                          if (downloaded.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                              child: Text(
                                'No states downloaded yet.',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12),
                              ),
                            )
                          else
                            ...downloaded
                                .map((s) =>
                                    _stateTile(s, downloaded: true))
                                .toList(),
                          _sectionTitle('DOWNLOAD MORE'),
                          if (available.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 6, 16, 10),
                              child: Text(
                                'No additional states available in the current manifest.',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12),
                              ),
                            ),
                          ...available
                              .map((s) => _stateTile(s, downloaded: false))
                              .toList(),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),
                  ),
                ],
              ),
      ),
    );
  }
}

