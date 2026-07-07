import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/router_choice_field.dart';

class FirewallRuleSheet extends StatefulWidget {
  final MikrotikApi api;
  final String? section;
  final Map<String, String>? rule;

  const FirewallRuleSheet({
    super.key,
    required this.api,
    this.section,
    this.rule,
  });

  @override
  State<FirewallRuleSheet> createState() => _FirewallRuleSheetState();
}

class _FirewallRuleSheetState extends State<FirewallRuleSheet> {
  late String _section;
  final Map<String, TextEditingController> _fields = {};
  final Map<String, List<String>> _dynamicOptions = {};
  bool _saving = false;
  bool _advanced = false;
  bool _loadingOptions = true;

  bool get _editing => widget.rule != null;
  bool get _addressList => _section == 'ADDRESS LIST';

  static const _ruleFields = [
    'chain',
    'action',
    'protocol',
    'src-address',
    'dst-address',
    'src-port',
    'dst-port',
    'any-port',
    'in-interface',
    'out-interface',
    'in-interface-list',
    'out-interface-list',
    'src-address-list',
    'dst-address-list',
    'src-address-type',
    'dst-address-type',
    'src-mac-address',
    'in-bridge-port',
    'out-bridge-port',
    'in-bridge-port-list',
    'out-bridge-port-list',
    'connection-state',
    'connection-nat-state',
    'connection-type',
    'connection-bytes',
    'connection-rate',
    'per-connection-classifier',
    'ipsec-policy',
    'hotspot',
    'fragment',
    'connection-mark',
    'packet-mark',
    'routing-mark',
    'tcp-flags',
    'icmp-options',
    'connection-limit',
    'limit',
    'dst-limit',
    'layer7-protocol',
    'content',
    'tls-host',
    'ingress-priority',
    'priority',
    'dscp',
    'tcp-mss',
    'packet-size',
    'random',
    'ipv4-options',
    'ttl',
    'nth',
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
    'comment',
  ];

  static const _addressFields = ['list', 'address', 'timeout', 'comment'];

  @override
  void initState() {
    super.initState();
    _section = widget.section ?? 'FILTER';
    final rule = widget.rule ?? const <String, String>{};
    for (final key in {..._ruleFields, ..._addressFields}) {
      _fields[key] = TextEditingController(text: rule[key] ?? '');
    }
    if (!_editing) _applyDefaults();
    _loadOptions();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key) => _fields[key]!;

  Future<void> _loadOptions() async {
    try {
      final commands = <List<String>>[
        ['/interface/print'],
        ['/interface/list/print'],
        ['/ip/firewall/address-list/print'],
        ['/routing/table/print'],
        ['/ip/firewall/layer7-protocol/print'],
        ['/ip/firewall/filter/print'],
        ['/ip/firewall/nat/print'],
        ['/ip/firewall/mangle/print'],
        ['/ip/firewall/raw/print'],
        ['/interface/bridge/port/print'],
      ];
      final results = await Future.wait(commands.map(_safeQuery));
      if (!mounted) return;
      setState(() {
        _dynamicOptions['interface'] = _values(results[0], 'name');
        _dynamicOptions['interface-list'] = _values(results[1], 'name');
        _dynamicOptions['address-list'] = _values(results[2], 'list');
        _dynamicOptions['routing-table'] = _values(results[3], 'name');
        _dynamicOptions['layer7'] = _values(results[4], 'name');
        final rules = [
          ...results[5],
          ...results[6],
          ...results[7],
          ...results[8],
        ];
        _dynamicOptions['chain'] = _values(rules, 'chain');
        _dynamicOptions['connection-mark'] = {
          ..._values(rules, 'connection-mark'),
          ..._values(rules, 'new-connection-mark'),
        }.toList();
        _dynamicOptions['packet-mark'] = {
          ..._values(rules, 'packet-mark'),
          ..._values(rules, 'new-packet-mark'),
        }.toList();
        _dynamicOptions['routing-mark'] = {
          ..._values(rules, 'routing-mark'),
          ..._values(rules, 'new-routing-mark'),
        }.toList();
        _dynamicOptions['bridge-port'] = _values(results[9], 'interface');
      });
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<List<Map<String, String>>> _safeQuery(List<String> command) async {
    try {
      return await widget.api.query(command);
    } catch (_) {
      return const [];
    }
  }

  List<String> _values(List<Map<String, String>> rows, String key) {
    return rows
        .map((row) => row[key])
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  String get _endpoint => switch (_section) {
    'NAT' => '/ip/firewall/nat',
    'MANGLE' => '/ip/firewall/mangle',
    'RAW' => '/ip/firewall/raw',
    'ADDRESS LIST' => '/ip/firewall/address-list',
    _ => '/ip/firewall/filter',
  };

  void _applyDefaults() {
    if (_addressList) return;
    switch (_section) {
      case 'NAT':
        _ctrl('chain').text = 'srcnat';
        _ctrl('action').text = 'masquerade';
      case 'MANGLE':
        _ctrl('chain').text = 'prerouting';
        _ctrl('action').text = 'mark-connection';
      case 'RAW':
        _ctrl('chain').text = 'prerouting';
        _ctrl('action').text = 'accept';
      default:
        _ctrl('chain').text = 'input';
        _ctrl('action').text = 'accept';
    }
  }

  void _changeSection(String? value) {
    if (value == null || _editing) return;
    setState(() {
      _section = value;
      _applyDefaults();
    });
  }

  List<String> _options(String key) {
    const yesNo = ['yes', 'no'];
    final sectionChains = switch (_section) {
      'NAT' => ['srcnat', 'dstnat'],
      'MANGLE' => ['prerouting', 'input', 'forward', 'output', 'postrouting'],
      'RAW' => ['prerouting', 'output'],
      _ => ['input', 'forward', 'output'],
    };
    final actions = switch (_section) {
      'NAT' => [
        'accept',
        'add-dst-to-address-list',
        'add-src-to-address-list',
        'dst-nat',
        'jump',
        'log',
        'masquerade',
        'netmap',
        'passthrough',
        'redirect',
        'return',
        'same',
        'src-nat',
      ],
      'MANGLE' => [
        'accept',
        'add-dst-to-address-list',
        'add-src-to-address-list',
        'change-dscp',
        'change-mss',
        'change-ttl',
        'clear-df',
        'fasttrack-connection',
        'jump',
        'log',
        'mark-connection',
        'mark-packet',
        'mark-routing',
        'passthrough',
        'return',
        'route',
        'set-priority',
        'sniff-pc',
        'sniff-tzsp',
        'strip-ipv4-options',
      ],
      'RAW' => [
        'accept',
        'add-dst-to-address-list',
        'add-src-to-address-list',
        'drop',
        'jump',
        'log',
        'notrack',
        'passthrough',
        'return',
      ],
      _ => [
        'accept',
        'add-dst-to-address-list',
        'add-src-to-address-list',
        'drop',
        'fasttrack-connection',
        'jump',
        'log',
        'passthrough',
        'reject',
        'return',
        'tarpit',
      ],
    };
    return switch (key) {
      'chain' => {...sectionChains, ...?_dynamicOptions['chain']}.toList(),
      'action' => actions,
      'protocol' => [
        'tcp',
        'udp',
        'icmp',
        'icmpv6',
        'gre',
        'esp',
        'ah',
        'ipsec-esp',
        'ipsec-ah',
        'sctp',
        'dccp',
        'igmp',
        'ipv6-encap',
        'all',
      ],
      'connection-state' => [
        'established',
        'related',
        'new',
        'invalid',
        'untracked',
      ],
      'connection-nat-state' => ['dstnat', 'srcnat'],
      'connection-type' => ['ftp', 'h323', 'irc', 'pptp', 'sip', 'tftp'],
      'ipsec-policy' => ['in,ipsec', 'in,none', 'out,ipsec', 'out,none'],
      'hotspot' => ['auth', 'from-client', 'http', 'local-dst', 'to-client'],
      'fragment' => yesNo,
      'in-interface' ||
      'out-interface' => _dynamicOptions['interface'] ?? const [],
      'in-interface-list' ||
      'out-interface-list' => _dynamicOptions['interface-list'] ?? const [],
      'src-address-list' ||
      'dst-address-list' ||
      'list' => _dynamicOptions['address-list'] ?? const [],
      'src-address-type' ||
      'dst-address-type' => ['unicast', 'local', 'broadcast', 'multicast'],
      'tcp-flags' => [
        'syn',
        'ack',
        'fin',
        'rst',
        'psh',
        'urg',
        'syn,!ack',
        'fin,syn,rst,psh,ack,urg',
      ],
      'icmp-options' => ['0:0', '3:0', '3:1', '3:3', '8:0', '11:0', '11:1'],
      'src-port' || 'dst-port' || 'to-ports' => [
        '20',
        '21',
        '22',
        '25',
        '53',
        '67',
        '68',
        '80',
        '110',
        '123',
        '143',
        '161',
        '443',
        '8291',
        '8728',
        '8729',
      ],
      'any-port' => ['53', '80', '443', '8291', '8728', '8729'],
      'in-bridge-port' ||
      'out-bridge-port' => _dynamicOptions['bridge-port'] ?? const [],
      'in-bridge-port-list' ||
      'out-bridge-port-list' => _dynamicOptions['interface-list'] ?? const [],
      'per-connection-classifier' => [
        'both-addresses',
        'both-addresses-and-ports',
        'both-ports',
        'dst-address',
        'dst-address-and-port',
        'dst-port',
        'src-address',
        'src-address-and-port',
        'src-port',
      ],
      'ipv4-options' => [
        'any',
        'loose-source-routing',
        'no-router-alert',
        'record-route',
        'router-alert',
        'strict-source-routing',
        'timestamp',
      ],
      'routing-mark' || 'new-routing-mark' => [
        ...?_dynamicOptions['routing-table'],
        ...?_dynamicOptions['routing-mark'],
      ],
      'connection-mark' ||
      'new-connection-mark' => _dynamicOptions['connection-mark'] ?? const [],
      'packet-mark' ||
      'new-packet-mark' => _dynamicOptions['packet-mark'] ?? const [],
      'layer7-protocol' => _dynamicOptions['layer7'] ?? const [],
      'jump-target' => _dynamicOptions['chain'] ?? const [],
      'reject-with' => [
        'icmp-network-unreachable',
        'icmp-host-unreachable',
        'icmp-port-unreachable',
        'icmp-protocol-unreachable',
        'icmp-admin-prohibited',
        'tcp-reset',
      ],
      'passthrough' || 'log' => yesNo,
      'timeout' => ['none-dynamic', '1m', '5m', '10m', '30m', '1h', '1d', '7d'],
      'connection-limit' => ['10,32', '50,32', '100,32', '200,32'],
      'limit' => ['1,5', '5,10', '10,20', '50,100'],
      'time' => ['00:00:00-23:59:59', '08:00:00-17:00:00'],
      'days' => ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
      _ => const [],
    };
  }

  Future<void> _save() async {
    final required = _addressList ? ['list', 'address'] : ['chain', 'action'];
    if (required.any((key) => _ctrl(key).text.trim().isEmpty)) {
      _snack(
        _addressList
            ? 'List dan address wajib diisi'
            : 'Chain dan action wajib diisi',
      );
      return;
    }

    setState(() => _saving = true);
    final command = <String>[
      '$_endpoint/${_editing ? 'set' : 'add'}',
      if (_editing) '=.id=${widget.rule!['.id']}',
    ];
    final keys = _addressList ? _addressFields : _ruleFields;
    for (final key in keys) {
      final value = _ctrl(key).text.trim();
      final original = widget.rule?[key] ?? '';
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
      _snack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${_editing ? 'Edit' : 'Tambah'} ${_label(_section)}',
                      style: TextStyle(
                        color: c.txt,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              if (!_editing) _sectionPicker(),
              if (!_editing) const SizedBox(height: 8),
              if (_addressList) _addressListForm() else _ruleForm(c),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 16),
                  label: Text(_editing ? 'Simpan perubahan' : 'Tambahkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionPicker() {
    return DropdownButtonFormField<String>(
      initialValue: _section,
      decoration: const InputDecoration(labelText: 'Kategori'),
      items: const [
        DropdownMenuItem(value: 'FILTER', child: Text('Filter Rules')),
        DropdownMenuItem(value: 'NAT', child: Text('NAT')),
        DropdownMenuItem(value: 'MANGLE', child: Text('Mangle')),
        DropdownMenuItem(value: 'RAW', child: Text('Raw')),
        DropdownMenuItem(value: 'ADDRESS LIST', child: Text('Address List')),
      ],
      onChanged: _changeSection,
    );
  }

  Widget _addressListForm() {
    return Column(
      children: [
        _field('list', 'List *'),
        const SizedBox(height: 7),
        _field('address', 'Address *'),
        const SizedBox(height: 7),
        _field('timeout', 'Timeout', hint: 'Contoh: 1d atau none-dynamic'),
        const SizedBox(height: 7),
        _field('comment', 'Comment'),
      ],
    );
  }

  Widget _ruleForm(AppC c) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _field('chain', 'Chain *')),
            const SizedBox(width: 7),
            Expanded(child: _field('action', 'Action *')),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(child: _field('protocol', 'Protocol')),
            const SizedBox(width: 7),
            Expanded(child: _field('connection-state', 'Connection State')),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(child: _field('src-address', 'Src. Address')),
            const SizedBox(width: 7),
            Expanded(child: _field('dst-address', 'Dst. Address')),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(child: _field('src-port', 'Src. Port')),
            const SizedBox(width: 7),
            Expanded(child: _field('dst-port', 'Dst. Port')),
          ],
        ),
        const SizedBox(height: 7),
        _field('any-port', 'Any Port'),
        const SizedBox(height: 5),
        InkWell(
          onTap: () => setState(() => _advanced = !_advanced),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Icon(
                  _advanced
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.cyan,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  'Parameter lanjutan',
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _advanced
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _field('in-interface', 'In Interface')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('out-interface', 'Out Interface')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _field('in-interface-list', 'In Interface List'),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _field('out-interface-list', 'Out Interface List'),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('src-address-list', 'Src. List')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('dst-address-list', 'Dst. List')),
                ],
              ),
              const SizedBox(height: 7),
              _field('connection-nat-state', 'Connection NAT State'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('connection-type', 'Connection Type')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('ipsec-policy', 'IPsec Policy')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('hotspot', 'Hotspot')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('fragment', 'Fragment')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('src-address-type', 'Src. Type')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('dst-address-type', 'Dst. Type')),
                ],
              ),
              const SizedBox(height: 7),
              _field('src-mac-address', 'Source MAC Address'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('in-bridge-port', 'In Bridge Port')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('out-bridge-port', 'Out Bridge Port')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _field('in-bridge-port-list', 'In Bridge Port List'),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _field(
                      'out-bridge-port-list',
                      'Out Bridge Port List',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('tcp-flags', 'TCP Flags')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('icmp-options', 'ICMP Options')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('connection-mark', 'Connection Mark')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('packet-mark', 'Packet Mark')),
                ],
              ),
              const SizedBox(height: 7),
              _field('routing-mark', 'Routing Mark'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _field('connection-bytes', 'Connection Bytes'),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: _field('connection-rate', 'Connection Rate')),
                ],
              ),
              const SizedBox(height: 7),
              _field('per-connection-classifier', 'Per Connection Classifier'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('connection-limit', 'Conn. Limit')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('limit', 'Limit')),
                ],
              ),
              const SizedBox(height: 7),
              _field('dst-limit', 'Destination Limit'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('layer7-protocol', 'Layer7 Protocol')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('content', 'Content')),
                ],
              ),
              const SizedBox(height: 7),
              _field('tls-host', 'TLS Host'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _field('ingress-priority', 'Ingress Priority'),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: _field('priority', 'Priority')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('dscp', 'DSCP')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('tcp-mss', 'TCP MSS')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('packet-size', 'Packet Size')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('random', 'Random')),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('ipv4-options', 'IPv4 Options')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('ttl', 'TTL')),
                ],
              ),
              const SizedBox(height: 7),
              _field('nth', 'Nth'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _field('time', 'Time')),
                  const SizedBox(width: 7),
                  Expanded(child: _field('days', 'Days')),
                ],
              ),
              if (_section == 'NAT') ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(child: _field('to-addresses', 'To Addresses')),
                    const SizedBox(width: 7),
                    Expanded(child: _field('to-ports', 'To Ports')),
                  ],
                ),
              ],
              if (_ctrl('action').text == 'jump') ...[
                const SizedBox(height: 7),
                _field('jump-target', 'Jump Target'),
              ],
              if (_ctrl('action').text == 'reject') ...[
                const SizedBox(height: 7),
                _field('reject-with', 'Reject With'),
              ],
              if (_ctrl('action').text == 'mark-connection') ...[
                const SizedBox(height: 7),
                _field('new-connection-mark', 'New Connection Mark'),
              ],
              if (_ctrl('action').text == 'mark-packet') ...[
                const SizedBox(height: 7),
                _field('new-packet-mark', 'New Packet Mark'),
              ],
              if (_ctrl('action').text == 'mark-routing') ...[
                const SizedBox(height: 7),
                _field('new-routing-mark', 'New Routing Mark'),
              ],
              if (_section == 'MANGLE') ...[
                const SizedBox(height: 7),
                _field('passthrough', 'Passthrough'),
              ],
              const SizedBox(height: 7),
              _field('log', 'Log', hint: 'yes / no'),
              const SizedBox(height: 7),
              _field('log-prefix', 'Log Prefix'),
              const SizedBox(height: 7),
              _field('comment', 'Comment'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String key, String label, {String? hint}) {
    final options = _options(key);
    if (options.isNotEmpty || _usesRouterData(key)) {
      return RouterChoiceField(
        controller: _ctrl(key),
        label: label,
        hint: hint,
        options: options,
        multiSelect: {'connection-state', 'tcp-flags', 'days'}.contains(key),
        onChanged: key == 'action' ? (_) => setState(() {}) : null,
        allowCustom: !_selectionOnly(key),
        loading: _loadingOptions && _usesRouterData(key),
      );
    }
    return TextField(
      controller: _ctrl(key),
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  bool _usesRouterData(String key) {
    return {
      'in-interface',
      'out-interface',
      'in-interface-list',
      'out-interface-list',
      'routing-mark',
      'connection-mark',
      'packet-mark',
      'layer7-protocol',
      'jump-target',
      'in-bridge-port',
      'out-bridge-port',
      'in-bridge-port-list',
      'out-bridge-port-list',
    }.contains(key);
  }

  bool _selectionOnly(String key) {
    if (_usesRouterData(key)) return true;
    return {
      'action',
      'protocol',
      'connection-state',
      'connection-nat-state',
      'connection-type',
      'ipsec-policy',
      'hotspot',
      'fragment',
      'src-address-type',
      'dst-address-type',
      'tcp-flags',
      'icmp-options',
      'reject-with',
      'passthrough',
      'log',
      'days',
      'per-connection-classifier',
      'ipv4-options',
    }.contains(key);
  }

  String _label(String section) => switch (section) {
    'FILTER' => 'Filter Rule',
    'ADDRESS LIST' => 'Address List',
    _ => section[0] + section.substring(1).toLowerCase(),
  };

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }
}
