import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/dashboard_interface_card.dart';

class DashboardScreen extends StatefulWidget {
  final MikrotikApi api;
  final VoidCallback onOpenInterface;

  const DashboardScreen({
    super.key,
    required this.api,
    required this.onOpenInterface,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _resourceTimer;

  // Router info
  String _identity = '-';
  String _model = '-';
  String _version = '-';
  String _uptime = '-';
  String _platform = '-';

  // Resources
  int _cpuVal = 0;
  int _ramVal = 0;
  String _cpuLoad = '0%';
  String _temp = 'N/A';

  // Stats
  int _hotspot = 0;
  int _pppoe = 0;
  int _dhcp = 0;

  bool _loading = true;
  bool _isFetching = false;
  bool _isFetchingResources = false;
  bool _active = true;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _startTimers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _resourceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _refresh();
      _startTimers();
    } else {
      _timer?.cancel();
      _timer = null;
      _resourceTimer?.cancel();
      _resourceTimer = null;
    }
  }

  void _startTimers() {
    _timer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      if (_active) _refresh();
    });
    _resourceTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (_active) _refreshResources();
    });
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchIdentity(),
      _refreshResources(),
      _fetchHotspot(),
      _fetchPppoe(),
      _fetchDhcp(),
    ]);
    if (mounted) {
      setState(() {
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    }
  }

  Future<void> _refresh() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      await _fetchAll();
    } finally {
      _isFetching = false;
    }
  }

  String _formatClock(DateTime? time) {
    if (time == null) return '--:--';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  Future<void> _fetchIdentity() async {
    try {
      final r = await widget.api.queryOrThrow(['/system/identity/print']);
      if (r.isNotEmpty && mounted) {
        setState(() => _identity = r[0]['name'] ?? '-');
        context.read<AppProvider>().setRouterInfo(
          name: r[0]['name'] ?? '-',
          model: _model,
          version: _version,
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchResources() async {
    try {
      final r = await widget.api.queryOrThrow(['/system/resource/print']);
      if (r.isNotEmpty && mounted) {
        final d = r[0];
        final total = int.tryParse(d['total-memory'] ?? '0') ?? 0;
        final free = int.tryParse(d['free-memory'] ?? '0') ?? 0;
        final used = total - free;
        final pct = total > 0 ? ((used / total) * 100).round() : 0;

        // Fix suhu — coba semua field yang mungkin ada di RouterOS
        String temp = 'N/A';
        final tempFields = [
          'cpu-temperature',
          'board-temperature1',
          'board-temperature2',
          'temperature',
        ];
        for (final field in tempFields) {
          final val = d[field];
          if (val != null && val.isNotEmpty && val != '0') {
            temp = '$val C';
            break;
          }
        }
        // Jika masih N/A, coba query health
        if (temp == 'N/A') {
          try {
            final health = await widget.api.queryOrThrow([
              '/system/health/print',
            ]);
            if (health.isNotEmpty) {
              for (final h in health) {
                final name = h['name'] ?? '';
                final val = h['value'] ?? '';
                if (name.contains('temperature') && val.isNotEmpty) {
                  temp = '$val C';
                  break;
                }
              }
            }
          } catch (_) {}
        }

        if (!mounted) return;
        setState(() {
          _model = d['board-name'] ?? '-';
          _version = d['version'] ?? '-';
          _platform = d['platform'] ?? '-';
          _uptime = _formatUptime(d['uptime'] ?? '-');
          _cpuVal = int.tryParse(d['cpu-load'] ?? '0') ?? 0;
          _cpuLoad = '$_cpuVal%';
          _ramVal = pct;
          _temp = temp;
        });

        if (mounted) {
          context.read<AppProvider>().setRouterInfo(
            name: _identity,
            model: _model,
            version: _version,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshResources() async {
    if (_isFetchingResources) return;
    _isFetchingResources = true;
    try {
      await _fetchResources();
    } finally {
      _isFetchingResources = false;
    }
  }

  Future<void> _fetchHotspot() async {
    try {
      final r = await widget.api.queryOrThrow([
        '/ip/hotspot/active/print',
        '=.proplist=.id',
      ]);
      if (mounted) setState(() => _hotspot = r.length);
    } catch (_) {}
  }

  Future<void> _fetchPppoe() async {
    try {
      final r = await widget.api.queryOrThrow([
        '/ppp/active/print',
        '=.proplist=.id',
      ]);
      if (mounted) setState(() => _pppoe = r.length);
    } catch (_) {}
  }

  Future<void> _fetchDhcp() async {
    try {
      final r = await widget.api.queryOrThrow([
        '/ip/dhcp-server/lease/print',
        '?status=bound',
        '=.proplist=.id',
      ]);
      if (mounted) {
        setState(() => _dhcp = r.length);
      }
    } catch (_) {}
  }

  String _formatUptime(String uptime) {
    // Format: 1w2d3h4m5s → 1w 2d 3h 4m
    final match = RegExp(
      r'^(?:(\d+)w)?(?:(\d+)d)?(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$',
    ).firstMatch(uptime.trim());
    if (match == null) return uptime;

    final weeks = int.tryParse(match.group(1) ?? '0') ?? 0;
    final days = int.tryParse(match.group(2) ?? '0') ?? 0;
    final hours = int.tryParse(match.group(3) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(4) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(5) ?? '0') ?? 0;
    final totalDays = (weeks * 7) + days;

    if (totalDays > 0) {
      return hours > 0 ? '$totalDays Hari $hours Jam' : '$totalDays Hari';
    }
    if (hours > 0) {
      return minutes > 0 ? '$hours Jam $minutes Menit' : '$hours Jam';
    }
    if (minutes > 0) return '$minutes Menit';
    return '$seconds Detik';
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);

    if (_loading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Router card skeleton
            SkeletonRouterCard(c: c),
            const SizedBox(height: 14),
            SkeletonBox(width: 90, height: 13, radius: 4),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: SkeletonStat(c: c)),
                const SizedBox(width: 8),
                Expanded(child: SkeletonStat(c: c)),
                const SizedBox(width: 8),
                Expanded(child: SkeletonStat(c: c)),
              ],
            ),
            const SizedBox(height: 16),
            SkeletonBox(width: 105, height: 13, radius: 4),
            const SizedBox(height: 8),
            SkeletonInterfaceCard(c: c),
            const SizedBox(height: 12),
            SkeletonBox(height: 58, radius: 12),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.cyan,
      backgroundColor: c.card,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Router Info Card ─────────────────────
            _RouterCard(
              identity: _identity,
              model: _model,
              version: _version,
              uptime: _uptime,
              temp: _temp,
              cpuLoad: _cpuLoad,
              ramLoad: '$_ramVal%',
              c: c,
            ),

            const SizedBox(height: 14),

            // ── Section: Statistik ───────────────────
            _sectionHeader('Koneksi Aktif', c),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.wifi_rounded,
                    label: 'Hotspot',
                    value: '$_hotspot',
                    color: AppColors.green,
                    c: c,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.cable_rounded,
                    label: 'PPPoE',
                    value: '$_pppoe',
                    color: AppColors.orange,
                    c: c,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    icon: Icons.devices_rounded,
                    label: 'DHCP',
                    value: '$_dhcp',
                    color: AppColors.blue,
                    c: c,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _sectionHeader('Traffic Interface', c),
            const SizedBox(height: 8),
            DashboardInterfaceCard(
              api: widget.api,
              c: c,
              onOpenDetails: widget.onOpenInterface,
            ),

            const SizedBox(height: 12),

            // ── Section: Info ────────────────────────
            _InfoCard(
              identity: _identity,
              model: _model,
              version: _version,
              platform: _platform,
              uptime: _uptime,
              c: c,
            ),

            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _isFetching ? null : _refresh,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.refresh_rounded, color: c.sub, size: 15),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      'Update ${_formatClock(_lastUpdated)} - otomatis 10 detik',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.sub, fontSize: 10),
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

  Widget _sectionHeader(String title, AppC c) => Text(
    title,
    style: TextStyle(color: c.txt, fontSize: 13, fontWeight: FontWeight.w700),
  );
}

// ── Router Card ──────────────────────────────────────────
class _RouterCard extends StatelessWidget {
  final String identity, model, version, uptime, temp, cpuLoad, ramLoad;
  final AppC c;

  const _RouterCard({
    required this.identity,
    required this.model,
    required this.version,
    required this.uptime,
    required this.temp,
    required this.cpuLoad,
    required this.ramLoad,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.sub.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.router_rounded,
                  color: AppColors.cyan,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity,
                      style: TextStyle(
                        color: c.txt,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$model  •  RouterOS $version',
                      style: TextStyle(color: c.sub, fontSize: 9),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, color: c.sub, size: 11),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            uptime,
                            style: TextStyle(
                              color: c.txt,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Online badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: AppColors.green, size: 7),
                    SizedBox(width: 5),
                    Text(
                      'ONLINE',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: c.sub.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _infoChip(Icons.memory_rounded, 'CPU', cpuLoad)),
              const SizedBox(width: 6),
              Expanded(child: _infoChip(Icons.storage_rounded, 'RAM', ramLoad)),
              const SizedBox(width: 6),
              Expanded(
                child: _infoChip(Icons.thermostat_outlined, 'Suhu', temp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: c.bg,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.cyan, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: c.sub, fontSize: 9)),
              Text(
                value,
                style: TextStyle(
                  color: c.txt,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Stat Card ────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final AppC c;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.sub,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Card ────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String identity, model, version, platform, uptime;
  final AppC c;

  const _InfoCard({
    required this.identity,
    required this.model,
    required this.version,
    required this.platform,
    required this.uptime,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        leading: const Icon(
          Icons.info_outline_rounded,
          color: AppColors.cyan,
          size: 19,
        ),
        title: Text(
          'Detail Router',
          style: TextStyle(
            color: c.txt,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '$model | RouterOS $version',
          style: TextStyle(color: c.sub, fontSize: 9),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconColor: AppColors.cyan,
        collapsedIconColor: c.sub,
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          _row('Nama Router', identity, Icons.router_rounded, AppColors.cyan),
          _div(),
          _row('Model', model, Icons.developer_board_rounded, AppColors.purple),
          _div(),
          _row('Platform', platform, Icons.computer_rounded, AppColors.orange),
          _div(),
          _row('Uptime', uptime, Icons.timer_rounded, AppColors.blue),
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(color: c.sub, fontSize: 11)),
            ),
            Text(
              value,
              style: TextStyle(
                color: c.txt,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      );

  Widget _div() => Divider(color: c.sub.withValues(alpha: 0.08), height: 1);
}
