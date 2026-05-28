import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';

class HotspotActiveScreen extends StatefulWidget {
  final MikrotikApi api;
  const HotspotActiveScreen({super.key, required this.api});

  @override
  State<HotspotActiveScreen> createState() => _HotspotActiveScreenState();
}

class _HotspotActiveScreenState extends State<HotspotActiveScreen> {
  Timer? _timer;
  List<Map<String, String>> _users = [];
  Map<String, String> _deviceNames = {};
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchDhcp();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDhcp() async {
    try {
      final r = await widget.api.query(['/ip/dhcp-server/lease/print']);
      final map = <String, String>{};
      for (final l in r) {
        final mac = (l['mac-address'] ?? '').toUpperCase();
        final name = l['host-name'] ?? l['comment'] ?? '';
        if (mac.isNotEmpty && name.isNotEmpty) map[mac] = name;
      }
      if (mounted) setState(() => _deviceNames = map);
    } catch (_) {}
  }

  Future<void> _fetch() async {
    try {
      final r = await widget.api.query(['/ip/hotspot/active/print']);
      if (mounted && r.isNotEmpty) {
        setState(() {
          _users = r;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _kickUser(String id, String user) async {
    final c = AppC(context.read<AppProvider>().isDark);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Kick User', style: TextStyle(color: c.txt)),
        content: Text(
          'Putuskan koneksi "$user"?',
          style: TextStyle(color: c.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: c.sub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Kick'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.query(['/ip/hotspot/active/remove', '=.id=$id']);
      _fetch();
    }
  }

  String _fmtBytes(String b) {
    final v = int.tryParse(b) ?? 0;
    if (v >= 1073741824) return '${(v / 1073741824).toStringAsFixed(1)}GB';
    if (v >= 1048576) return '${(v / 1048576).toStringAsFixed(1)}MB';
    if (v >= 1024) return '${(v / 1024).toStringAsFixed(1)}KB';
    return '${v}B';
  }

  String _fmtBps(String b) {
    final v = int.tryParse(b) ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}Mbps';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}Kbps';
    return '${v}bps';
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);
    final filtered = _users
        .where(
          (u) =>
              (u['user'] ?? '').toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
        // Search + count
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(color: c.txt),
                decoration: InputDecoration(
                  hintText: 'Cari username...',
                  hintStyle: TextStyle(color: c.sub),
                  prefixIcon: Icon(Icons.search, color: c.sub),
                  filled: true,
                  fillColor: c.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip(
                    '${filtered.length} online',
                    AppColors.green,
                    Icons.wifi_rounded,
                  ),
                  const SizedBox(width: 8),
                  _chip('Refresh tiap 3s', AppColors.cyan, Icons.sync_rounded),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 5,
                  itemBuilder: (_, __) => SkeletonCard(c: c),
                )
              : filtered.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada user aktif',
                    style: TextStyle(color: c.sub),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  cacheExtent: 800,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final mac = (u['mac-address'] ?? '').toUpperCase();
                    final dev = _deviceNames[mac] ?? '';
                    final id = u['.id'] ?? '';

                    return RepaintBoundary(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.green.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.wifi_rounded,
                                    color: AppColors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u['user'] ?? '-',
                                        style: TextStyle(
                                          color: c.txt,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        u['address'] ?? '-',
                                        style: TextStyle(
                                          color: c.sub,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Kick button
                                GestureDetector(
                                  onTap: () => _kickUser(id, u['user'] ?? ''),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.red.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.red.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Kick',
                                      style: TextStyle(
                                        color: AppColors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Divider(
                              color: c.sub.withValues(alpha: 0.1),
                              height: 1,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _info(
                                    'Uptime',
                                    u['uptime'] ?? '-',
                                    c.sub,
                                    c.txt,
                                  ),
                                ),
                                Expanded(
                                  child: _info(
                                    'Upload',
                                    _fmtBytes(u['bytes-out'] ?? '0'),
                                    c.sub,
                                    AppColors.red,
                                  ),
                                ),
                                Expanded(
                                  child: _info(
                                    'Download',
                                    _fmtBytes(u['bytes-in'] ?? '0'),
                                    c.sub,
                                    AppColors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Hanya tampilkan jika ada traffic
                            ...(() {
                              final txRate = u['tx-rate'] ?? '0';
                              final rxRate = u['rx-rate'] ?? '0';
                              final txInt = int.tryParse(txRate) ?? 0;
                              final rxInt = int.tryParse(rxRate) ?? 0;

                              if (txInt > 0 || rxInt > 0) {
                                return [
                                  Row(
                                    children: [
                                      if (txInt > 0)
                                        Expanded(
                                          child: _liveBox(
                                            'TX',
                                            _fmtBps(txRate),
                                            AppColors.red,
                                          ),
                                        ),
                                      if (txInt > 0 && rxInt > 0)
                                        const SizedBox(width: 8),
                                      if (rxInt > 0)
                                        Expanded(
                                          child: _liveBox(
                                            'RX',
                                            _fmtBps(rxRate),
                                            AppColors.green,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ];
                              }
                              return [];
                            })(),
                            Row(
                              children: [
                                Icon(
                                  dev.isNotEmpty
                                      ? Icons.devices_rounded
                                      : Icons.device_unknown_rounded,
                                  color: c.sub,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    dev.isNotEmpty ? '$dev  •  $mac' : mac,
                                    style: TextStyle(
                                      color: c.sub,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _info(String label, String value, Color sub, Color vc) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: sub, fontSize: 10)),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(color: vc, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    ],
  );

  Widget _liveBox(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(
          label == 'TX'
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          color: color,
          size: 13,
        ),
        const SizedBox(width: 4),
        Text('$label  ', style: TextStyle(color: color, fontSize: 10)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
