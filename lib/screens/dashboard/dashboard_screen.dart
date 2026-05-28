import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';

class DashboardScreen extends StatefulWidget {
  final MikrotikApi api;
  const DashboardScreen({super.key, required this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;

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
  String _ramUsed = '0 MB';
  String _ramTotal = '0 MB';
  String _ramPct = '0%';
  String _temp = 'N/A';
  String _hddFree = '-';
  String _hddTotal = '-';

  // Stats
  int _hotspot = 0;
  int _pppoe = 0;
  int _dhcp = 0;

  // Traffic total
  String _rxTotal = '0';
  String _txTotal = '0';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchAll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchIdentity(), _fetchResources()]);
    await Future.wait([_fetchHotspot(), _fetchPppoe(), _fetchDhcp()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchIdentity() async {
    try {
      final r = await widget.api.query(['/system/identity/print']);
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
      final r = await widget.api.query(['/system/resource/print']);
      if (r.isNotEmpty && mounted) {
        final d = r[0];
        final total = int.tryParse(d['total-memory'] ?? '0') ?? 0;
        final free = int.tryParse(d['free-memory'] ?? '0') ?? 0;
        final used = total - free;
        final pct = total > 0 ? ((used / total) * 100).round() : 0;

        final hddTotal = int.tryParse(d['total-hdd-space'] ?? '0') ?? 0;
        final hddFree = int.tryParse(d['free-hdd-space'] ?? '0') ?? 0;

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
            temp = '$val°C';
            break;
          }
        }
        // Jika masih N/A, coba query health
        if (temp == 'N/A') {
          try {
            final health = await widget.api.query(['/system/health/print']);
            if (health.isNotEmpty) {
              for (final h in health) {
                final name = h['name'] ?? '';
                final val = h['value'] ?? '';
                if (name.contains('temperature') && val.isNotEmpty) {
                  temp = '$val°C';
                  break;
                }
              }
            }
          } catch (_) {}
        }

        setState(() {
          _model = d['board-name'] ?? '-';
          _version = d['version'] ?? '-';
          _platform = d['platform'] ?? '-';
          _uptime = _formatUptime(d['uptime'] ?? '-');
          _cpuVal = int.tryParse(d['cpu-load'] ?? '0') ?? 0;
          _cpuLoad = '$_cpuVal%';
          _ramVal = pct;
          _ramUsed = _fmtMB(used);
          _ramTotal = _fmtMB(total);
          _ramPct = '$pct%';
          _temp = temp;
          _hddFree = _fmtMB(hddFree);
          _hddTotal = _fmtMB(hddTotal);
        });

        context.read<AppProvider>().setRouterInfo(
          name: _identity,
          model: _model,
          version: _version,
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchHotspot() async {
    try {
      final r = await widget.api.query(['/ip/hotspot/active/print']);
      if (mounted) setState(() => _hotspot = r.length);
    } catch (_) {}
  }

  Future<void> _fetchPppoe() async {
    try {
      final r = await widget.api.query(['/ppp/active/print']);
      if (mounted) setState(() => _pppoe = r.length);
    } catch (_) {}
  }

  Future<void> _fetchDhcp() async {
    try {
      final r = await widget.api.query(['/ip/dhcp-server/lease/print']);
      if (mounted) setState(() => _dhcp = r.length);
    } catch (_) {}
  }

  String _fmtMB(int bytes) {
    if (bytes >= 1073741824)
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(0)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  String _formatUptime(String uptime) {
    // Format: 1w2d3h4m5s → 1w 2d 3h 4m
    return uptime
        .replaceAll('w', 'w ')
        .replaceAll('d', 'd ')
        .replaceAll('h', 'h ')
        .replaceAll('m', 'm ')
        .replaceAll('s', 's')
        .trim();
  }

  String _fmtBps(int bps) {
    if (bps >= 1000000000)
      return '${(bps / 1000000000).toStringAsFixed(1)} Gbps';
    if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
    if (bps >= 1000) return '${(bps / 1000).toStringAsFixed(1)} Kbps';
    return '$bps bps';
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);

    if (_loading)
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Router card skeleton
            const SkeletonRouterCard(),
            const SizedBox(height: 20),
            // Stat skeletons
            Row(
              children: [
                Expanded(child: SkeletonStat(c: c)),
                const SizedBox(width: 12),
                Expanded(child: SkeletonStat(c: c)),
                const SizedBox(width: 12),
                Expanded(child: SkeletonStat(c: c)),
              ],
            ),
            const SizedBox(height: 20),
            SkeletonBox(height: 160, radius: 16),
            const SizedBox(height: 12),
            SkeletonBox(height: 120, radius: 16),
          ],
        ),
      );

    return RefreshIndicator(
      color: AppColors.cyan,
      backgroundColor: c.card,
      onRefresh: _fetchAll,
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
              platform: _platform,
              uptime: _uptime,
              temp: _temp,
              cpuLoad: _cpuLoad,
              cpuVal: _cpuVal,
              ramPct: _ramPct,
              ramUsed: _ramUsed,
              ramTotal: _ramTotal,
              ramVal: _ramVal,
              hddFree: _hddFree,
              hddTotal: _hddTotal,
              c: c,
            ),

            const SizedBox(height: 20),

            // ── Section: Statistik ───────────────────
            _sectionHeader('Statistik Aktif', c),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.wifi_rounded,
                    label: 'Hotspot',
                    sub: 'User Online',
                    value: '$_hotspot',
                    color: AppColors.green,
                    c: c,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.cable_rounded,
                    label: 'PPPoE',
                    sub: 'Client Online',
                    value: '$_pppoe',
                    color: AppColors.orange,
                    c: c,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.devices_rounded,
                    label: 'DHCP',
                    sub: 'Lease Aktif',
                    value: '$_dhcp',
                    color: AppColors.blue,
                    c: c,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Section: Resource ────────────────────
            _sectionHeader('Resource Monitor', c),
            const SizedBox(height: 12),

            _ResourceCard(
              cpuVal: _cpuVal,
              cpuLoad: _cpuLoad,
              ramVal: _ramVal,
              ramUsed: _ramUsed,
              ramTotal: _ramTotal,
              hddFree: _hddFree,
              hddTotal: _hddTotal,
              temp: _temp,
              c: c,
            ),

            const SizedBox(height: 20),

            // ── Section: Info ────────────────────────
            _sectionHeader('Info Router', c),
            const SizedBox(height: 12),

            _InfoCard(
              identity: _identity,
              model: _model,
              version: _version,
              platform: _platform,
              uptime: _uptime,
              c: c,
            ),

            const SizedBox(height: 12),

            // Auto refresh info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sync_rounded,
                    color: AppColors.cyan,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Auto refresh setiap 5 detik',
                    style: TextStyle(color: c.sub, fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _fetchAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Refresh',
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, AppC c) => Row(
    children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          color: AppColors.cyan,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          color: c.txt,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

// ── Router Card ──────────────────────────────────────────
class _RouterCard extends StatelessWidget {
  final String identity, model, version, platform;
  final String uptime, temp, cpuLoad, ramPct, ramUsed, ramTotal;
  final String hddFree, hddTotal;
  final int cpuVal, ramVal;
  final AppC c;

  const _RouterCard({
    required this.identity,
    required this.model,
    required this.version,
    required this.platform,
    required this.uptime,
    required this.temp,
    required this.cpuLoad,
    required this.ramPct,
    required this.ramUsed,
    required this.ramTotal,
    required this.hddFree,
    required this.hddTotal,
    required this.cpuVal,
    required this.ramVal,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003A4D), Color(0xFF006680)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.router_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$model  •  RouterOS $version',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
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
                  color: AppColors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.5),
                  ),
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

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 14),

          // Uptime + Suhu
          Row(
            children: [
              Expanded(
                child: _infoChip(Icons.timer_outlined, 'Uptime', uptime),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoChip(Icons.thermostat_outlined, 'Suhu', temp),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // CPU bar
          _resourceBar('CPU', cpuLoad, cpuVal, _cpuColor(cpuVal)),
          const SizedBox(height: 8),

          // RAM bar
          _resourceBar(
            'RAM',
            '$ramUsed / $ramTotal ($ramPct)',
            ramVal,
            _ramColor(ramVal),
          ),

          const SizedBox(height: 10),

          // HDD
          Row(
            children: [
              const Icon(
                Icons.storage_rounded,
                color: Colors.white60,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Storage: ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              Text(
                '$hddFree free / $hddTotal total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _cpuColor(int v) => v > 80
      ? AppColors.red
      : v > 60
      ? AppColors.orange
      : AppColors.green;

  Color _ramColor(int v) => v > 85
      ? AppColors.red
      : v > 65
      ? AppColors.orange
      : AppColors.cyan;

  Widget _infoChip(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white60, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

  Widget _resourceBar(String label, String value, int pct, Color color) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 7,
            ),
          ),
        ],
      );
}

// ── Stat Card ────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, sub, value;
  final Color color;
  final AppC c;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.color,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: TextStyle(
              color: c.txt,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(label, style: TextStyle(color: c.sub, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Resource Card ────────────────────────────────────────
class _ResourceCard extends StatelessWidget {
  final int cpuVal, ramVal;
  final String cpuLoad, ramUsed, ramTotal, hddFree, hddTotal, temp;
  final AppC c;

  const _ResourceCard({
    required this.cpuVal,
    required this.ramVal,
    required this.cpuLoad,
    required this.ramUsed,
    required this.ramTotal,
    required this.hddFree,
    required this.hddTotal,
    required this.temp,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // CPU
          _resRow(
            icon: Icons.memory_rounded,
            label: 'CPU Usage',
            value: cpuLoad,
            pct: cpuVal,
            color: cpuVal > 80
                ? AppColors.red
                : cpuVal > 60
                ? AppColors.orange
                : AppColors.green,
            c: c,
          ),
          const SizedBox(height: 14),
          // RAM
          _resRow(
            icon: Icons.storage_rounded,
            label: 'RAM  ($ramUsed / $ramTotal)',
            value: '$ramVal%',
            pct: ramVal,
            color: ramVal > 85
                ? AppColors.red
                : ramVal > 65
                ? AppColors.orange
                : AppColors.cyan,
            c: c,
          ),
          const SizedBox(height: 14),
          Divider(color: c.sub.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 12),
          // Bottom info row
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  Icons.thermostat_rounded,
                  'Suhu CPU',
                  temp,
                  AppColors.orange,
                  c,
                ),
              ),
              Expanded(
                child: _infoItem(
                  Icons.folder_rounded,
                  'Storage Free',
                  hddFree,
                  AppColors.purple,
                  c,
                ),
              ),
              Expanded(
                child: _infoItem(
                  Icons.folder_open_rounded,
                  'Storage Total',
                  hddTotal,
                  AppColors.blue,
                  c,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resRow({
    required IconData icon,
    required String label,
    required String value,
    required int pct,
    required Color color,
    required AppC c,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: TextStyle(color: c.sub, fontSize: 12)),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: (pct / 100).clamp(0.0, 1.0),
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ),
    ],
  );

  Widget _infoItem(
    IconData icon,
    String label,
    String value,
    Color color,
    AppC c,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: c.txt,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: TextStyle(color: c.sub, fontSize: 10)),
    ],
  );
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _row('Nama Router', identity, Icons.router_rounded, AppColors.cyan),
          _div(),
          _row('Model', model, Icons.developer_board_rounded, AppColors.purple),
          _div(),
          _row(
            'RouterOS',
            version,
            Icons.system_update_rounded,
            AppColors.green,
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
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
              child: Text(label, style: TextStyle(color: c.sub, fontSize: 13)),
            ),
            Text(
              value,
              style: TextStyle(
                color: c.txt,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      );

  Widget _div() => Divider(color: c.sub.withValues(alpha: 0.08), height: 1);
}
