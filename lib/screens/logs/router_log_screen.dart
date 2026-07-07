import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';

enum _LogFilter { all, error, warning, info }

class RouterLogScreen extends StatefulWidget {
  final MikrotikApi api;

  const RouterLogScreen({super.key, required this.api});

  @override
  State<RouterLogScreen> createState() => _RouterLogScreenState();
}

class _RouterLogScreenState extends State<RouterLogScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  List<Map<String, String>> _logs = [];
  bool _loading = true;
  bool _fetching = false;
  bool _paused = false;
  bool _active = true;
  String? _error;
  String _search = '';
  _LogFilter _filter = _LogFilter.all;

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
      _fetch(silent: true);
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (_active && !_paused) _fetch(silent: true);
    });
  }

  Future<void> _fetch({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!silent && _logs.isEmpty && mounted) {
      setState(() => _loading = true);
    }

    try {
      final rows = await widget.api.queryOrThrow([
        '/log/print',
        '=.proplist=.id,time,topics,message',
      ]);
      if (!mounted) return;
      setState(() {
        _logs = rows.reversed.toList();
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

  List<Map<String, String>> get _visibleLogs {
    final query = _search.toLowerCase().trim();
    return _logs.where((log) {
      final topics = (log['topics'] ?? '').toLowerCase();
      final message = (log['message'] ?? '').toLowerCase();
      final matchesSearch =
          query.isEmpty || topics.contains(query) || message.contains(query);
      if (!matchesSearch) return false;

      return switch (_filter) {
        _LogFilter.all => true,
        _LogFilter.error => _isError(topics),
        _LogFilter.warning => _isWarning(topics),
        _LogFilter.info => !_isError(topics) && !_isWarning(topics),
      };
    }).toList();
  }

  bool _isError(String topics) {
    return topics.contains('error') ||
        topics.contains('critical') ||
        topics.contains('failed');
  }

  bool _isWarning(String topics) {
    return topics.contains('warning') || topics.contains('alert');
  }

  ({Color color, IconData icon, String label}) _appearance(String topics) {
    final normalized = topics.toLowerCase();
    if (_isError(normalized)) {
      return (
        color: AppColors.red,
        icon: Icons.error_outline_rounded,
        label: 'ERROR',
      );
    }
    if (_isWarning(normalized)) {
      return (
        color: AppColors.orange,
        icon: Icons.warning_amber_rounded,
        label: 'WARNING',
      );
    }
    if (normalized.contains('account') || normalized.contains('login')) {
      return (
        color: AppColors.purple,
        icon: Icons.person_outline_rounded,
        label: 'ACCOUNT',
      );
    }
    if (normalized.contains('interface')) {
      return (
        color: AppColors.green,
        icon: Icons.settings_ethernet_rounded,
        label: 'INTERFACE',
      );
    }
    return (
      color: AppColors.cyan,
      icon: Icons.info_outline_rounded,
      label: 'INFO',
    );
  }

  void _copyLog(Map<String, String> log) {
    final text =
        '[${log['time'] ?? '-'}] ${log['topics'] ?? 'info'}\n'
        '${log['message'] ?? '-'}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Log disalin')));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    final visible = _visibleLogs;
    final errors = _logs.where((log) => _isError(log['topics'] ?? '')).length;
    final warnings = _logs
        .where((log) => _isWarning(log['topics'] ?? ''))
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      c,
                      'Total',
                      '${_logs.length}',
                      Icons.receipt_long_outlined,
                      AppColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _summaryCard(
                      c,
                      'Warning',
                      '$warnings',
                      Icons.warning_amber_rounded,
                      AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _summaryCard(
                      c,
                      'Error',
                      '$errors',
                      Icons.error_outline_rounded,
                      AppColors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  style: TextStyle(color: c.txt, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Cari pesan atau topik log...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: c.sub,
                      size: 18,
                    ),
                    suffixIcon: IconButton(
                      tooltip: _paused ? 'Lanjutkan' : 'Jeda',
                      onPressed: () => setState(() => _paused = !_paused),
                      icon: Icon(
                        _paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: _paused ? AppColors.orange : c.sub,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('Semua', _LogFilter.all, c),
                          _filterChip('Error', _LogFilter.error, c),
                          _filterChip('Warning', _LogFilter.warning, c),
                          _filterChip('Info', _LogFilter.info, c),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    visualDensity: VisualDensity.compact,
                    onPressed: _fetching ? null : _fetch,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.cyan,
                      size: 19,
                    ),
                  ),
                ],
              ),
              if (_paused)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Auto-refresh dijeda',
                    style: TextStyle(color: AppColors.orange, fontSize: 9),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 6,
                  itemBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: SkeletonBox(height: 78, radius: 10),
                  ),
                )
              : _error != null && _logs.isEmpty
              ? _errorState(c)
              : visible.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada log yang sesuai',
                    style: TextStyle(color: c.sub, fontSize: 12),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.cyan,
                  onRefresh: _fetch,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: visible.length,
                    itemBuilder: (_, index) => _logCard(visible[index], c),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    AppC c,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(label, style: TextStyle(color: c.sub, fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _LogFilter filter, AppC c) {
    final selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _filter = filter),
        labelStyle: TextStyle(
          color: selected ? AppColors.darkBg : c.sub,
          fontSize: 10,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        selectedColor: AppColors.cyan,
      ),
    );
  }

  Widget _logCard(Map<String, String> log, AppC c) {
    final topics = log['topics'] ?? 'info';
    final appearance = _appearance(topics);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onLongPress: () => _copyLog(log),
      onTap: () => _showDetails(log, c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: appearance.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(appearance.icon, color: appearance.color, size: 15),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        appearance.label,
                        style: TextStyle(
                          color: appearance.color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          topics,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.sub, fontSize: 9),
                        ),
                      ),
                      Text(
                        log['time'] ?? '-',
                        style: TextStyle(color: c.sub, fontSize: 9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log['message'] ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.txt, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(AppC c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.red,
              size: 38,
            ),
            const SizedBox(height: 10),
            Text(
              'Log gagal dimuat',
              style: TextStyle(
                color: c.txt,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.sub, fontSize: 10),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(Map<String, String> log, AppC c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log['topics'] ?? 'Log Router',
                style: TextStyle(
                  color: c.txt,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                log['time'] ?? '-',
                style: TextStyle(color: c.sub, fontSize: 10),
              ),
              const SizedBox(height: 12),
              SelectableText(
                log['message'] ?? '-',
                style: TextStyle(color: c.txt, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _copyLog(log);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Salin Log'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
