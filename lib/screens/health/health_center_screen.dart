import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/router_health.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';

class HealthCenterScreen extends StatefulWidget {
  final MikrotikApi api;

  const HealthCenterScreen({super.key, required this.api});

  @override
  State<HealthCenterScreen> createState() => _HealthCenterScreenState();
}

class _HealthCenterScreenState extends State<HealthCenterScreen> {
  static const _evaluator = RouterHealthEvaluator();
  RouterHealthReport? _report;
  bool _loading = true;
  bool _fetching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    _fetching = true;
    if (_report == null && mounted) setState(() => _loading = true);

    try {
      final results = await Future.wait([
        widget.api.queryOrThrow(['/system/resource/print']),
        widget.api.queryOrThrow([
          '/interface/print',
          '=.proplist=name,type,running,disabled',
        ]),
        widget.api.queryOrThrow([
          '/ip/dhcp-server/lease/print',
          '=.proplist=status',
        ]),
        widget.api.queryOrThrow(['/log/print', '=.proplist=topics']),
      ]);
      final report = _evaluator.evaluate(
        resource: results[0].isEmpty ? const {} : results[0].first,
        interfaces: results[1],
        leases: results[2],
        logs: results[3],
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    if (_loading) return _loadingView(c);
    if (_report == null) return _errorView(c);
    final report = _report!;
    final scoreColor = _scoreColor(report.score);

    return RefreshIndicator(
      color: AppColors.cyan,
      onRefresh: _fetch,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scoreColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: report.score / 100,
                        strokeWidth: 7,
                        backgroundColor: scoreColor.withValues(alpha: 0.12),
                        color: scoreColor,
                      ),
                      Text(
                        '${report.score}',
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.status,
                        style: TextStyle(
                          color: c.txt,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report.findings.length} hasil pemeriksaan',
                        style: TextStyle(color: c.sub, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.sync_rounded, color: c.sub, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Tarik ke bawah untuk scan ulang',
                            style: TextStyle(color: c.sub, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Scan ulang',
                  onPressed: _fetching ? null : _fetch,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metric(c, 'CPU', '${report.cpu}%', AppColors.cyan),
              const SizedBox(width: 7),
              _metric(c, 'RAM', '${report.ram}%', AppColors.purple),
              const SizedBox(width: 7),
              _metric(c, 'Storage', '${report.storage}%', AppColors.orange),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              _metric(
                c,
                'Interface Down',
                '${report.interfacesDown}',
                report.interfacesDown > 0 ? AppColors.red : AppColors.green,
              ),
              const SizedBox(width: 7),
              _metric(c, 'DHCP Bound', '${report.boundLeases}', AppColors.blue),
              const SizedBox(width: 7),
              _metric(
                c,
                'Log Error',
                '${report.recentErrors}',
                report.recentErrors > 0 ? AppColors.red : AppColors.green,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Temuan dan Rekomendasi',
            style: TextStyle(
              color: c.txt,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...report.findings.map((finding) => _findingCard(finding, c)),
        ],
      ),
    );
  }

  Widget _metric(AppC c, String label, String value, Color color) {
    return Expanded(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.sub, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _findingCard(HealthFinding finding, AppC c) {
    final appearance = switch (finding.severity) {
      HealthSeverity.critical => (
        color: AppColors.red,
        icon: Icons.error_outline_rounded,
      ),
      HealthSeverity.warning => (
        color: AppColors.orange,
        icon: Icons.warning_amber_rounded,
      ),
      HealthSeverity.good => (
        color: AppColors.green,
        icon: Icons.check_circle_outline_rounded,
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: appearance.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(appearance.icon, color: appearance.color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  finding.detail,
                  style: TextStyle(color: c.sub, fontSize: 10, height: 1.35),
                ),
                const SizedBox(height: 7),
                Text(
                  finding.recommendation,
                  style: TextStyle(
                    color: appearance.color,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingView(AppC c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SkeletonBox(height: 104, radius: 12),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 56, radius: 9)),
            const SizedBox(width: 7),
            Expanded(child: SkeletonBox(height: 56, radius: 9)),
            const SizedBox(width: 7),
            Expanded(child: SkeletonBox(height: 56, radius: 9)),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SkeletonBox(height: 94, radius: 10),
          ),
        ),
      ],
    );
  }

  Widget _errorView(AppC c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.red,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              'Pemeriksaan gagal',
              style: TextStyle(color: c.txt, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              _error ?? 'Data router tidak tersedia',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.sub, fontSize: 10),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Scan Ulang'),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return AppColors.green;
    if (score >= 75) return AppColors.cyan;
    if (score >= 55) return AppColors.orange;
    return AppColors.red;
  }
}
