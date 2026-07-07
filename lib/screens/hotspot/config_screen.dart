import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/router_choice_field.dart';
import '../../widgets/skeleton.dart';

enum HotspotConfigType { server, serverProfile, userProfile }

class HotspotConfigScreen extends StatefulWidget {
  final MikrotikApi api;
  final HotspotConfigType type;

  const HotspotConfigScreen({super.key, required this.api, required this.type});

  @override
  State<HotspotConfigScreen> createState() => _HotspotConfigScreenState();
}

class _HotspotConfigScreenState extends State<HotspotConfigScreen> {
  List<Map<String, String>> _rows = [];
  bool _loading = true;

  String get _endpoint => switch (widget.type) {
    HotspotConfigType.server => '/ip/hotspot',
    HotspotConfigType.serverProfile => '/ip/hotspot/profile',
    HotspotConfigType.userProfile => '/ip/hotspot/user/profile',
  };

  String get _label => switch (widget.type) {
    HotspotConfigType.server => 'Hotspot Server',
    HotspotConfigType.serverProfile => 'Server Profile',
    HotspotConfigType.userProfile => 'User Profile',
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await widget.api.query(['$_endpoint/print']);
      if (mounted) setState(() => _rows = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, String>? row]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _HotspotEditor(api: widget.api, type: widget.type, row: row),
    );
    if (changed == true) _fetch();
  }

  Future<void> _delete(Map<String, String> row) async {
    final id = row['.id'];
    if (id == null || row['name'] == 'default') return;
    await widget.api.queryOrThrow(['$_endpoint/remove', '=.id=$id']);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                '${_rows.length} $_label',
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
                onPressed: () => _edit(),
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
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _rows.length,
                  itemBuilder: (_, index) {
                    final row = _rows[index];
                    final values = switch (widget.type) {
                      HotspotConfigType.server => [
                        row['interface'],
                        row['address-pool'],
                        row['profile'],
                      ],
                      HotspotConfigType.serverProfile => [
                        row['dns-name'],
                        row['html-directory'],
                        row['rate-limit'],
                      ],
                      HotspotConfigType.userProfile => [
                        row['address-pool'],
                        row['shared-users'],
                        row['rate-limit'],
                      ],
                    };
                    return ListTile(
                      tileColor: c.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: c.border),
                      ),
                      title: Text(
                        row['name'] ?? '-',
                        style: TextStyle(
                          color: c.txt,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        values
                            .whereType<String>()
                            .where((v) => v.isNotEmpty)
                            .join('  |  '),
                        style: TextStyle(color: c.sub, fontSize: 10),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _edit(row);
                          if (value == 'delete') _delete(row);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          if (row['name'] != 'default')
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
      ],
    );
  }
}

class _HotspotEditor extends StatefulWidget {
  final MikrotikApi api;
  final HotspotConfigType type;
  final Map<String, String>? row;

  const _HotspotEditor({required this.api, required this.type, this.row});

  @override
  State<_HotspotEditor> createState() => _HotspotEditorState();
}

class _HotspotEditorState extends State<_HotspotEditor> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<String>> _options = {};
  bool _loading = true;
  bool _saving = false;

  Map<String, String> get _labels => switch (widget.type) {
    HotspotConfigType.server => {
      'name': 'Name *',
      'interface': 'Interface *',
      'address-pool': 'Address Pool',
      'profile': 'Profile',
      'idle-timeout': 'Idle Timeout',
      'keepalive-timeout': 'Keepalive Timeout',
      'login-timeout': 'Login Timeout',
      'addresses-per-mac': 'Addresses Per MAC',
      'comment': 'Comment',
    },
    HotspotConfigType.serverProfile => {
      'name': 'Name *',
      'hotspot-address': 'Hotspot Address',
      'dns-name': 'DNS Name',
      'html-directory': 'HTML Directory',
      'rate-limit': 'Rate Limit (rx/tx)',
      'login-by': 'Login By',
      'http-cookie-lifetime': 'HTTP Cookie Lifetime',
      'ssl-certificate': 'SSL Certificate',
      'smtp-server': 'SMTP Server',
      'split-user-domain': 'Split User Domain',
      'use-radius': 'Use RADIUS',
    },
    HotspotConfigType.userProfile => {
      'name': 'Name *',
      'address-pool': 'Address Pool',
      'session-timeout': 'Session Timeout',
      'idle-timeout': 'Idle Timeout',
      'keepalive-timeout': 'Keepalive Timeout',
      'status-autorefresh': 'Status Autorefresh',
      'shared-users': 'Shared Users',
      'rate-limit': 'Rate Limit (rx/tx)',
      'add-mac-cookie': 'Add MAC Cookie',
      'mac-cookie-timeout': 'MAC Cookie Timeout',
      'address-list': 'Address List',
      'incoming-filter': 'Incoming Filter',
      'outgoing-filter': 'Outgoing Filter',
      'incoming-packet-mark': 'Incoming Packet Mark',
      'outgoing-packet-mark': 'Outgoing Packet Mark',
      'open-status-page': 'Open Status Page',
      'transparent-proxy': 'Transparent Proxy',
      'on-login': 'On Login',
      'on-logout': 'On Logout',
    },
  };

  String get _endpoint => switch (widget.type) {
    HotspotConfigType.server => '/ip/hotspot',
    HotspotConfigType.serverProfile => '/ip/hotspot/profile',
    HotspotConfigType.userProfile => '/ip/hotspot/user/profile',
  };

  @override
  void initState() {
    super.initState();
    for (final entry in _labels.entries) {
      _controllers[entry.key] = TextEditingController(
        text: widget.row?[entry.key] ?? '',
      );
    }
    _load();
  }

  Future<void> _load() async {
    final commands = [
      ['/interface/print'],
      ['/ip/pool/print'],
      ['/ip/hotspot/profile/print'],
      ['/ip/firewall/filter/print'],
      ['/ip/firewall/mangle/print'],
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
      _options['interface'] = _values(results[0], 'name');
      _options['pool'] = _values(results[1], 'name');
      _options['profile'] = _values(results[2], 'name');
      _options['filter'] = _values(results[3], 'chain');
      _options['mark'] = {
        ..._values(results[4], 'packet-mark'),
        ..._values(results[4], 'new-packet-mark'),
      }.toList();
      _loading = false;
    });
  }

  List<String> _values(List<Map<String, String>> rows, String key) => rows
      .map((row) => row[key])
      .whereType<String>()
      .where((v) => v.isNotEmpty)
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
    if (key == 'interface') return _options['interface'] ?? const [];
    if (key == 'address-pool') return ['none', ...?_options['pool']];
    if (key == 'profile') return _options['profile'] ?? const [];
    if (key == 'incoming-filter' || key == 'outgoing-filter') {
      return _options['filter'] ?? const [];
    }
    if (key.contains('packet-mark')) return _options['mark'] ?? const [];
    if ({
      'add-mac-cookie',
      'transparent-proxy',
      'split-user-domain',
      'use-radius',
    }.contains(key)) {
      return const ['yes', 'no'];
    }
    if (key == 'open-status-page') return const ['always', 'http-login'];
    if (key == 'login-by') {
      return const [
        'cookie',
        'http-chap',
        'http-pap',
        'https',
        'mac',
        'mac-cookie',
        'trial',
      ];
    }
    return const [];
  }

  Future<void> _save() async {
    if (_controllers['name']!.text.trim().isEmpty) {
      _message('Name wajib diisi');
      return;
    }
    setState(() => _saving = true);
    final editing = widget.row != null;
    final command = <String>[
      '$_endpoint/${editing ? 'set' : 'add'}',
      if (editing) '=.id=${widget.row!['.id']}',
    ];
    for (final key in _labels.keys) {
      final value = _controllers[key]!.text.trim();
      final original = widget.row?[key] ?? '';
      if (editing) {
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
              ..._labels.entries.map((entry) {
                final options = _fieldOptions(entry.key);
                final scripts =
                    entry.key == 'on-login' || entry.key == 'on-logout';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: options.isEmpty
                      ? TextField(
                          controller: _controllers[entry.key],
                          minLines: scripts ? 3 : 1,
                          maxLines: scripts ? 7 : 1,
                          decoration: InputDecoration(labelText: entry.value),
                        )
                      : RouterChoiceField(
                          controller: _controllers[entry.key]!,
                          label: entry.value,
                          options: options,
                          multiSelect: entry.key == 'login-by',
                          loading: _loading,
                        ),
                );
              }),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Simpan'),
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
