import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/router_choice_field.dart';
import '../../widgets/skeleton.dart';

class PppoeServerScreen extends StatefulWidget {
  final MikrotikApi api;

  const PppoeServerScreen({super.key, required this.api});

  @override
  State<PppoeServerScreen> createState() => _PppoeServerScreenState();
}

class _PppoeServerScreenState extends State<PppoeServerScreen> {
  List<Map<String, String>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await widget.api.query([
        '/interface/pppoe-server/server/print',
      ]);
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([Map<String, String>? row]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PppoeServerEditor(api: widget.api, row: row),
    );
    if (changed == true) _fetch();
  }

  Future<void> _toggle(Map<String, String> row) async {
    final id = row['.id'];
    if (id == null) return;
    final disabled = row['disabled'] == 'true';
    try {
      await widget.api.queryOrThrow([
        '/interface/pppoe-server/server/${disabled ? 'enable' : 'disable'}',
        '=.id=$id',
      ]);
      await _fetch();
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _delete(Map<String, String> row) async {
    final id = row['.id'];
    if (id == null) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Hapus PPPoE Server'),
            content: Text(
              'Hapus server pada interface "${row['interface'] ?? '-'}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await widget.api.queryOrThrow([
        '/interface/pppoe-server/server/remove',
        '=.id=$id',
      ]);
      await _fetch();
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Text(
                '${_rows.length} PPPoE server',
                style: TextStyle(
                  color: c.txt,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _fetch,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.cyan),
              ),
              IconButton.filled(
                tooltip: 'Tambah PPPoE Server',
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 5,
                  itemBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.only(bottom: 7),
                    child: SkeletonBox(height: 66, radius: 10),
                  ),
                )
              : _rows.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada PPPoE server',
                    style: TextStyle(color: c.sub),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _rows.length,
                  itemBuilder: (_, index) => _card(_rows[index], c),
                ),
        ),
      ],
    );
  }

  Widget _card(Map<String, String> row, AppC c) {
    final disabled = row['disabled'] == 'true';
    final details = [
      row['service-name'],
      row['default-profile'],
      if ((row['max-sessions'] ?? '').isNotEmpty)
        'max ${row['max-sessions']} session',
    ].whereType<String>().where((value) => value.isNotEmpty).join('  |  ');
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(
            disabled ? Icons.pause_circle_outline : Icons.router_outlined,
            color: disabled ? c.sub : AppColors.green,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['interface'] ?? '-',
                  style: TextStyle(
                    color: disabled ? c.sub : c.txt,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  details.isEmpty ? 'default' : details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.sub, fontSize: 9),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'edit') _openEditor(row);
              if (action == 'toggle') _toggle(row);
              if (action == 'delete') _delete(row);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(disabled ? 'Enable' : 'Disable'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ],
      ),
    );
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

class _PppoeServerEditor extends StatefulWidget {
  final MikrotikApi api;
  final Map<String, String>? row;

  const _PppoeServerEditor({required this.api, this.row});

  @override
  State<_PppoeServerEditor> createState() => _PppoeServerEditorState();
}

class _PppoeServerEditorState extends State<_PppoeServerEditor> {
  final _interface = TextEditingController();
  final _serviceName = TextEditingController();
  final _profile = TextEditingController();
  final _maxMtu = TextEditingController();
  final _maxMru = TextEditingController();
  final _mrru = TextEditingController();
  final _keepalive = TextEditingController();
  final _maxSessions = TextEditingController();
  final _padoDelay = TextEditingController();
  final _acceptEmpty = TextEditingController();
  final _authentication = TextEditingController();
  final _oneSession = TextEditingController();
  List<String> _interfaces = [];
  List<String> _profiles = [];
  bool _loading = true;
  bool _saving = false;

  bool get _editing => widget.row != null;

  @override
  void initState() {
    super.initState();
    final row = widget.row ?? const <String, String>{};
    _interface.text = row['interface'] ?? '';
    _serviceName.text = row['service-name'] ?? '';
    _profile.text = row['default-profile'] ?? 'default';
    _maxMtu.text = row['max-mtu'] ?? '1480';
    _maxMru.text = row['max-mru'] ?? '1480';
    _mrru.text = row['mrru'] ?? '';
    _keepalive.text = row['keepalive-timeout'] ?? '10';
    _maxSessions.text = row['max-sessions'] ?? '0';
    _padoDelay.text = row['pado-delay'] ?? '0';
    _acceptEmpty.text = row['accept-empty-service'] ?? 'yes';
    _authentication.text = row['authentication'] ?? 'pap,chap,mschap1,mschap2';
    _oneSession.text = row['one-session-per-host'] ?? 'no';
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final results = await Future.wait([
      widget.api.query(['/interface/print']),
      widget.api.query(['/ppp/profile/print']),
    ]);
    if (!mounted) return;
    setState(() {
      _interfaces = results[0]
          .map((row) => row['name'])
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      _profiles = results[1]
          .map((row) => row['name'])
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _interface,
      _serviceName,
      _profile,
      _maxMtu,
      _maxMru,
      _mrru,
      _keepalive,
      _maxSessions,
      _padoDelay,
      _acceptEmpty,
      _authentication,
      _oneSession,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_interface.text.trim().isEmpty || _profile.text.trim().isEmpty) {
      _message('Interface dan default profile wajib dipilih');
      return;
    }
    setState(() => _saving = true);
    final command = <String>[
      '/interface/pppoe-server/server/${_editing ? 'set' : 'add'}',
      if (_editing) '=.id=${widget.row!['.id']}',
    ];
    final values = {
      'interface': _interface.text.trim(),
      'service-name': _serviceName.text.trim(),
      'default-profile': _profile.text.trim(),
      'max-mtu': _maxMtu.text.trim(),
      'max-mru': _maxMru.text.trim(),
      'mrru': _mrru.text.trim(),
      'keepalive-timeout': _keepalive.text.trim(),
      'max-sessions': _maxSessions.text.trim(),
      'pado-delay': _padoDelay.text.trim(),
      'accept-empty-service': _acceptEmpty.text.trim(),
      'authentication': _authentication.text.trim(),
      'one-session-per-host': _oneSession.text.trim(),
    };
    for (final entry in values.entries) {
      if (entry.value.isNotEmpty &&
          (!_editing || widget.row![entry.key] != entry.value)) {
        command.add('=${entry.key}=${entry.value}');
      }
    }
    try {
      if (!_editing || command.length > 2) {
        await widget.api.queryOrThrow(command);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_editing ? 'Edit' : 'Tambah'} PPPoE Server',
                style: TextStyle(
                  color: c.txt,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              RouterChoiceField(
                controller: _interface,
                label: 'Interface *',
                options: _interfaces,
                allowCustom: false,
                loading: _loading,
              ),
              const SizedBox(height: 7),
              RouterChoiceField(
                controller: _profile,
                label: 'Default Profile *',
                options: _profiles,
                allowCustom: false,
                loading: _loading,
              ),
              const SizedBox(height: 7),
              _field(_serviceName, 'Service Name'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field(_maxMtu, 'Max MTU')),
                  const SizedBox(width: 7),
                  Expanded(child: _field(_maxMru, 'Max MRU')),
                ],
              ),
              const SizedBox(height: 7),
              _field(_mrru, 'MRRU'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field(_keepalive, 'Keepalive Timeout')),
                  const SizedBox(width: 7),
                  Expanded(child: _field(_maxSessions, 'Max Sessions')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field(_padoDelay, 'PADO Delay')),
                  const SizedBox(width: 7),
                  Expanded(
                    child: RouterChoiceField(
                      controller: _acceptEmpty,
                      label: 'Accept Empty Service',
                      options: const ['yes', 'no'],
                      allowCustom: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              RouterChoiceField(
                controller: _authentication,
                label: 'Authentication',
                options: const ['pap', 'chap', 'mschap1', 'mschap2'],
                multiSelect: true,
              ),
              const SizedBox(height: 7),
              RouterChoiceField(
                controller: _oneSession,
                label: 'One Session Per Host',
                options: const ['yes', 'no'],
                allowCustom: false,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_editing ? 'Simpan perubahan' : 'Tambahkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(labelText: label),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }
}
