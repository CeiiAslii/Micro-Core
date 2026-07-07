import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';

class HotspotActiveScreen extends StatefulWidget {
  final MikrotikApi api;
  const HotspotActiveScreen({super.key, required this.api});

  @override
  State<HotspotActiveScreen> createState() => _HotspotActiveScreenState();
}

class _HotspotActiveScreenState extends State<HotspotActiveScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  List<Map<String, String>> _users = [];
  final Map<String, _TrafficSample> _lastTraffic = {};
  final Map<String, int> _downRates = {};
  final Map<String, int> _upRates = {};
  Map<String, String> _deviceNames = {};
  bool _loading = true;
  bool _isFetching = false;
  bool _active = true;
  String _search = '';
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchDhcp();
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
    _timer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (_active) _fetch();
    });
  }

  Future<void> _fetchDhcp() async {
    try {
      final rows = await context.read<AppProvider>().cachedDhcpLeases();
      final names = <String, String>{};
      for (final lease in rows) {
        final mac = (lease['mac-address'] ?? '').toUpperCase();
        final name = lease['host-name'] ?? lease['comment'] ?? '';
        if (mac.isNotEmpty && name.isNotEmpty) names[mac] = name;
      }
      if (mounted) setState(() => _deviceNames = names);
    } catch (_) {}
  }

  Future<void> _fetch() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final rows = await widget.api.queryOrThrow([
        '/ip/hotspot/active/print',
        '=.proplist=.id,user,address,mac-address,uptime,bytes-in,bytes-out,rx-rate,tx-rate',
      ]);
      if (!mounted) return;
      setState(() {
        _updateRealtimeRates(rows);
        _users = rows;
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _isFetching = false;
    }
  }

  void _updateRealtimeRates(List<Map<String, String>> users) {
    final now = DateTime.now();
    final activeKeys = <String>{};

    for (final user in users) {
      final key = _userKey(user);
      activeKeys.add(key);

      final bytesIn = _parseCounter(user['bytes-in']);
      final bytesOut = _parseCounter(user['bytes-out']);
      final previous = _lastTraffic[key];

      if (previous != null) {
        final seconds = now.difference(previous.time).inMilliseconds / 1000;
        if (seconds > 0) {
          final downDelta = math.max(0, bytesOut - previous.bytesOut);
          final upDelta = math.max(0, bytesIn - previous.bytesIn);
          _downRates[key] = ((downDelta * 8) / seconds).round();
          _upRates[key] = ((upDelta * 8) / seconds).round();
        }
      } else {
        _downRates[key] = _parseBps(user['tx-rate']);
        _upRates[key] = _parseBps(user['rx-rate']);
      }

      _lastTraffic[key] = _TrafficSample(
        bytesIn: bytesIn,
        bytesOut: bytesOut,
        time: now,
      );
    }

    _lastTraffic.removeWhere((key, _) => !activeKeys.contains(key));
    _downRates.removeWhere((key, _) => !activeKeys.contains(key));
    _upRates.removeWhere((key, _) => !activeKeys.contains(key));
  }

  Future<void> _kickUser(String id, String user) async {
    final c = AppC(context.read<AppProvider>().isDark);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      await widget.api.queryOrThrow(['/ip/hotspot/active/remove', '=.id=$id']);
      _fetch();
    }
  }

  String _userKey(Map<String, String> user) {
    final id = user['.id'];
    if (id != null && id.isNotEmpty) return id;
    return [
      user['user'] ?? '',
      user['mac-address'] ?? '',
      user['address'] ?? '',
    ].join('|');
  }

  int _parseCounter(String? value) => int.tryParse(value ?? '0') ?? 0;

  int _parseBps(String? value) {
    final normalized = (value ?? '0').trim().toLowerCase().replaceAll(' ', '');
    final match = RegExp(r'^([\d.]+)([a-z/]*)$').firstMatch(normalized);
    if (match == null) return (double.tryParse(normalized) ?? 0).round();

    final number = double.tryParse(match.group(1) ?? '0') ?? 0;
    final unit = match.group(2) ?? '';
    if (unit.startsWith('g')) return (number * 1000000000).round();
    if (unit.startsWith('m')) return (number * 1000000).round();
    if (unit.startsWith('k')) return (number * 1000).round();
    return number.round();
  }

  String _fmtBytes(String value) {
    final bytes = int.tryParse(value) ?? 0;
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

  String _fmtClock(DateTime? time) {
    if (time == null) return '--:--:--';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  String _fmtUptime(String value) {
    if (value.isEmpty || value == '-') return '-';
    final days =
        int.tryParse(RegExp(r'(\d+)d').firstMatch(value)?.group(1) ?? '') ?? 0;
    final hours =
        int.tryParse(RegExp(r'(\d+)h').firstMatch(value)?.group(1) ?? '') ?? 0;
    final minutes =
        int.tryParse(RegExp(r'(\d+)m').firstMatch(value)?.group(1) ?? '') ?? 0;

    if (days > 0) return '$days hari $hours jam';
    if (hours > 0) return '$hours jam $minutes menit';
    if (minutes > 0) return '$minutes menit';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);
    final filtered = _users
        .where(
          (user) =>
              (user['user'] ?? '').toLowerCase().contains(
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
                    AppColors.green,
                    Icons.wifi_rounded,
                  ),
                  const SizedBox(width: 8),
                  _chip('3s realtime', AppColors.cyan, Icons.sync_rounded),
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
                    'Tidak ada user aktif',
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
    final mac = (user['mac-address'] ?? '').toUpperCase();
    final deviceName = _deviceNames[mac] ?? '';
    final id = user['.id'] ?? '';
    final trafficKey = _userKey(user);
    final down = _downRates[trafficKey] ?? _parseBps(user['tx-rate']);
    final up = _upRates[trafficKey] ?? _parseBps(user['rx-rate']);
    final meta = [
      user['address'] ?? '-',
      _fmtUptime(user['uptime'] ?? '-'),
      if (deviceName.isNotEmpty) deviceName,
    ].join(' | ');

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
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['user'] ?? '-',
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
                tooltip: 'Kick user',
                onPressed: id.isEmpty
                    ? null
                    : () => _kickUser(id, user['user'] ?? ''),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.red.withValues(alpha: 0.08),
                ),
                icon: const Icon(
                  Icons.link_off_rounded,
                  color: AppColors.red,
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
                  _fmtBytes(user['bytes-out'] ?? '0'),
                  c,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _compactInfo(
                  Icons.file_upload_rounded,
                  'Total Up',
                  _fmtBytes(user['bytes-in'] ?? '0'),
                  c,
                ),
              ),
            ],
          ),
          if (mac.isNotEmpty) ...[
            const SizedBox(height: 7),
            _compactInfo(
              deviceName.isNotEmpty
                  ? Icons.devices_rounded
                  : Icons.memory_rounded,
              'MAC',
              mac,
              c,
            ),
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
  final int bytesIn;
  final int bytesOut;
  final DateTime time;

  const _TrafficSample({
    required this.bytesIn,
    required this.bytesOut,
    required this.time,
  });
}
