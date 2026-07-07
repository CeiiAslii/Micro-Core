import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/router_choice_field.dart';
import '../../widgets/skeleton.dart';

class PppoeProfileScreen extends StatefulWidget {
  final MikrotikApi api;

  const PppoeProfileScreen({super.key, required this.api});

  @override
  State<PppoeProfileScreen> createState() => _PppoeProfileScreenState();
}

class _PppoeProfileScreenState extends State<PppoeProfileScreen> {
  List<Map<String, String>> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await widget.api.query(['/ppp/profile/print']);
      if (mounted) setState(() => _profiles = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([Map<String, String>? row]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PppProfileEditor(api: widget.api, row: row),
    );
    if (changed == true) _fetch();
  }

  Future<void> _delete(Map<String, String> row) async {
    final id = row['.id'];
    final name = row['name'] ?? '';
    if (id == null || name == 'default' || name == 'default-encryption') return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Hapus PPP Profile'),
            content: Text('Hapus profile "$name"?'),
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
    await widget.api.queryOrThrow(['/ppp/profile/remove', '=.id=$id']);
    await _fetch();
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
                '${_profiles.length} profile',
                style: TextStyle(
                  color: c.txt,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton.filled(
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
                    child: SkeletonBox(height: 62, radius: 10),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _profiles.length,
                    itemBuilder: (_, index) {
                      final row = _profiles[index];
                      final name = row['name'] ?? '-';
                      final builtIn =
                          name == 'default' || name == 'default-encryption';
                      final details =
                          [
                                row['local-address'],
                                row['remote-address'],
                                row['rate-limit'],
                              ]
                              .whereType<String>()
                              .where((v) => v.isNotEmpty)
                              .join('  |  ');
                      return ListTile(
                        tileColor: c.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: c.border),
                        ),
                        contentPadding: const EdgeInsets.only(left: 12),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: c.txt,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          details.isEmpty ? 'default' : details,
                          style: TextStyle(color: c.sub, fontSize: 10),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'edit') _openEditor(row);
                            if (action == 'delete') _delete(row);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            if (!builtIn)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Hapus'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _PppProfileEditor extends StatefulWidget {
  final MikrotikApi api;
  final Map<String, String>? row;

  const _PppProfileEditor({required this.api, this.row});

  @override
  State<_PppProfileEditor> createState() => _PppProfileEditorState();
}

class _PppProfileEditorState extends State<_PppProfileEditor> {
  static const _fields = <String, String>{
    'name': 'Name',
    'local-address': 'Local Address',
    'remote-address': 'Remote Address / Pool',
    'remote-ipv6-prefix-pool': 'Remote IPv6 Prefix Pool',
    'dhcpv6-pd-pool': 'DHCPv6 PD Pool',
    'bridge': 'Bridge',
    'bridge-port-priority': 'Bridge Port Priority',
    'bridge-path-cost': 'Bridge Path Cost',
    'bridge-horizon': 'Bridge Horizon',
    'bridge-learning': 'Bridge Learning',
    'incoming-filter': 'Incoming Filter',
    'outgoing-filter': 'Outgoing Filter',
    'address-list': 'Address List',
    'interface-list': 'Interface List',
    'dns-server': 'DNS Server',
    'wins-server': 'WINS Server',
    'change-tcp-mss': 'Change TCP MSS',
    'use-upnp': 'Use UPnP',
    'use-ipv6': 'Use IPv6',
    'use-mpls': 'Use MPLS',
    'use-compression': 'Use Compression',
    'use-encryption': 'Use Encryption',
    'session-timeout': 'Session Timeout',
    'idle-timeout': 'Idle Timeout',
    'rate-limit': 'Rate Limit (rx/tx)',
    'only-one': 'Only One',
    'insert-queue-before': 'Insert Queue Before',
    'parent-queue': 'Parent Queue',
    'queue-type': 'Queue Type',
    'on-up': 'On Up',
    'on-down': 'On Down',
  };

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<String>> _options = {};
  int _tab = 0;
  bool _loading = true;
  bool _saving = false;

  bool get _editing => widget.row != null;

  @override
  void initState() {
    super.initState();
    for (final entry in _fields.entries) {
      _controllers[entry.key] = TextEditingController(
        text: widget.row?[entry.key] ?? '',
      );
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final commands = [
      ['/ip/pool/print'],
      ['/interface/bridge/print'],
      ['/interface/list/print'],
      ['/queue/simple/print'],
      ['/queue/type/print'],
    ];
    final results = await Future.wait(
      commands.map((command) async {
        try {
          return await widget.api.query(command);
        } catch (_) {
          return <Map<String, String>>[];
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _options['pool'] = _values(results[0], 'name');
      _options['bridge'] = _values(results[1], 'name');
      _options['interface-list'] = _values(results[2], 'name');
      _options['queue'] = _values(results[3], 'name');
      _options['queue-type'] = _values(results[4], 'name');
      _loading = false;
    });
  }

  List<String> _values(List<Map<String, String>> rows, String key) => rows
      .map((row) => row[key])
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _fieldOptions(String key) {
    if (key == 'remote-address') {
      return _options['pool'] ?? const [];
    }
    if (key == 'bridge') return ['none', ...?_options['bridge']];
    if (key == 'interface-list') {
      return ['none', ...?_options['interface-list']];
    }
    if (key == 'insert-queue-before' || key == 'parent-queue') {
      return ['first', 'bottom', 'none', ...?_options['queue']];
    }
    if (key == 'queue-type') return _options['queue-type'] ?? const [];
    if (key.startsWith('use-')) {
      return const ['no', 'yes', 'required', 'default'];
    }
    if (key == 'change-tcp-mss' || key == 'only-one') {
      return const ['no', 'yes', 'default'];
    }
    if (key == 'bridge-learning') return const ['no', 'yes', 'default'];
    return const [];
  }

  List<String> get _tabKeys => switch (_tab) {
    0 => _fields.keys.take(17).toList(),
    1 => ['use-ipv6', 'use-mpls', 'use-compression', 'use-encryption'],
    2 => ['session-timeout', 'idle-timeout', 'rate-limit', 'only-one'],
    3 => ['insert-queue-before', 'parent-queue', 'queue-type'],
    _ => ['on-up', 'on-down'],
  };

  Future<void> _save() async {
    if (_controllers['name']!.text.trim().isEmpty) {
      _message('Name wajib diisi');
      return;
    }
    setState(() => _saving = true);
    final command = <String>[
      '/ppp/profile/${_editing ? 'set' : 'add'}',
      if (_editing) '=.id=${widget.row!['.id']}',
    ];
    for (final key in _fields.keys) {
      final value = _controllers[key]!.text.trim();
      final original = widget.row?[key] ?? '';
      if (_editing) {
        if (value != original) command.add('=$key=$value');
      } else if (value.isNotEmpty) {
        command.add('=$key=$value');
      }
    }
    try {
      await widget.api.queryOrThrow(command);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = ['General', 'Protocols', 'Limits', 'Queue', 'Scripts'];
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
            children: [
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.length,
                  itemBuilder: (_, index) => ChoiceChip(
                    label: Text(tabs[index]),
                    selected: _tab == index,
                    onSelected: (_) => setState(() => _tab = index),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._tabKeys.map((key) {
                final options = _fieldOptions(key);
                final multiline = key == 'on-up' || key == 'on-down';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: options.isNotEmpty
                      ? RouterChoiceField(
                          controller: _controllers[key]!,
                          label: _fields[key]!,
                          options: options,
                          loading: _loading,
                        )
                      : TextField(
                          controller: _controllers[key],
                          minLines: multiline ? 4 : 1,
                          maxLines: multiline ? 8 : 1,
                          decoration: InputDecoration(labelText: _fields[key]),
                        ),
                );
              }),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_editing ? 'Simpan perubahan' : 'Tambahkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }
}
