import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/router_choice_field.dart';
import '../../widgets/skeleton.dart';

class SystemControlScreen extends StatefulWidget {
  final MikrotikApi api;

  const SystemControlScreen({super.key, required this.api});

  @override
  State<SystemControlScreen> createState() => _SystemControlScreenState();
}

class _SystemControlScreenState extends State<SystemControlScreen> {
  Map<String, String> _identity = {};
  Map<String, String> _clock = {};
  Map<String, String> _note = {};
  Map<String, String> _resource = {};
  Map<String, String> _routerboard = {};
  Map<String, String> _update = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final results = await Future.wait([
      widget.api.query(['/system/identity/print']),
      widget.api.query(['/system/clock/print']),
      widget.api.query(['/system/note/print']),
      widget.api.query(['/system/resource/print']),
      widget.api.query(['/system/routerboard/print']),
      widget.api.query(['/system/package/update/print']),
    ]);
    if (mounted) {
      setState(() {
        _identity = _first(results[0]);
        _clock = _first(results[1]);
        _note = _first(results[2]);
        _resource = _first(results[3]);
        _routerboard = _first(results[4]);
        _update = _first(results[5]);
        _loading = false;
        _busy = false;
      });
    }
  }

  Map<String, String> _first(List<Map<String, String>> rows) =>
      rows.isEmpty ? {} : rows.first;

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: 6,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: SkeletonBox(height: 88, radius: 10),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        children: [
          _overview(c),
          const SizedBox(height: 8),
          _settingCard(
            c,
            icon: Icons.badge_outlined,
            title: 'Identity',
            value: _identity['name'] ?? '-',
            onEdit: () => _editSingle(
              title: 'Router Identity',
              label: 'Name',
              initial: _identity['name'] ?? '',
              endpoint: '/system/identity/set',
              key: 'name',
            ),
          ),
          _settingCard(
            c,
            icon: Icons.schedule_outlined,
            title: 'Clock & Timezone',
            value: _join([
              _clock['date'],
              _clock['time'],
              _clock['time-zone-name'],
            ]),
            onEdit: _editClock,
          ),
          _settingCard(
            c,
            icon: Icons.sticky_note_2_outlined,
            title: 'System Note',
            value: (_note['note'] ?? '').isEmpty
                ? 'Belum ada catatan'
                : _note['note']!,
            onEdit: () => _editSingle(
              title: 'System Note',
              label: 'Note',
              initial: _note['note'] ?? '',
              endpoint: '/system/note/set',
              key: 'note',
              multiline: true,
            ),
          ),
          const SizedBox(height: 6),
          _section('MAINTENANCE', c),
          _actionGrid(c),
          const SizedBox(height: 10),
          _section('ROUTERBOARD', c),
          _detailsCard(c, {
            'Model': _routerboard['model'] ?? _resource['board-name'] ?? '-',
            'Serial': _routerboard['serial-number'] ?? '-',
            'Firmware': _routerboard['current-firmware'] ?? '-',
            'Upgrade': _routerboard['upgrade-firmware'] ?? '-',
            'Factory Firmware': _routerboard['factory-firmware'] ?? '-',
          }),
          const SizedBox(height: 10),
          _section('PACKAGE UPDATE', c),
          _updateCard(c),
        ],
      ),
    );
  }

  Widget _overview(AppC c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.router_rounded,
              color: AppColors.cyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _identity['name'] ?? 'Router',
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _join([
                    _resource['board-name'],
                    'RouterOS ${_resource['version'] ?? '-'}',
                  ]),
                  style: TextStyle(color: c.sub, fontSize: 9),
                ),
              ],
            ),
          ),
          Text(
            _resource['uptime'] ?? '-',
            style: const TextStyle(
              color: AppColors.green,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingCard(
    AppC c, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.cyan, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.sub, fontSize: 9),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: _busy ? null : onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.cyan,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionGrid(AppC c) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      childAspectRatio: 2.75,
      children: [
        _actionTile(
          c,
          Icons.backup_outlined,
          'Binary Backup',
          AppColors.cyan,
          _backup,
        ),
        _actionTile(
          c,
          Icons.description_outlined,
          'Export Config',
          AppColors.green,
          _export,
        ),
        _actionTile(
          c,
          Icons.restart_alt_rounded,
          'Reboot',
          AppColors.orange,
          () => _powerAction('reboot'),
        ),
        _actionTile(
          c,
          Icons.power_settings_new_rounded,
          'Shutdown',
          AppColors.red,
          () => _powerAction('shutdown'),
        ),
      ],
    );
  }

  Widget _actionTile(
    AppC c,
    IconData icon,
    String label,
    Color color,
    VoidCallback action,
  ) {
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: _busy ? null : action,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: c.txt,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailsCard(AppC c, Map<String, String> details) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: details.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(color: c.sub, fontSize: 9),
                      ),
                    ),
                    Text(
                      entry.value,
                      style: TextStyle(
                        color: c.txt,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _updateCard(AppC c) {
    final installed =
        _update['installed-version'] ?? _resource['version'] ?? '-';
    final latest = _update['latest-version'] ?? 'Belum diperiksa';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_alt_rounded, color: AppColors.cyan),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Installed $installed',
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Latest $latest',
                  style: TextStyle(color: c.sub, fontSize: 9),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _checkUpdate,
            child: const Text('Check'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, AppC c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 7),
      child: Text(
        title,
        style: TextStyle(
          color: c.sub,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Future<void> _editSingle({
    required String title,
    required String label,
    required String initial,
    required String endpoint,
    required String key,
    bool multiline = false,
  }) async {
    final value = await _inputDialog(
      title: title,
      label: label,
      initial: initial,
      multiline: multiline,
    );
    if (value == null) return;
    await _run([endpoint, '=$key=$value'], '$title diperbarui');
  }

  Future<void> _editClock() async {
    final timezone = await _inputDialog(
      title: 'Clock & Timezone',
      label: 'Timezone',
      initial: _clock['time-zone-name'] ?? '',
      options: const [
        'UTC',
        'Africa/Cairo',
        'America/Chicago',
        'America/Los_Angeles',
        'America/New_York',
        'Asia/Bangkok',
        'Asia/Dubai',
        'Asia/Hong_Kong',
        'Asia/Jakarta',
        'Asia/Jayapura',
        'Asia/Kuala_Lumpur',
        'Asia/Makassar',
        'Asia/Manila',
        'Asia/Singapore',
        'Asia/Tokyo',
        'Australia/Sydney',
        'Europe/London',
      ],
    );
    if (timezone == null || timezone.isEmpty) return;
    await _run([
      '/system/clock/set',
      '=time-zone-name=$timezone',
    ], 'Timezone diperbarui');
  }

  Future<String?> _inputDialog({
    required String title,
    required String label,
    required String initial,
    bool multiline = false,
    List<String> options = const [],
  }) async {
    final controller = TextEditingController(text: initial);
    final c = AppC(context.read<AppProvider>().isDark);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.card,
        title: Text(title, style: TextStyle(color: c.txt)),
        content: options.isNotEmpty
            ? RouterChoiceField(
                controller: controller,
                label: label,
                options: options,
              )
            : TextField(
                controller: controller,
                autofocus: true,
                minLines: multiline ? 4 : 1,
                maxLines: multiline ? 8 : 1,
                decoration: InputDecoration(labelText: label),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _backup() async {
    final name = await _fileName('Binary Backup', 'core-backup');
    if (name == null) return;
    await _run([
      '/system/backup/save',
      '=name=$name',
    ], 'Backup $name dibuat di Files');
  }

  Future<void> _export() async {
    final name = await _fileName('Export Configuration', 'core-export');
    if (name == null) return;
    await _run(['/export', '=file=$name'], 'Export $name dibuat di Files');
  }

  Future<String?> _fileName(String title, String fallback) async {
    final value = await _inputDialog(
      title: title,
      label: 'File name',
      initial: '$fallback-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (value == null || value.isEmpty) return null;
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '-');
  }

  Future<void> _checkUpdate() async {
    await _run([
      '/system/package/update/check-for-updates',
    ], 'Pemeriksaan update selesai');
  }

  Future<void> _powerAction(String action) async {
    final c = AppC(context.read<AppProvider>().isDark);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.card,
        title: Text(
          action == 'reboot' ? 'Reboot Router' : 'Shutdown Router',
          style: TextStyle(color: c.txt),
        ),
        content: Text(
          'Koneksi ke router akan terputus.',
          style: TextStyle(color: c.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action == 'reboot' ? 'Reboot' : 'Shutdown'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(['/system/$action'], 'Perintah $action dikirim', refresh: false);
  }

  Future<void> _run(
    List<String> command,
    String success, {
    bool refresh = true,
  }) async {
    setState(() => _busy = true);
    try {
      await widget.api.queryOrThrow(command);
      _message(success);
      if (refresh) await _fetchAfterAction();
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetchAfterAction() async {
    setState(() => _busy = false);
    await _fetch();
  }

  String _join(List<String?> values) {
    final parts = values.whereType<String>().where((value) => value.isNotEmpty);
    return parts.isEmpty ? '-' : parts.join('  |  ');
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.red : null,
      ),
    );
  }
}
