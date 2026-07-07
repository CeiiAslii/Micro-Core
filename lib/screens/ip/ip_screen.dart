import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/router_choice_field.dart';

class IpScreen extends StatefulWidget {
  final MikrotikApi api;
  final int subIndex;

  const IpScreen({super.key, required this.api, required this.subIndex});

  @override
  State<IpScreen> createState() => _IpScreenState();
}

class _IpScreenState extends State<IpScreen> {
  List<Map<String, String>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(IpScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subIndex != widget.subIndex) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _data = [];
    });
    try {
      List<Map<String, String>> r = [];
      switch (widget.subIndex) {
        case 0:
          r = await widget.api.query(['/ip/address/print']);
          break;
        case 1:
          r = await widget.api.query(['/ip/pool/print']);
          break;
        case 2:
          r = await widget.api.query(['/ip/dhcp-server/print']);
          break;
        case 3:
          // Ambil semua lease, filter bound di UI
          r = await widget.api.query(['/ip/dhcp-server/lease/print']);
          // Sort: bound dulu
          r.sort((a, b) {
            final aStatus = a['status'] ?? '';
            final bStatus = b['status'] ?? '';
            if (aStatus == 'bound' && bStatus != 'bound') return -1;
            if (aStatus != 'bound' && bStatus == 'bound') return 1;
            return 0;
          });
          break;
        case 4:
          r = await widget.api.query(['/ip/dns/print']);
          break;
      }
      if (mounted) {
        setState(() {
          _data = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _title() {
    switch (widget.subIndex) {
      case 0:
        return 'IP Address';
      case 1:
        return 'IP Pool';
      case 2:
        return 'DHCP Server';
      case 3:
        return 'DHCP Lease';
      case 4:
        return 'DNS Settings';
      default:
        return 'IP';
    }
  }

  Color _color() {
    switch (widget.subIndex) {
      case 0:
        return AppColors.cyan;
      case 1:
        return AppColors.green;
      case 2:
        return AppColors.orange;
      case 3:
        return AppColors.blue;
      case 4:
        return AppColors.purple;
      default:
        return AppColors.cyan;
    }
  }

  IconData _icon() {
    switch (widget.subIndex) {
      case 0:
        return Icons.grid_view_rounded;
      case 1:
        return Icons.pool_rounded;
      case 2:
        return Icons.router_rounded;
      case 3:
        return Icons.devices_rounded;
      case 4:
        return Icons.dns_rounded;
      default:
        return Icons.lan_rounded;
    }
  }

  Widget _buildItem(Map<String, String> item, AppC c) {
    final color = _color();
    switch (widget.subIndex) {
      case 0: // IP Address
        return _card(c, color, [
          _row('Address', item['address'] ?? '-', c),
          _row('Interface', item['interface'] ?? '-', c),
          _row('Network', item['network'] ?? '-', c),
          if ((item['comment'] ?? '').isNotEmpty)
            _row('Comment', item['comment'] ?? '', c),
        ]);

      case 1: // IP Pool
        return _card(c, color, [
          _row('Nama', item['name'] ?? '-', c),
          _row('Ranges', item['ranges'] ?? '-', c),
          if ((item['next-pool'] ?? '').isNotEmpty)
            _row('Next Pool', item['next-pool'] ?? '-', c),
        ]);

      case 2: // DHCP Server
        final disabled = item['disabled'] == 'true';
        return _card(c, disabled ? AppColors.red : color, [
          _row('Nama', item['name'] ?? '-', c),
          _row('Interface', item['interface'] ?? '-', c),
          _row('Pool', item['address-pool'] ?? '-', c),
          _row(
            'Status',
            disabled ? 'DISABLED' : 'AKTIF',
            c,
            valueColor: disabled ? AppColors.red : AppColors.green,
          ),
        ]);

      case 3: // DHCP Lease
        final status = item['status'] ?? '-';
        final dynamic_ = item['dynamic'] == 'true';
        final hostname = item['host-name'] ?? '';
        final mac = item['mac-address'] ?? '-';
        final ip = item['address'] ?? '-';

        // Warna berdasarkan status
        Color statusColor;
        switch (status) {
          case 'bound':
            statusColor = AppColors.green;
            break;
          case 'waiting':
            statusColor = AppColors.orange;
            break;
          case 'expired':
            statusColor = AppColors.red;
            break;
          default:
            statusColor = c.sub;
        }

        return _card(c, _color(), [
          _row('IP', ip, c),
          _row('MAC', mac, c),
          if (hostname.isNotEmpty) _row('Hostname', hostname, c),
          _row('Status', status.toUpperCase(), c, valueColor: statusColor),
          _row(
            'Type',
            dynamic_ ? 'Dynamic' : 'Static',
            c,
            valueColor: dynamic_ ? AppColors.orange : AppColors.cyan,
          ),
          if ((item['expires-after'] ?? '').isNotEmpty)
            _row('Expires', item['expires-after'] ?? '-', c),
        ]);
      case 4:
        return _card(c, color, [
          _row('Servers', item['servers'] ?? '-', c),
          _row(
            'Remote Requests',
            item['allow-remote-requests'] == 'true' ? 'YES' : 'NO',
            c,
          ),
          _row('Cache Size', item['cache-size'] ?? '-', c),
          _row('Cache Used', item['cache-used'] ?? '-', c),
        ]);

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);
    final color = _color();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(),
                      style: TextStyle(
                        color: c.txt,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_data.length} data',
                      style: TextStyle(color: c.sub, fontSize: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _fetch,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.refresh_rounded, color: color, size: 18),
                ),
              ),
              if (widget.subIndex != 3) ...[
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: widget.subIndex == 4 ? 'Edit DNS' : 'Tambah',
                  onPressed: () => _openEditor(
                    widget.subIndex == 4 && _data.isNotEmpty
                        ? _data.first
                        : null,
                  ),
                  icon: Icon(
                    widget.subIndex == 4
                        ? Icons.edit_rounded
                        : Icons.add_rounded,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SkeletonBox(height: 90, radius: 12),
                  ),
                )
              : _data.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icon(), color: c.sub, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada data',
                        style: TextStyle(color: c.sub, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: color,
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _data.length,
                    itemBuilder: (_, i) => InkWell(
                      onLongPress: widget.subIndex == 3 || widget.subIndex == 4
                          ? null
                          : () => _delete(_data[i]),
                      onTap: widget.subIndex == 3
                          ? null
                          : () => _openEditor(_data[i]),
                      child: _buildItem(_data[i], c),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _card(AppC c, Color color, List<Widget> rows) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(children: rows),
  );

  Widget _row(String label, String value, AppC c, {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label, style: TextStyle(color: c.sub, fontSize: 12)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? c.txt,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Future<void> _openEditor([Map<String, String>? row]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _IpConfigEditor(api: widget.api, type: widget.subIndex, row: row),
    );
    if (changed == true) _fetch();
  }

  Future<void> _delete(Map<String, String> row) async {
    final id = row['.id'];
    if (id == null) return;
    final endpoint = switch (widget.subIndex) {
      0 => '/ip/address',
      1 => '/ip/pool',
      2 => '/ip/dhcp-server',
      _ => '',
    };
    if (endpoint.isEmpty) return;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Hapus konfigurasi'),
            content: const Text('Konfigurasi ini akan dihapus dari router.'),
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
    if (!ok) return;
    await widget.api.queryOrThrow(['$endpoint/remove', '=.id=$id']);
    _fetch();
  }
}

class _IpConfigEditor extends StatefulWidget {
  final MikrotikApi api;
  final int type;
  final Map<String, String>? row;

  const _IpConfigEditor({required this.api, required this.type, this.row});

  @override
  State<_IpConfigEditor> createState() => _IpConfigEditorState();
}

class _IpConfigEditorState extends State<_IpConfigEditor> {
  final Map<String, TextEditingController> _controllers = {};
  List<String> _interfaces = [];
  List<String> _pools = [];
  bool _loading = true;
  bool _saving = false;

  Map<String, String> get _labels => switch (widget.type) {
    0 => {
      'address': 'Address *',
      'network': 'Network',
      'interface': 'Interface *',
      'comment': 'Comment',
    },
    1 => {
      'name': 'Name *',
      'ranges': 'Addresses *',
      'next-pool': 'Next Pool',
      'comment': 'Comment',
    },
    2 => {
      'name': 'Name *',
      'interface': 'Interface *',
      'relay': 'Relay',
      'lease-time': 'Lease Time',
      'address-pool': 'Address Pool',
      'add-arp': 'Add ARP',
      'authoritative': 'Authoritative',
      'comment': 'Comment',
    },
    _ => {
      'servers': 'Servers',
      'use-doh-server': 'Use DoH Server',
      'allow-remote-requests': 'Allow Remote Requests',
      'vrf': 'VRF',
      'max-udp-packet-size': 'Max UDP Packet Size',
      'query-server-timeout': 'Query Server Timeout',
      'query-total-timeout': 'Query Total Timeout',
      'max-concurrent-queries': 'Max Concurrent Queries',
      'max-concurrent-tcp-sessions': 'Max Concurrent TCP Sessions',
      'cache-size': 'Cache Size',
      'cache-max-ttl': 'Cache Max TTL',
    },
  };

  bool get _editing => widget.row != null;

  @override
  void initState() {
    super.initState();
    for (final entry in _labels.entries) {
      _controllers[entry.key] = TextEditingController(
        text: widget.row?[entry.key] ?? '',
      );
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final results = await Future.wait([
      widget.api.query(['/interface/print']),
      widget.api.query(['/ip/pool/print']),
    ]);
    if (!mounted) return;
    setState(() {
      _interfaces = results[0]
          .map((r) => r['name'])
          .whereType<String>()
          .toList();
      _pools = results[1].map((r) => r['name']).whereType<String>().toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _options(String key) {
    if (key == 'interface') return _interfaces;
    if (key == 'address-pool') return ['static-only', ..._pools];
    if (key == 'next-pool') return ['none', ..._pools];
    if (key == 'add-arp' || key == 'allow-remote-requests') {
      return const ['yes', 'no'];
    }
    if (key == 'authoritative') {
      return const ['yes', 'no', 'after-2sec-delay', 'after-10sec-delay'];
    }
    return const [];
  }

  Future<void> _save() async {
    final required = switch (widget.type) {
      0 => ['address', 'interface'],
      1 => ['name', 'ranges'],
      2 => ['name', 'interface'],
      _ => <String>[],
    };
    if (required.any((key) => _controllers[key]!.text.trim().isEmpty)) {
      _message('Field wajib belum lengkap');
      return;
    }
    setState(() => _saving = true);
    final endpoint = switch (widget.type) {
      0 => '/ip/address',
      1 => '/ip/pool',
      2 => '/ip/dhcp-server',
      _ => '/ip/dns',
    };
    final singleton = widget.type == 4;
    final command = <String>[
      '$endpoint/${singleton ? 'set' : (_editing ? 'set' : 'add')}',
      if (_editing && !singleton) '=.id=${widget.row!['.id']}',
    ];
    for (final key in _labels.keys) {
      final value = _controllers[key]!.text.trim();
      final original = widget.row?[key] ?? '';
      if (singleton || _editing) {
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
                final options = _options(entry.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: options.isEmpty
                      ? TextField(
                          controller: _controllers[entry.key],
                          decoration: InputDecoration(labelText: entry.value),
                        )
                      : RouterChoiceField(
                          controller: _controllers[entry.key]!,
                          label: entry.value,
                          options: options,
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

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), backgroundColor: AppColors.red),
    );
  }
}
