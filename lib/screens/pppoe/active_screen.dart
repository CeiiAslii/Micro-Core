import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';
import 'edit_screen.dart';

class PppoeActiveScreen extends StatefulWidget {
  final MikrotikApi api;
  const PppoeActiveScreen({super.key, required this.api});

  @override
  State<PppoeActiveScreen> createState() => _PppoeActiveScreenState();
}

class _PppoeActiveScreenState extends State<PppoeActiveScreen> {
  Timer? _timer;
  List<Map<String, String>> _users = [];
  Map<String, Map<String, int>> _traffic = {};
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final users = await widget.api.query(['/ppp/active/print']);
      final Map<String, Map<String, int>> tm = {};
      for (final u in users) {
        final name = u['name'] ?? '';
        if (name.isEmpty) continue;
        try {
          final t = await widget.api.query([
            '/interface/monitor-traffic',
            '=interface=<pppoe-$name>',
            '=once=',
          ]);
          if (t.isNotEmpty) {
            tm[name] = {
              'rx': int.tryParse(t[0]['rx-bits-per-second'] ?? '0') ?? 0,
              'tx': int.tryParse(t[0]['tx-bits-per-second'] ?? '0') ?? 0,
            };
          }
        } catch (_) {}
      }
      if (mounted && users.isNotEmpty) {
        setState(() {
          _users = users;
          _traffic = tm;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtBytes(String b) {
    final v = int.tryParse(b) ?? 0;
    if (v >= 1073741824) return '${(v / 1073741824).toStringAsFixed(1)}GB';
    if (v >= 1048576) return '${(v / 1048576).toStringAsFixed(1)}MB';
    if (v >= 1024) return '${(v / 1024).toStringAsFixed(1)}KB';
    return '${v}B';
  }

  String _fmtBps(int b) {
    if (b >= 1000000) return '${(b / 1000000).toStringAsFixed(1)}Mbps';
    if (b >= 1000) return '${(b / 1000).toStringAsFixed(1)}Kbps';
    return '${b}bps';
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);
    final filtered = _users
        .where(
          (u) =>
              (u['name'] ?? '').toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();

    return Column(
      children: [
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
                    AppColors.orange,
                    Icons.cable_rounded,
                  ),
                  const SizedBox(width: 8),
                  _chip('Refresh tiap 5s', AppColors.cyan, Icons.sync_rounded),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 4,
                  itemBuilder: (_, __) => SkeletonCard(c: c),
                )
              : filtered.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada PPPoE aktif',
                    style: TextStyle(color: c.sub),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  cacheExtent: 800,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final name = u['name'] ?? '-';
                    final t = _traffic[name];
                    final rx = t?['rx'] ?? 0;
                    final tx = t?['tx'] ?? 0;

                    return RepaintBoundary(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.orange.withValues(alpha: 0.2),
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
                                    color: AppColors.orange.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.orange,
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
                                        name,
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
                                // Edit button
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PppoeEditScreen(
                                        api: widget.api,
                                        username: name,
                                      ),
                                    ),
                                  ).then((_) => _fetch()),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cyan.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.cyan.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: AppColors.cyan,
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
                            Row(
                              children: [
                                Expanded(
                                  child: _liveBox(
                                    'TX',
                                    _fmtBps(tx),
                                    AppColors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _liveBox(
                                    'RX',
                                    _fmtBps(rx),
                                    AppColors.green,
                                  ),
                                ),
                              ],
                            ),
                            if (u['caller-id'] != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.router_outlined,
                                    color: c.sub,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'MAC: ${u['caller-id']}',
                                    style: TextStyle(
                                      color: c.sub,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
