import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';
import 'edit_screen.dart';

class PppoeActiveScreen extends StatefulWidget {
  final MikrotikApi api;
  const PppoeActiveScreen({super.key, required this.api});

  @override
  State<PppoeActiveScreen> createState() => _PppoeActiveScreenState();
}

class _PppoeActiveScreenState extends State<PppoeActiveScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  List<Map<String, String>> _users = [];
  Map<String, Map<String, int>> _traffic = {};
  final Map<String, _TrafficSample> _lastTraffic = {};
  bool _loading = true;
  bool _isFetching = false;
  bool _active = true;
  String _search = '';
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetch();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _fetch();
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      if (_active) _fetch();
    });
  }

  Future<void> _fetch() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final users = await widget.api.query([
        '/ppp/active/print',
        '=.proplist=.id,name,address,uptime,service,caller-id,bytes-in,bytes-out',
      ]);
      final traffic = _calculateTraffic(users);

      if (!mounted) return;
      setState(() {
        _users = users;
        _traffic = traffic;
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _isFetching = false;
    }
  }

  Map<String, Map<String, int>> _calculateTraffic(
    List<Map<String, String>> users,
  ) {
    final now = DateTime.now();
    final activeNames = <String>{};
    final traffic = <String, Map<String, int>>{};

    for (final user in users) {
      final name = user['name'] ?? '';
      if (name.isEmpty) continue;

      final rxBytes = int.tryParse(user['bytes-in'] ?? '0') ?? 0;
      final txBytes = int.tryParse(user['bytes-out'] ?? '0') ?? 0;
      final previous = _lastTraffic[name];
      var rxRate = 0;
      var txRate = 0;

      if (previous != null) {
        final seconds = now.difference(previous.time).inMilliseconds / 1000;
        if (seconds > 0) {
          rxRate = ((math.max(0, rxBytes - previous.rxBytes) * 8) / seconds)
              .round();
          txRate = ((math.max(0, txBytes - previous.txBytes) * 8) / seconds)
              .round();
        }
      }

      _lastTraffic[name] = _TrafficSample(
        rxBytes: rxBytes,
        txBytes: txBytes,
        time: now,
      );
      activeNames.add(name);
      traffic[name] = {
        'rx': rxRate,
        'tx': txRate,
        'rxBytes': rxBytes,
        'txBytes': txBytes,
      };
    }

    _lastTraffic.removeWhere((key, _) => !activeNames.contains(key));
    return traffic;
  }

  String _fmtBytes(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)}GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)}MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${bytes}B';
  }

  String _fmtBps(int bits) {
    if (bits >= 1000000000) {
      return '${(bits / 1000000000).toStringAsFixed(1)}Gbps';
    }
    if (bits >= 1000000) return '${(bits / 1000000).toStringAsFixed(1)}Mbps';
    if (bits >= 1000) return '${(bits / 1000).toStringAsFixed(1)}Kbps';
    return '${bits}bps';
  }

  String _fmtUptime(String raw) {
    if (raw.trim().isEmpty || raw == '-') return '-';
    final days = RegExp(r'(\d+)d').firstMatch(raw);
    final hours = RegExp(r'(\d+)h').firstMatch(raw);
    final minutes = RegExp(r'(\d+)m').firstMatch(raw);

    final d = int.tryParse(days?.group(1) ?? '0') ?? 0;
    final h = int.tryParse(hours?.group(1) ?? '0') ?? 0;
    final m = int.tryParse(minutes?.group(1) ?? '0') ?? 0;

    if (d > 0) return '$d hari $h jam';
    if (h > 0) return '$h jam $m menit';
    return '$m menit';
  }

  String _fmtClock(DateTime? time) {
    if (time == null) return '--:--:--';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);
    final filtered = _users
        .where(
          (user) =>
              (user['name'] ?? '').toLowerCase().contains(
                _search.toLowerCase(),
              ) ||
              (user['address'] ?? '').contains(_search),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _search = value),
                style: TextStyle(color: c.txt, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Cari username atau IP',
                  hintStyle: TextStyle(color: c.sub, fontSize: 12),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: c.sub,
                    size: 18,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  filled: true,
                  fillColor: c.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  _chip(
                    '${filtered.length} online',
                    AppColors.orange,
                    Icons.cable_rounded,
                  ),
                  const SizedBox(width: 8),
                  _chip('4s realtime', AppColors.cyan, Icons.sync_rounded),
                  const Spacer(),
                  Text(
                    _fmtClock(_lastUpdated),
                    style: TextStyle(color: c.sub, fontSize: 10),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _isFetching ? null : _fetch,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(30, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.refresh_rounded, color: c.sub, size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (_, _) => SkeletonCard(c: c),
                )
              : filtered.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada PPPoE aktif',
                    style: TextStyle(color: c.sub),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  cacheExtent: 800,
                  itemCount: filtered.length,
                  itemBuilder: (_, index) =>
                      RepaintBoundary(child: _userCard(filtered[index], c)),
                ),
        ),
      ],
    );
  }

  Widget _userCard(Map<String, String> user, AppC c) {
    final name = user['name'] ?? '-';
    final traffic = _traffic[name];
    final down = traffic?['tx'] ?? 0;
    final up = traffic?['rx'] ?? 0;
    final totalDown = traffic?['txBytes'] ?? 0;
    final totalUp = traffic?['rxBytes'] ?? 0;
    final callerId = user['caller-id'] ?? '';
    final service = user['service'] ?? '';
    final meta = [
      user['address'] ?? '-',
      _fmtUptime(user['uptime'] ?? '-'),
      if (service.isNotEmpty) service,
    ].where((value) => value.isNotEmpty).join(' | ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.txt,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.sub, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit user',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PppoeEditScreen(api: widget.api, username: name),
                  ),
                ).then((_) => _fetch()),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.cyan.withValues(alpha: 0.08),
                ),
                icon: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.cyan,
                  size: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _rateTile(
                  'Down',
                  _fmtBps(down),
                  Icons.arrow_downward_rounded,
                  AppColors.green,
                  c,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _rateTile(
                  'Up',
                  _fmtBps(up),
                  Icons.arrow_upward_rounded,
                  AppColors.red,
                  c,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _compactInfo(
                  Icons.file_download_rounded,
                  'Total Down',
                  _fmtBytes(totalDown),
                  c,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInfo(
                  Icons.file_upload_rounded,
                  'Total Up',
                  _fmtBytes(totalUp),
                  c,
                ),
              ),
            ],
          ),
          if (callerId.isNotEmpty) ...[
            const SizedBox(height: 7),
            _compactInfo(Icons.router_outlined, 'Caller ID', callerId, c),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _rateTile(
    String label,
    String value,
    IconData icon,
    Color color,
    AppC c,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: c.sub, fontSize: 9)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInfo(IconData icon, String label, String value, AppC c) {
    return Row(
      children: [
        Icon(icon, color: c.sub, size: 12),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c.sub, fontSize: 9)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: c.txt,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrafficSample {
  final int rxBytes;
  final int txBytes;
  final DateTime time;

  const _TrafficSample({
    required this.rxBytes,
    required this.txBytes,
    required this.time,
  });
}
