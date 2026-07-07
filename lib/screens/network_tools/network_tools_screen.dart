import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';
import 'firewall_rule_sheet.dart';

class NetworkToolsScreen extends StatefulWidget {
  final MikrotikApi api;

  const NetworkToolsScreen({super.key, required this.api});

  @override
  State<NetworkToolsScreen> createState() => _NetworkToolsScreenState();
}

class _NetworkToolsScreenState extends State<NetworkToolsScreen> {
  static const _categories = [
    _FirewallCategory(
      'FILTER',
      'Filter',
      '/ip/firewall/filter',
      Icons.filter_alt_outlined,
    ),
    _FirewallCategory(
      'NAT',
      'NAT',
      '/ip/firewall/nat',
      Icons.swap_horiz_rounded,
    ),
    _FirewallCategory(
      'MANGLE',
      'Mangle',
      '/ip/firewall/mangle',
      Icons.tune_rounded,
    ),
    _FirewallCategory('RAW', 'Raw', '/ip/firewall/raw', Icons.bolt_rounded),
    _FirewallCategory(
      'ADDRESS LIST',
      'Address List',
      '/ip/firewall/address-list',
      Icons.format_list_bulleted_rounded,
    ),
    _FirewallCategory(
      'CONNECTION',
      'Connections',
      '/ip/firewall/connection',
      Icons.device_hub_rounded,
      readOnly: true,
    ),
  ];

  int _selected = 0;
  bool _loading = true;
  bool _fetching = false;
  String _search = '';
  List<Map<String, String>> _rows = [];

  _FirewallCategory get _category => _categories[_selected];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    _fetching = true;
    if (_rows.isEmpty && mounted) setState(() => _loading = true);
    final rows = await widget.api.query(['${_category.endpoint}/print']);
    if (mounted) {
      setState(() {
        _rows = rows;
        _loading = false;
      });
    }
    _fetching = false;
  }

  List<Map<String, String>> get _visible {
    final query = _search.toLowerCase().trim();
    if (query.isEmpty) return _rows;
    return _rows.where((row) {
      return row.entries.any(
        (entry) =>
            entry.key.toLowerCase().contains(query) ||
            entry.value.toLowerCase().contains(query),
      );
    }).toList();
  }

  int get _disabled => _rows.where((row) => row['disabled'] == 'true').length;

  void _selectCategory(int index) {
    if (_selected == index) return;
    setState(() {
      _selected = index;
      _rows = [];
      _search = '';
      _loading = true;
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    return Column(
      children: [
        _categoryBar(c),
        _toolbar(c),
        Expanded(child: _content(c)),
      ],
    );
  }

  Widget _categoryBar(AppC c) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final category = _categories[index];
          final active = index == _selected;
          return Material(
            color: active ? AppColors.cyan.withValues(alpha: 0.14) : c.card,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => _selectCategory(index),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: active ? AppColors.cyan : c.border),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Icon(
                      category.icon,
                      size: 15,
                      color: active ? AppColors.cyan : c.sub,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      category.label,
                      style: TextStyle(
                        color: active ? AppColors.cyan : c.txt,
                        fontSize: 10,
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _toolbar(AppC c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Text(
                  '${_rows.length}',
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_disabled > 0) ...[
                  const SizedBox(width: 5),
                  Text(
                    '($_disabled off)',
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 8,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                style: TextStyle(color: c.txt, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Cari ${_category.label}...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: c.sub,
                    size: 17,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
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
          if (!_category.readOnly)
            IconButton.filled(
              tooltip: 'Tambah ${_category.label}',
              visualDensity: VisualDensity.compact,
              onPressed: _showAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _content(AppC c) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 7,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: SkeletonBox(height: 58, radius: 9),
        ),
      );
    }
    final rows = _visible;
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data ${_category.label}',
          style: TextStyle(color: c.sub, fontSize: 11),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.cyan,
      onRefresh: _fetch,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: rows.length,
        itemBuilder: (_, index) => _ruleCard(rows[index], index, c),
      ),
    );
  }

  Widget _ruleCard(Map<String, String> row, int index, AppC c) {
    final disabled = row['disabled'] == 'true';
    final invalid = row['invalid'] == 'true';
    final dynamic = row['dynamic'] == 'true';
    final color = invalid
        ? AppColors.red
        : disabled
        ? c.sub
        : AppColors.green;
    final summary = _summary(row);
    final comment = row['comment']?.trim() ?? '';
    final counters = _parts([
      _formatCounter(row['packets'], 'pkt'),
      _formatBytes(row['bytes']),
    ]);
    return InkWell(
      onTap: () => _showDetails(row, c),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(9, 7, 5, 7),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 8, 5),
                child: Row(
                  children: [
                    const Text(
                      ';;;',
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        comment,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.txt,
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.sub, fontSize: 9),
                  ),
                ),
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              summary.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: disabled ? c.sub : c.txt,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (dynamic) _tag('D', AppColors.cyan),
                          if (invalid) _tag('I', AppColors.red),
                          if (disabled) _tag('X', c.sub),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.sub, fontSize: 9),
                      ),
                      if (counters != 'tanpa detail')
                        Text(
                          counters,
                          style: TextStyle(
                            color: c.sub.withValues(alpha: 0.75),
                            fontSize: 8,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!_category.readOnly && !dynamic)
                  PopupMenuButton<String>(
                    iconSize: 17,
                    padding: EdgeInsets.zero,
                    tooltip: 'Aksi',
                    onSelected: (action) => _action(action, row),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicate'),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(disabled ? 'Enable' : 'Disable'),
                      ),
                      if (_category.key != 'ADDRESS LIST')
                        const PopupMenuItem(
                          value: 'reset',
                          child: Text('Reset Counter'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Hapus'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, String) _summary(Map<String, String> row) {
    if (_category.key == 'ADDRESS LIST') {
      return (
        '${row['list'] ?? '-'}  |  ${row['address'] ?? '-'}',
        _parts([row['timeout'], row['comment']]),
      );
    }
    if (_category.key == 'CONNECTION') {
      final source = '${row['src-address'] ?? '-'}:${row['src-port'] ?? ''}';
      final destination =
          '${row['dst-address'] ?? '-'}:${row['dst-port'] ?? ''}';
      return (
        '$source  >  $destination',
        _parts([row['protocol'], row['connection-state'], row['timeout']]),
      );
    }
    final chain = row['chain'] ?? '-';
    final action = row['action'] ?? '-';
    final source =
        row['src-address'] ?? row['src-address-list'] ?? row['in-interface'];
    final destination =
        row['dst-address'] ?? row['dst-address-list'] ?? row['out-interface'];
    return (
      '$chain  >  $action',
      _parts([
        row['protocol'],
        source == null ? null : 'src $source',
        destination == null ? null : 'dst $destination',
        row['comment'],
      ]),
    );
  }

  String _parts(List<String?> values) {
    final parts = values.whereType<String>().where((value) => value.isNotEmpty);
    return parts.isEmpty ? 'tanpa detail' : parts.join('  |  ');
  }

  String? _formatCounter(String? value, String suffix) {
    if (value == null || value.isEmpty) return null;
    return '$value $suffix';
  }

  String? _formatBytes(String? value) {
    final bytes = int.tryParse(value ?? '');
    if (bytes == null) return null;
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  Widget _tag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showAdd() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          FirewallRuleSheet(api: widget.api, section: _category.key),
    );
    if (changed == true) _fetch();
  }

  Future<void> _action(String action, Map<String, String> row) async {
    try {
      if (action == 'edit') {
        final changed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => FirewallRuleSheet(
            api: widget.api,
            section: _category.key,
            rule: row,
          ),
        );
        if (changed == true) _fetch();
        return;
      }
      final id = row['.id'];
      if (id == null) return;
      if (action == 'duplicate') {
        await _duplicate(row);
      } else if (action == 'reset') {
        await widget.api.queryOrThrow([
          '${_category.endpoint}/reset-counters',
          '=.id=$id',
        ]);
      } else if (action == 'toggle') {
        final disabled = row['disabled'] == 'true';
        await widget.api.queryOrThrow([
          '${_category.endpoint}/${disabled ? 'enable' : 'disable'}',
          '=.id=$id',
        ]);
      } else if (action == 'delete' && await _confirmDelete(row)) {
        await widget.api.queryOrThrow([
          '${_category.endpoint}/remove',
          '=.id=$id',
        ]);
      } else {
        return;
      }
      await _fetch();
    } catch (error) {
      _snack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _duplicate(Map<String, String> row) async {
    const ruleFields = {
      'chain',
      'action',
      'protocol',
      'src-address',
      'dst-address',
      'src-port',
      'dst-port',
      'in-interface',
      'out-interface',
      'in-interface-list',
      'out-interface-list',
      'src-address-list',
      'dst-address-list',
      'src-address-type',
      'dst-address-type',
      'src-mac-address',
      'connection-state',
      'connection-nat-state',
      'connection-type',
      'ipsec-policy',
      'hotspot',
      'fragment',
      'connection-mark',
      'packet-mark',
      'routing-mark',
      'tcp-flags',
      'icmp-options',
      'connection-limit',
      'dst-limit',
      'layer7-protocol',
      'content',
      'time',
      'days',
      'to-addresses',
      'to-ports',
      'jump-target',
      'reject-with',
      'new-connection-mark',
      'new-packet-mark',
      'new-routing-mark',
      'passthrough',
      'log',
      'log-prefix',
      'limit',
      'comment',
    };
    const addressFields = {'list', 'address', 'timeout', 'comment'};
    final allowed = _category.key == 'ADDRESS LIST'
        ? addressFields
        : ruleFields;
    final command = <String>['${_category.endpoint}/add'];
    for (final entry in row.entries) {
      if (!allowed.contains(entry.key) || entry.value.isEmpty) {
        continue;
      }
      command.add('=${entry.key}=${entry.value}');
    }
    await widget.api.queryOrThrow(command);
  }

  void _showDetails(Map<String, String> row, AppC c) {
    final entries = row.entries.where((entry) => entry.value.isNotEmpty);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.58,
          maxChildSize: 0.9,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              Text(
                _category.label,
                style: TextStyle(
                  color: c.txt,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 115,
                        child: Text(
                          entry.key,
                          style: TextStyle(color: c.sub, fontSize: 9),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          entry.value,
                          style: TextStyle(color: c.txt, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(Map<String, String> row) async {
    final c = AppC(context.read<AppProvider>().isDark);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: c.card,
            title: Text(
              'Hapus ${_category.label}',
              style: TextStyle(color: c.txt),
            ),
            content: Text(_summary(row).$1, style: TextStyle(color: c.sub)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }
}

class _FirewallCategory {
  final String key;
  final String label;
  final String endpoint;
  final IconData icon;
  final bool readOnly;

  const _FirewallCategory(
    this.key,
    this.label,
    this.endpoint,
    this.icon, {
    this.readOnly = false,
  });
}
