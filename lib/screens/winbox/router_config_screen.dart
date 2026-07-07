import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/router_choice_field.dart';
import '../../widgets/skeleton.dart';

class RouterConfigScreen extends StatefulWidget {
  final MikrotikApi api;
  final int moduleIndex;

  const RouterConfigScreen({
    super.key,
    required this.api,
    required this.moduleIndex,
  });

  @override
  State<RouterConfigScreen> createState() => _RouterConfigScreenState();
}

class _RouterConfigScreenState extends State<RouterConfigScreen> {
  static const _modules = [
    _ConfigModule(
      label: 'Bridge',
      endpoint: '/interface/bridge',
      icon: Icons.device_hub_rounded,
      titleKeys: ['name'],
      subtitleKeys: ['protocol-mode', 'vlan-filtering', 'mtu'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('protocol-mode', 'Protocol Mode'),
        _ConfigField('vlan-filtering', 'VLAN Filtering', hint: 'yes / no'),
        _ConfigField('fast-forward', 'Fast Forward'),
        _ConfigField('igmp-snooping', 'IGMP Snooping'),
        _ConfigField('dhcp-snooping', 'DHCP Snooping'),
        _ConfigField('multicast-querier', 'Multicast Querier'),
        _ConfigField('auto-mac', 'Auto MAC'),
        _ConfigField('priority', 'Bridge Priority'),
        _ConfigField('ageing-time', 'Ageing Time'),
        _ConfigField('max-learned-entries', 'Max Learned Entries'),
        _ConfigField('mtu', 'MTU'),
        _ConfigField('arp', 'ARP'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Bridge Ports',
      endpoint: '/interface/bridge/port',
      icon: Icons.settings_ethernet_rounded,
      titleKeys: ['interface'],
      subtitleKeys: ['bridge', 'pvid', 'role', 'edge'],
      fields: [
        _ConfigField('interface', 'Interface', required: true),
        _ConfigField('bridge', 'Bridge', required: true),
        _ConfigField('pvid', 'PVID'),
        _ConfigField('frame-types', 'Frame Types'),
        _ConfigField(
          'ingress-filtering',
          'Ingress Filtering',
          hint: 'yes / no',
        ),
        _ConfigField('path-cost', 'Path Cost'),
        _ConfigField('internal-path-cost', 'Internal Path Cost'),
        _ConfigField('priority', 'Priority'),
        _ConfigField('edge', 'Edge'),
        _ConfigField('point-to-point', 'Point To Point'),
        _ConfigField('auto-isolate', 'Auto Isolate'),
        _ConfigField('restricted-role', 'Restricted Role'),
        _ConfigField('restricted-tcn', 'Restricted TCN'),
        _ConfigField('bpdu-guard', 'BPDU Guard'),
        _ConfigField('trusted', 'Trusted'),
        _ConfigField('horizon', 'Horizon'),
        _ConfigField('learn', 'Learn'),
        _ConfigField('unknown-unicast-flood', 'Unknown Unicast Flood'),
        _ConfigField('unknown-multicast-flood', 'Unknown Multicast Flood'),
        _ConfigField('broadcast-flood', 'Broadcast Flood'),
        _ConfigField('hw', 'Hardware Offload'),
        _ConfigField('multicast-router', 'Multicast Router'),
        _ConfigField('fast-leave', 'Fast Leave'),
        _ConfigField('tag-stacking', 'Tag Stacking'),
        _ConfigField('mvrp-registrar-state', 'MVRP Registrar State'),
        _ConfigField('mvrp-applicant-state', 'MVRP Applicant State'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Bridge VLANs',
      endpoint: '/interface/bridge/vlan',
      icon: Icons.view_week_outlined,
      titleKeys: ['vlan-ids'],
      subtitleKeys: ['bridge', 'tagged', 'untagged'],
      fields: [
        _ConfigField('bridge', 'Bridge', required: true),
        _ConfigField('vlan-ids', 'VLAN IDs', required: true),
        _ConfigField('tagged', 'Tagged'),
        _ConfigField('untagged', 'Untagged'),
        _ConfigField('mvrp-forbidden', 'MVRP Forbidden'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'VLAN',
      endpoint: '/interface/vlan',
      icon: Icons.account_tree_outlined,
      titleKeys: ['name'],
      subtitleKeys: ['vlan-id', 'interface', 'mtu'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('vlan-id', 'VLAN ID', required: true),
        _ConfigField('interface', 'Interface', required: true),
        _ConfigField('mtu', 'MTU'),
        _ConfigField('arp', 'ARP'),
        _ConfigField('use-service-tag', 'Use Service Tag'),
        _ConfigField('loop-protect', 'Loop Protect'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'WireGuard',
      endpoint: '/interface/wireguard',
      icon: Icons.vpn_key_outlined,
      titleKeys: ['name'],
      subtitleKeys: ['listen-port', 'mtu', 'public-key'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('listen-port', 'Listen Port'),
        _ConfigField('private-key', 'Private Key', obscure: true),
        _ConfigField('mtu', 'MTU'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'WG Peers',
      endpoint: '/interface/wireguard/peers',
      icon: Icons.people_outline_rounded,
      titleKeys: ['interface', 'name'],
      subtitleKeys: ['allowed-address', 'endpoint-address', 'last-handshake'],
      fields: [
        _ConfigField('interface', 'Interface', required: true),
        _ConfigField('public-key', 'Public Key', required: true),
        _ConfigField('preshared-key', 'Preshared Key', obscure: true),
        _ConfigField('allowed-address', 'Allowed Address', required: true),
        _ConfigField('endpoint-address', 'Endpoint Address'),
        _ConfigField('endpoint-port', 'Endpoint Port'),
        _ConfigField('persistent-keepalive', 'Persistent Keepalive'),
        _ConfigField('responder', 'Responder'),
        _ConfigField('client-address', 'Client Address'),
        _ConfigField('client-dns', 'Client DNS'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'IPsec Peers',
      endpoint: '/ip/ipsec/peer',
      icon: Icons.security_rounded,
      titleKeys: ['name', 'address'],
      subtitleKeys: ['exchange-mode', 'profile', 'local-address'],
      fields: [
        _ConfigField('name', 'Name'),
        _ConfigField('address', 'Address', required: true),
        _ConfigField('local-address', 'Local Address'),
        _ConfigField('exchange-mode', 'Exchange Mode'),
        _ConfigField('profile', 'Profile'),
        _ConfigField('passive', 'Passive', hint: 'yes / no'),
        _ConfigField('send-initial-contact', 'Send Initial Contact'),
        _ConfigField('proposal-check', 'Proposal Check'),
        _ConfigField('dpd-interval', 'DPD Interval'),
        _ConfigField('dpd-maximum-failures', 'DPD Max Failures'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'IPsec Identity',
      endpoint: '/ip/ipsec/identity',
      icon: Icons.key_rounded,
      titleKeys: ['peer', 'remote-id'],
      subtitleKeys: ['auth-method', 'generate-policy', 'mode-config'],
      fields: [
        _ConfigField('peer', 'Peer', required: true),
        _ConfigField('auth-method', 'Auth Method'),
        _ConfigField('secret', 'Secret', obscure: true),
        _ConfigField('my-id', 'My ID'),
        _ConfigField('remote-id', 'Remote ID'),
        _ConfigField('match-by', 'Match By'),
        _ConfigField('certificate', 'Certificate'),
        _ConfigField('remote-certificate', 'Remote Certificate'),
        _ConfigField('generate-policy', 'Generate Policy'),
        _ConfigField('mode-config', 'Mode Config'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Routes',
      endpoint: '/ip/route',
      icon: Icons.alt_route_rounded,
      titleKeys: ['dst-address'],
      subtitleKeys: ['gateway', 'distance', 'routing-table'],
      fields: [
        _ConfigField('dst-address', 'Destination', required: true),
        _ConfigField('gateway', 'Gateway', required: true),
        _ConfigField('distance', 'Distance'),
        _ConfigField('routing-table', 'Routing Table'),
        _ConfigField('pref-src', 'Preferred Source'),
        _ConfigField('check-gateway', 'Check Gateway'),
        _ConfigField('scope', 'Scope'),
        _ConfigField('target-scope', 'Target Scope'),
        _ConfigField('suppress-hw-offload', 'Suppress HW Offload'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Routing Tables',
      endpoint: '/routing/table',
      icon: Icons.table_rows_outlined,
      titleKeys: ['name'],
      subtitleKeys: ['fib'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('fib', 'FIB', hint: 'yes / no'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'DNS Static',
      endpoint: '/ip/dns/static',
      icon: Icons.dns_rounded,
      titleKeys: ['name'],
      subtitleKeys: ['address', 'type', 'ttl'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('address', 'Address'),
        _ConfigField('type', 'Type'),
        _ConfigField('ttl', 'TTL'),
        _ConfigField('regexp', 'Regexp'),
        _ConfigField('forward-to', 'Forward To'),
        _ConfigField('match-subdomain', 'Match Subdomain'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'ARP',
      endpoint: '/ip/arp',
      icon: Icons.lan_outlined,
      titleKeys: ['address'],
      subtitleKeys: ['mac-address', 'interface', 'status'],
      fields: [
        _ConfigField('address', 'Address', required: true),
        _ConfigField('mac-address', 'MAC Address', required: true),
        _ConfigField('interface', 'Interface', required: true),
        _ConfigField('comment', 'Comment'),
      ],
      canToggle: false,
    ),
    _ConfigModule(
      label: 'Neighbors',
      endpoint: '/ip/neighbor',
      icon: Icons.radar_outlined,
      titleKeys: ['identity', 'system-description'],
      subtitleKeys: ['address', 'mac-address', 'interface', 'platform'],
      fields: [],
      readOnly: true,
    ),
    _ConfigModule(
      label: 'Simple Queue',
      endpoint: '/queue/simple',
      icon: Icons.speed_rounded,
      titleKeys: ['name'],
      subtitleKeys: ['target', 'max-limit', 'priority'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('target', 'Target', required: true),
        _ConfigField('max-limit', 'Max Limit', hint: '10M/10M'),
        _ConfigField('limit-at', 'Limit At'),
        _ConfigField('burst-limit', 'Burst Limit'),
        _ConfigField('burst-threshold', 'Burst Threshold'),
        _ConfigField('burst-time', 'Burst Time'),
        _ConfigField('priority', 'Priority', hint: '8/8'),
        _ConfigField('queue', 'Queue Type'),
        _ConfigField('parent', 'Parent'),
        _ConfigField('packet-marks', 'Packet Marks'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Netwatch',
      endpoint: '/tool/netwatch',
      icon: Icons.visibility_outlined,
      titleKeys: ['name', 'host'],
      subtitleKeys: ['type', 'status', 'since', 'interval'],
      fields: [
        _ConfigField('name', 'Name'),
        _ConfigField('host', 'Host', required: true),
        _ConfigField(
          'type',
          'Type',
          hint: 'simple / icmp / tcp-conn / http-get',
        ),
        _ConfigField('interval', 'Interval'),
        _ConfigField('timeout', 'Timeout'),
        _ConfigField('port', 'Port'),
        _ConfigField('packet-count', 'Packet Count'),
        _ConfigField('packet-interval', 'Packet Interval'),
        _ConfigField('http-codes', 'HTTP Codes'),
        _ConfigField('ignore-initial-up', 'Ignore Initial Up'),
        _ConfigField('ignore-initial-down', 'Ignore Initial Down'),
        _ConfigField('up-script', 'Up Script', multiline: true),
        _ConfigField('down-script', 'Down Script', multiline: true),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'SNMP Community',
      endpoint: '/snmp/community',
      icon: Icons.sensors_outlined,
      titleKeys: ['name'],
      subtitleKeys: ['addresses', 'security', 'read-access', 'write-access'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('addresses', 'Addresses'),
        _ConfigField('security', 'Security'),
        _ConfigField('read-access', 'Read Access', hint: 'yes / no'),
        _ConfigField('write-access', 'Write Access', hint: 'yes / no'),
        _ConfigField('authentication-protocol', 'Auth Protocol'),
        _ConfigField('encryption-protocol', 'Encryption Protocol'),
        _ConfigField(
          'authentication-password',
          'Authentication Password',
          obscure: true,
        ),
        _ConfigField(
          'encryption-password',
          'Encryption Password',
          obscure: true,
        ),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Scripts',
      endpoint: '/system/script',
      icon: Icons.code_rounded,
      titleKeys: ['name'],
      subtitleKeys: ['owner', 'policy'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('source', 'Source', required: true, multiline: true),
        _ConfigField('policy', 'Policy'),
        _ConfigField('comment', 'Comment'),
      ],
      canRun: true,
    ),
    _ConfigModule(
      label: 'Scheduler',
      endpoint: '/system/scheduler',
      icon: Icons.schedule_rounded,
      titleKeys: ['name'],
      subtitleKeys: ['next-run', 'interval', 'on-event'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('start-date', 'Start Date'),
        _ConfigField('start-time', 'Start Time'),
        _ConfigField('interval', 'Interval'),
        _ConfigField('startup-delay', 'Startup Delay'),
        _ConfigField('on-event', 'On Event', required: true, multiline: true),
        _ConfigField('policy', 'Policy'),
        _ConfigField('comment', 'Comment'),
      ],
      canRun: true,
    ),
    _ConfigModule(
      label: 'Users',
      endpoint: '/user',
      icon: Icons.manage_accounts_rounded,
      titleKeys: ['name'],
      subtitleKeys: ['group', 'address', 'last-logged-in'],
      fields: [
        _ConfigField('name', 'Username', required: true),
        _ConfigField('password', 'Password', obscure: true),
        _ConfigField('group', 'Group', required: true),
        _ConfigField('address', 'Allowed Address'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'IP Services',
      endpoint: '/ip/service',
      icon: Icons.miscellaneous_services_rounded,
      titleKeys: ['name'],
      subtitleKeys: ['port', 'address', 'max-sessions'],
      fields: [
        _ConfigField('port', 'Port'),
        _ConfigField('address', 'Allowed Address'),
        _ConfigField('certificate', 'Certificate'),
        _ConfigField('tls-version', 'TLS Version'),
        _ConfigField('max-sessions', 'Max Sessions'),
      ],
      canAdd: false,
      canDelete: false,
    ),
    _ConfigModule(
      label: 'Packages',
      endpoint: '/system/package',
      icon: Icons.inventory_2_outlined,
      titleKeys: ['name'],
      subtitleKeys: ['version', 'build-time', 'scheduled'],
      fields: [],
      readOnly: true,
    ),
    _ConfigModule(
      label: 'Certificates',
      endpoint: '/certificate',
      icon: Icons.verified_user_outlined,
      titleKeys: ['name', 'common-name'],
      subtitleKeys: ['issuer', 'expires-after', 'fingerprint'],
      fields: [],
      readOnly: true,
    ),
    _ConfigModule(
      label: 'Bridge Filters',
      endpoint: '/interface/bridge/filter',
      icon: Icons.filter_alt_outlined,
      titleKeys: ['chain', 'action'],
      subtitleKeys: ['in-interface', 'out-interface', 'mac-protocol'],
      fields: [
        _ConfigField('chain', 'Chain', required: true),
        _ConfigField('action', 'Action', required: true),
        _ConfigField('in-interface', 'In Interface'),
        _ConfigField('out-interface', 'Out Interface'),
        _ConfigField('src-mac-address', 'Src. MAC Address'),
        _ConfigField('dst-mac-address', 'Dst. MAC Address'),
        _ConfigField('mac-protocol', 'MAC Protocol'),
        _ConfigField('packet-mark', 'Packet Mark'),
        _ConfigField('jump-target', 'Jump Target'),
        _ConfigField('new-packet-mark', 'New Packet Mark'),
        _ConfigField('log', 'Log'),
        _ConfigField('log-prefix', 'Log Prefix'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Bridge NAT',
      endpoint: '/interface/bridge/nat',
      icon: Icons.swap_horiz_rounded,
      titleKeys: ['chain', 'action'],
      subtitleKeys: ['in-interface', 'out-interface', 'mac-protocol'],
      fields: [
        _ConfigField('chain', 'Chain', required: true),
        _ConfigField('action', 'Action', required: true),
        _ConfigField('in-interface', 'In Interface'),
        _ConfigField('out-interface', 'Out Interface'),
        _ConfigField('src-mac-address', 'Src. MAC Address'),
        _ConfigField('dst-mac-address', 'Dst. MAC Address'),
        _ConfigField('mac-protocol', 'MAC Protocol'),
        _ConfigField('to-src-mac-address', 'To Src. MAC'),
        _ConfigField('to-dst-mac-address', 'To Dst. MAC'),
        _ConfigField('log', 'Log'),
        _ConfigField('log-prefix', 'Log Prefix'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Bridge Hosts',
      endpoint: '/interface/bridge/host',
      icon: Icons.devices_outlined,
      titleKeys: ['mac-address'],
      subtitleKeys: ['bridge', 'interface', 'vid', 'age'],
      fields: [],
      canAdd: false,
      canDelete: false,
      canToggle: false,
      readOnly: true,
    ),
    _ConfigModule(
      label: 'Bridge MDB',
      endpoint: '/interface/bridge/mdb',
      icon: Icons.hub_outlined,
      titleKeys: ['group'],
      subtitleKeys: ['bridge', 'port', 'vid'],
      fields: [],
      canAdd: false,
      canDelete: false,
      canToggle: false,
      readOnly: true,
    ),
    _ConfigModule(
      label: 'Bridge MSTIs',
      endpoint: '/interface/bridge/msti',
      icon: Icons.account_tree_rounded,
      titleKeys: ['identifier'],
      subtitleKeys: ['bridge', 'vlan-mapping', 'priority'],
      fields: [
        _ConfigField('bridge', 'Bridge', required: true),
        _ConfigField('identifier', 'Identifier', required: true),
        _ConfigField('vlan-mapping', 'VLAN Mapping', required: true),
        _ConfigField('priority', 'Priority'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Bridge MST Overrides',
      endpoint: '/interface/bridge/port/mst-override',
      icon: Icons.alt_route_rounded,
      titleKeys: ['interface'],
      subtitleKeys: ['identifier', 'internal-path-cost', 'priority'],
      fields: [
        _ConfigField('interface', 'Interface', required: true),
        _ConfigField('identifier', 'Identifier', required: true),
        _ConfigField('internal-path-cost', 'Internal Path Cost'),
        _ConfigField('priority', 'Priority'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Interface Queues',
      endpoint: '/queue/interface',
      icon: Icons.settings_ethernet_rounded,
      titleKeys: ['interface'],
      subtitleKeys: ['queue', 'active-queue'],
      fields: [_ConfigField('queue', 'Queue Type', required: true)],
      canAdd: false,
      canDelete: false,
      canToggle: false,
    ),
    _ConfigModule(
      label: 'Queue Tree',
      endpoint: '/queue/tree',
      icon: Icons.account_tree_outlined,
      titleKeys: ['name'],
      subtitleKeys: ['parent', 'packet-mark', 'max-limit', 'priority'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('parent', 'Parent', required: true),
        _ConfigField('packet-mark', 'Packet Mark'),
        _ConfigField('queue', 'Queue Type'),
        _ConfigField('limit-at', 'Limit At'),
        _ConfigField('max-limit', 'Max Limit'),
        _ConfigField('burst-limit', 'Burst Limit'),
        _ConfigField('burst-threshold', 'Burst Threshold'),
        _ConfigField('burst-time', 'Burst Time'),
        _ConfigField('priority', 'Priority'),
        _ConfigField('bucket-size', 'Bucket Size'),
        _ConfigField('comment', 'Comment'),
      ],
    ),
    _ConfigModule(
      label: 'Queue Types',
      endpoint: '/queue/type',
      icon: Icons.tune_rounded,
      titleKeys: ['name'],
      subtitleKeys: ['kind', 'pfifo-limit', 'pcq-rate', 'pcq-classifier'],
      fields: [
        _ConfigField('name', 'Name', required: true),
        _ConfigField('kind', 'Kind', required: true),
        _ConfigField('pfifo-limit', 'PFIFO Limit'),
        _ConfigField('bfifo-limit', 'BFIFO Limit'),
        _ConfigField('mq-pfifo-limit', 'MQ PFIFO Limit'),
        _ConfigField('pcq-rate', 'PCQ Rate'),
        _ConfigField('pcq-limit', 'PCQ Limit'),
        _ConfigField('pcq-total-limit', 'PCQ Total Limit'),
        _ConfigField('pcq-classifier', 'PCQ Classifier'),
        _ConfigField('pcq-burst-rate', 'PCQ Burst Rate'),
        _ConfigField('pcq-burst-threshold', 'PCQ Burst Threshold'),
        _ConfigField('pcq-burst-time', 'PCQ Burst Time'),
        _ConfigField('cake-bandwidth', 'CAKE Bandwidth'),
        _ConfigField('cake-diffserv', 'CAKE Diffserv'),
        _ConfigField('cake-flowmode', 'CAKE Flow Mode'),
        _ConfigField('cake-nat', 'CAKE NAT'),
        _ConfigField('cake-rtt', 'CAKE RTT'),
        _ConfigField('fq-codel-limit', 'FQ-CoDel Limit'),
        _ConfigField('fq-codel-interval', 'FQ-CoDel Interval'),
        _ConfigField('fq-codel-target', 'FQ-CoDel Target'),
      ],
    ),
  ];

  late int _selected;
  bool _loading = true;
  bool _fetching = false;
  String _search = '';
  List<Map<String, String>> _rows = [];

  _ConfigModule get _module => _modules[_selected];
  static const _bridgeModuleIndexes = {0, 1, 2, 21, 22, 23, 24, 25, 26};
  static const _queueModuleIndexes = {13, 27, 28, 29};
  bool get _bridgeFamily => _bridgeModuleIndexes.contains(_selected);
  bool get _queueFamily => _queueModuleIndexes.contains(_selected);

  @override
  void initState() {
    super.initState();
    _selected = widget.moduleIndex.clamp(0, _modules.length - 1);
    _fetch();
  }

  @override
  void didUpdateWidget(covariant RouterConfigScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moduleIndex != widget.moduleIndex) {
      _selected = widget.moduleIndex.clamp(0, _modules.length - 1);
      _rows = [];
      _search = '';
      _loading = true;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    _fetching = true;
    if (_rows.isEmpty && mounted) setState(() => _loading = true);
    try {
      final rows = await widget.api.query(['${_module.endpoint}/print']);
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _message(error.toString().replaceFirst('Exception: ', ''), error: true);
      }
    } finally {
      _fetching = false;
    }
  }

  void _selectModuleTab(int moduleIndex) {
    if (_selected == moduleIndex || _fetching) return;
    setState(() {
      _selected = moduleIndex;
      _rows = [];
      _search = '';
      _loading = true;
    });
    _fetch();
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

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    return Column(
      children: [
        _toolbar(c),
        Expanded(child: _content(c)),
      ],
    );
  }

  Widget _toolbar(AppC c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          if (_bridgeFamily) ...[_bridgeTabs(c), const SizedBox(height: 8)],
          if (_queueFamily) ...[_queueTabs(c), const SizedBox(height: 8)],
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_module.icon, color: AppColors.cyan, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bridgeFamily
                          ? 'Bridge / ${_module.label}'
                          : _queueFamily
                          ? 'Queues / ${_module.label}'
                          : _module.label,
                      style: TextStyle(
                        color: c.txt,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_rows.length} data',
                      style: TextStyle(color: c.sub, fontSize: 8),
                    ),
                  ],
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
              if (_module.canAdd && !_module.readOnly)
                IconButton.filled(
                  tooltip: 'Tambah ${_module.label}',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 38,
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              style: TextStyle(color: c.txt, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Cari ${_module.label}...',
                prefixIcon: Icon(Icons.search_rounded, color: c.sub, size: 17),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bridgeTabs(AppC c) {
    const tabs = [
      (0, 'Bridge', Icons.device_hub_rounded),
      (1, 'Ports', Icons.settings_ethernet_rounded),
      (2, 'VLANs', Icons.view_week_outlined),
      (25, 'MSTIs', Icons.account_tree_rounded),
      (26, 'MST Override', Icons.alt_route_rounded),
      (21, 'Filters', Icons.filter_alt_outlined),
      (22, 'NAT', Icons.swap_horiz_rounded),
      (23, 'Hosts', Icons.devices_outlined),
      (24, 'MDB', Icons.hub_outlined),
    ];
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.card2.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 3),
        itemBuilder: (_, index) {
          final tab = tabs[index];
          final selected = _selected == tab.$1;
          return SizedBox(
            width: 86,
            child: InkWell(
              onTap: () => _selectModuleTab(tab.$1),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: selected ? AppColors.cyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.$3,
                        size: 14,
                        color: selected ? AppColors.darkBg : c.sub,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          tab.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? AppColors.darkBg : c.txt,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _queueTabs(AppC c) {
    const tabs = [
      (13, 'Simple', Icons.speed_rounded),
      (27, 'Interface', Icons.settings_ethernet_rounded),
      (28, 'Tree', Icons.account_tree_outlined),
      (29, 'Types', Icons.tune_rounded),
    ];
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.card2.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 3),
        itemBuilder: (_, index) {
          final tab = tabs[index];
          final selected = _selected == tab.$1;
          return SizedBox(
            width: 86,
            child: InkWell(
              onTap: () => _selectModuleTab(tab.$1),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: selected ? AppColors.cyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.$3,
                        size: 14,
                        color: selected ? AppColors.darkBg : c.sub,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          tab.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? AppColors.darkBg : c.txt,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
          child: SkeletonBox(height: 62, radius: 9),
        ),
      );
    }
    final rows = _visible;
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data ${_module.label}',
          style: TextStyle(color: c.sub, fontSize: 11),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: rows.length,
        itemBuilder: (_, index) => _rowCard(rows[index], index, c),
      ),
    );
  }

  Widget _rowCard(Map<String, String> row, int index, AppC c) {
    final disabled = row['disabled'] == 'true';
    final dynamic = row['dynamic'] == 'true';
    final invalid = row['invalid'] == 'true';
    final comment = row['comment']?.trim() ?? '';
    final title = _values(
      row,
      _module.titleKeys,
      fallback: 'Item ${index + 1}',
    );
    final subtitle = _values(row, _module.subtitleKeys);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(9, 7, 4, 7),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 8, 4),
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
                  color: invalid
                      ? AppColors.red
                      : disabled
                      ? c.sub
                      : AppColors.green,
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: disabled ? c.sub : c.txt,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (dynamic) _flag('D', AppColors.cyan),
                        if (invalid) _flag('I', AppColors.red),
                        if (disabled) _flag('X', c.sub),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.isEmpty ? 'tanpa detail' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.sub, fontSize: 9),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                iconSize: 17,
                padding: EdgeInsets.zero,
                onSelected: (action) => _action(action, row),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'detail', child: Text('Detail')),
                  if (!_module.readOnly)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (_module.canRun)
                    const PopupMenuItem(
                      value: 'run',
                      child: Text('Run Sekarang'),
                    ),
                  if (!_module.readOnly && _module.canToggle)
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(disabled ? 'Enable' : 'Disable'),
                    ),
                  if (_module.canDelete && !dynamic)
                    const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flag(String text, Color color) {
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

  String _values(
    Map<String, String> row,
    List<String> keys, {
    String fallback = '',
  }) {
    final values = keys
        .map((key) => row[key])
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
    return values.isEmpty ? fallback : values.join('  |  ');
  }

  Future<void> _action(String action, Map<String, String> row) async {
    if (action == 'detail') {
      _showDetails(row);
      return;
    }
    if (action == 'edit') {
      await _openEditor(row);
      return;
    }
    final id = row['.id'];
    if (id == null) return;
    try {
      if (action == 'run') {
        await widget.api.queryOrThrow(['${_module.endpoint}/run', '=.id=$id']);
        _message('${_module.label} dijalankan');
      } else if (action == 'toggle') {
        final disabled = row['disabled'] == 'true';
        await widget.api.queryOrThrow([
          '${_module.endpoint}/${disabled ? 'enable' : 'disable'}',
          '=.id=$id',
        ]);
      } else if (action == 'delete' && await _confirmDelete(row)) {
        await widget.api.queryOrThrow([
          '${_module.endpoint}/remove',
          '=.id=$id',
        ]);
      } else {
        return;
      }
      await _fetch();
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _openEditor([Map<String, String>? row]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConfigEditor(api: widget.api, module: _module, row: row),
    );
    if (changed == true) _fetch();
  }

  void _showDetails(Map<String, String> row) {
    final c = AppC(context.read<AppProvider>().isDark);
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
                _module.label,
                style: TextStyle(
                  color: c.txt,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...row.entries
                  .where((entry) => entry.value.isNotEmpty)
                  .map(
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
    final name = _values(row, _module.titleKeys, fallback: _module.label);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: c.card,
            title: Text(
              'Hapus ${_module.label}',
              style: TextStyle(color: c.txt),
            ),
            content: Text(name, style: TextStyle(color: c.sub)),
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

class _ConfigEditor extends StatefulWidget {
  final MikrotikApi api;
  final _ConfigModule module;
  final Map<String, String>? row;

  const _ConfigEditor({required this.api, required this.module, this.row});

  @override
  State<_ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<_ConfigEditor> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<String>> _dynamicOptions = {};
  bool _saving = false;
  bool _loadingOptions = true;
  bool _showAdvanced = true;

  bool get _editing => widget.row != null;

  @override
  void initState() {
    super.initState();
    for (final field in widget.module.fields) {
      _controllers[field.key] = TextEditingController(
        text: widget.row?[field.key] ?? '',
      );
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final commands = <List<String>>[
        ['/interface/print'],
        ['/interface/bridge/print'],
        ['/interface/wireguard/print'],
        ['/ip/ipsec/peer/print'],
        ['/ip/ipsec/profile/print'],
        ['/ip/ipsec/mode-config/print'],
        ['/routing/table/print'],
        ['/queue/type/print'],
        ['/user/group/print'],
        ['/certificate/print'],
        ['/system/script/print'],
        ['/queue/simple/print'],
        ['/ip/firewall/mangle/print'],
        ['/ip/route/print'],
        ['/ip/address/print'],
        ['/ip/dhcp-server/lease/print'],
        ['/ppp/secret/print'],
        ['/interface/bridge/filter/print'],
        ['/queue/tree/print'],
        ['/interface/bridge/port/print'],
      ];
      final results = await Future.wait(commands.map(_safeQuery));
      if (!mounted) return;
      setState(() {
        _dynamicOptions['interface'] = _values(results[0], 'name');
        _dynamicOptions['bridge'] = _values(results[1], 'name');
        _dynamicOptions['wireguard'] = _values(results[2], 'name');
        _dynamicOptions['ipsec-peer'] = [
          ..._values(results[3], 'name'),
          ..._values(results[3], '.id'),
        ];
        _dynamicOptions['ipsec-profile'] = _values(results[4], 'name');
        _dynamicOptions['mode-config'] = _values(results[5], 'name');
        _dynamicOptions['routing-table'] = _values(results[6], 'name');
        _dynamicOptions['queue-type'] = _values(results[7], 'name');
        _dynamicOptions['user-group'] = _values(results[8], 'name');
        _dynamicOptions['certificate'] = _values(results[9], 'name');
        _dynamicOptions['script'] = _values(results[10], 'name');
        _dynamicOptions['simple-queue'] = _values(results[11], 'name');
        _dynamicOptions['packet-mark'] = {
          ..._values(results[12], 'packet-mark'),
          ..._values(results[12], 'new-packet-mark'),
        }.toList();
        _dynamicOptions['gateway'] = {
          ..._values(results[0], 'name'),
          ..._values(results[13], 'gateway'),
        }.toList();
        _dynamicOptions['local-address'] = _values(
          results[14],
          'address',
        ).map((address) => address.split('/').first).toList();
        _dynamicOptions['queue-target'] = {
          ..._values(results[14], 'address'),
          ..._values(results[15], 'address'),
          ..._values(results[15], 'active-address'),
          ..._values(results[16], 'remote-address'),
        }.toList();
        _dynamicOptions['bridge-chain'] = _values(results[17], 'chain');
        _dynamicOptions['bridge-packet-mark'] = {
          ..._values(results[12], 'packet-mark'),
          ..._values(results[12], 'new-packet-mark'),
          ..._values(results[17], 'packet-mark'),
          ..._values(results[17], 'new-packet-mark'),
        }.toList();
        _dynamicOptions['queue-tree'] = _values(results[18], 'name');
        _dynamicOptions['bridge-port'] = _values(results[19], 'interface');
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

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    for (final field in widget.module.fields.where((field) => field.required)) {
      if (_controllers[field.key]!.text.trim().isEmpty) {
        _message('${field.label} wajib diisi');
        return;
      }
    }
    setState(() => _saving = true);
    final command = <String>[
      '${widget.module.endpoint}/${_editing ? 'set' : 'add'}',
      if (_editing) '=.id=${widget.row!['.id']}',
    ];
    for (final field in widget.module.fields) {
      final value = _controllers[field.key]!.text.trim();
      final original = widget.row?[field.key] ?? '';
      if (_editing) {
        if (value != original && !(field.obscure && value.isEmpty)) {
          command.add('=${field.key}=$value');
        }
      } else if (value.isNotEmpty) {
        command.add('=${field.key}=$value');
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

  List<String> _optionsFor(_ConfigField field) {
    final key = field.key;
    final endpoint = widget.module.endpoint;
    const yesNo = ['yes', 'no'];

    if (key == 'interface' || key == 'in-interface' || key == 'out-interface') {
      if (endpoint == '/interface/wireguard/peers') {
        return _dynamicOptions['wireguard'] ?? const [];
      }
      if (endpoint == '/interface/bridge/port/mst-override') {
        return _dynamicOptions['bridge-port'] ?? const [];
      }
      return _dynamicOptions['interface'] ?? const [];
    }
    if (key == 'bridge') return _dynamicOptions['bridge'] ?? const [];
    if (key == 'tagged' || key == 'untagged') {
      return _dynamicOptions['interface'] ?? const [];
    }
    if (key == 'peer') return _dynamicOptions['ipsec-peer'] ?? const [];
    if (key == 'profile') {
      return _dynamicOptions['ipsec-profile'] ?? const [];
    }
    if (key == 'mode-config') {
      return _dynamicOptions['mode-config'] ?? const [];
    }
    if (key == 'routing-table') {
      return _dynamicOptions['routing-table'] ?? const [];
    }
    if (key == 'gateway') {
      return _dynamicOptions['gateway'] ?? const [];
    }
    if (key == 'local-address') {
      return _dynamicOptions['local-address'] ?? const [];
    }
    if (key == 'target') return _dynamicOptions['queue-target'] ?? const [];
    if (key == 'queue') return _dynamicOptions['queue-type'] ?? const [];
    if (key == 'parent') {
      if (endpoint == '/queue/tree') {
        return [
          'global',
          'global-in',
          'global-out',
          ...?_dynamicOptions['interface'],
          ...?_dynamicOptions['queue-tree'],
        ];
      }
      return ['none', ...?_dynamicOptions['simple-queue']];
    }
    if (key == 'packet-marks') {
      return _dynamicOptions['packet-mark'] ?? const [];
    }
    if (key == 'packet-mark' && endpoint == '/queue/tree') {
      return ['no-mark', ...?_dynamicOptions['packet-mark']];
    }
    if (key == 'group') return _dynamicOptions['user-group'] ?? const [];
    if (key == 'certificate' || key == 'remote-certificate') {
      return ['none', ...?_dynamicOptions['certificate']];
    }
    if (key == 'on-event') return _dynamicOptions['script'] ?? const [];
    if (endpoint == '/interface/bridge/filter' ||
        endpoint == '/interface/bridge/nat') {
      if (key == 'chain') {
        final defaults = endpoint.endsWith('/nat')
            ? const ['srcnat', 'dstnat']
            : const ['input', 'forward', 'output'];
        return {...defaults, ...?_dynamicOptions['bridge-chain']}.toList();
      }
      if (key == 'action') {
        return endpoint.endsWith('/nat')
            ? const [
                'accept',
                'arp-reply',
                'dst-nat',
                'jump',
                'log',
                'netmap',
                'passthrough',
                'redirect',
                'return',
                'src-nat',
              ]
            : const [
                'accept',
                'drop',
                'jump',
                'log',
                'mark-packet',
                'passthrough',
                'return',
                'set-priority',
              ];
      }
      if (key == 'mac-protocol') {
        return const [
          'arp',
          'homeplug-av',
          'ip',
          'ipv6',
          'ipx',
          'length',
          'lldp',
          'mpls-multicast',
          'mpls-unicast',
          'pppoe',
          'pppoe-discovery',
          'rarp',
          'vlan',
        ];
      }
      if (key == 'packet-mark' || key == 'new-packet-mark') {
        return _dynamicOptions['bridge-packet-mark'] ?? const [];
      }
      if (key == 'jump-target') {
        return _dynamicOptions['bridge-chain'] ?? const [];
      }
    }

    if ({
      'vlan-filtering',
      'ingress-filtering',
      'passive',
      'send-initial-contact',
      'fib',
      'read-access',
      'write-access',
      'fast-forward',
      'igmp-snooping',
      'multicast-querier',
      'dhcp-snooping',
      'auto-mac',
      'bpdu-guard',
      'trusted',
      'auto-isolate',
      'restricted-role',
      'restricted-tcn',
      'unknown-unicast-flood',
      'unknown-multicast-flood',
      'broadcast-flood',
      'hw',
      'fast-leave',
      'tag-stacking',
      'use-service-tag',
      'responder',
      'suppress-hw-offload',
      'match-subdomain',
      'ignore-initial-up',
      'ignore-initial-down',
      'log',
    }.contains(key)) {
      return yesNo;
    }

    return switch (key) {
      'protocol-mode' => ['none', 'stp', 'rstp', 'mstp'],
      'mtu' => ['1280', '1420', '1500', '1598', '9000'],
      'vlan-id' ||
      'vlan-ids' ||
      'pvid' => ['1', '10', '20', '30', '40', '50', '100', '200', '4094'],
      'path-cost' => ['10', '100', '1000', '10000', '20000'],
      'priority' when endpoint == '/interface/bridge' => [
        '0x0000',
        '0x1000',
        '0x2000',
        '0x4000',
        '0x8000',
        '0xA000',
        '0xC000',
        '0xF000',
      ],
      'ageing-time' => ['10s', '30s', '1m', '5m', '10m', '30m', '1h'],
      'arp' => [
        'enabled',
        'disabled',
        'proxy-arp',
        'local-proxy-arp',
        'reply-only',
      ],
      'frame-types' => [
        'admit-all',
        'admit-only-vlan-tagged',
        'admit-only-untagged-and-priority-tagged',
      ],
      'edge' => ['auto', 'yes', 'yes-discover', 'no'],
      'point-to-point' => ['auto', 'yes', 'no'],
      'horizon' => ['none', '1', '2', '10', '100'],
      'multicast-router' => [
        'disabled',
        'permanent',
        'temporary-query',
        'multicast-router',
      ],
      'learn' => ['auto', 'yes', 'no'],
      'mvrp-registrar-state' => ['normal', 'fixed', 'forbidden'],
      'mvrp-applicant-state' => [
        'normal-participant',
        'non-participant',
        'active-participant',
      ],
      'loop-protect' => ['default', 'on', 'off'],
      'exchange-mode' => ['ike2', 'main', 'aggressive'],
      'listen-port' || 'endpoint-port' => ['13231', '51820', '51821', '51822'],
      'persistent-keepalive' => ['0', '10', '15', '20', '25', '30', '60'],
      'auth-method' => [
        'pre-shared-key',
        'digital-signature',
        'eap',
        'eap-radius',
      ],
      'generate-policy' => ['no', 'port-strict', 'port-override'],
      'proposal-check' => ['claim', 'exact', 'obey', 'strict'],
      'dpd-interval' => ['disable-dpd', '10s', '30s', '1m', '2m'],
      'dpd-maximum-failures' => ['1', '2', '3', '5', '10'],
      'match-by' => ['remote-id', 'certificate'],
      'check-gateway' => ['none', 'arp', 'ping', 'bfd'],
      'distance' => ['1', '2', '5', '10', '20', '50', '100', '200', '255'],
      'scope' || 'target-scope' => ['10', '20', '30', '40', '50', '200', '255'],
      'type' when endpoint == '/ip/dns/static' => [
        'A',
        'AAAA',
        'CNAME',
        'FWD',
        'MX',
        'NS',
        'NXDOMAIN',
        'SRV',
        'TXT',
      ],
      'type' when endpoint == '/tool/netwatch' => [
        'simple',
        'icmp',
        'tcp-conn',
        'http-get',
        'https-get',
        'dns',
      ],
      'priority' => ['1/1', '2/2', '3/3', '4/4', '5/5', '6/6', '7/7', '8/8'],
      'max-limit' || 'limit-at' || 'burst-limit' => [
        '1M/1M',
        '2M/2M',
        '5M/5M',
        '10M/10M',
        '20M/20M',
        '50M/50M',
        '100M/100M',
      ],
      'burst-threshold' => ['1M/1M', '2M/2M', '5M/5M', '10M/10M', '20M/20M'],
      'burst-time' => ['5s/5s', '10s/10s', '30s/30s', '1m/1m'],
      'interval' => ['10s', '30s', '1m', '5m', '10m', '30m', '1h', '1d'],
      'timeout' => ['1s', '3s', '5s', '10s', '30s'],
      'packet-count' => ['1', '2', '3', '5', '10', '20'],
      'packet-interval' => ['50ms', '100ms', '500ms', '1s', '5s'],
      'http-codes' => ['200', '200-299', '301,302', '400-499', '500-599'],
      'startup-delay' => ['0s', '5s', '10s', '30s', '1m', '5m'],
      'start-time' => [
        'startup',
        '00:00:00',
        '06:00:00',
        '08:00:00',
        '12:00:00',
        '18:00:00',
        '23:00:00',
      ],
      'ttl' => ['1m', '5m', '1h', '1d', '7d'],
      'port' => [
        '21',
        '22',
        '23',
        '53',
        '80',
        '161',
        '443',
        '8291',
        '8728',
        '8729',
      ],
      'max-sessions' => ['1', '5', '10', '20', '50', '100', '200'],
      'security' => ['none', 'authorized', 'private'],
      'authentication-protocol' => ['MD5', 'SHA1'],
      'encryption-protocol' => ['DES', 'AES'],
      'tls-version' => ['any', 'only-1.2', 'only-1.3'],
      'policy' => [
        'ftp',
        'reboot',
        'read',
        'write',
        'policy',
        'test',
        'password',
        'sniff',
        'sensitive',
        'romon',
      ],
      'kind' => [
        'bfifo',
        'cake',
        'codel',
        'fq-codel',
        'mq-pfifo',
        'none',
        'pcq',
        'pfifo',
        'red',
        'sfq',
      ],
      'pcq-classifier' => [
        'dst-address',
        'dst-port',
        'src-address',
        'src-port',
      ],
      _ => const [],
    };
  }

  Widget _buildField(_ConfigField field) {
    final label = '${field.label}${field.required ? ' *' : ''}';
    final options = _optionsFor(field);
    if (options.isNotEmpty || _usesRouterData(field.key)) {
      return RouterChoiceField(
        controller: _controllers[field.key]!,
        label: label,
        hint: field.hint,
        options: options,
        obscureText: field.obscure,
        multiSelect: {
          'tagged',
          'untagged',
          'policy',
          'packet-marks',
        }.contains(field.key),
        minLines: field.multiline ? 3 : 1,
        maxLines: field.multiline ? 8 : 1,
        allowCustom: !_selectionOnly(field),
        loading: _loadingOptions && _usesRouterData(field.key),
        onChanged: _controlsVisibility(field.key)
            ? (_) => setState(() {})
            : null,
      );
    }
    return TextField(
      controller: _controllers[field.key],
      obscureText: field.obscure,
      minLines: field.multiline ? 4 : 1,
      maxLines: field.multiline ? 10 : 1,
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        hintText: field.hint,
        alignLabelWithHint: field.multiline,
      ),
    );
  }

  bool _controlsVisibility(String key) {
    return {'type', 'auth-method', 'security', 'kind'}.contains(key);
  }

  bool _usesRouterData(String key) {
    return {
      'interface',
      'in-interface',
      'out-interface',
      'bridge',
      'tagged',
      'untagged',
      'peer',
      'profile',
      'mode-config',
      'routing-table',
      'queue',
      'parent',
      'packet-marks',
      'packet-mark',
      'group',
      'certificate',
      'remote-certificate',
      'on-event',
      'jump-target',
    }.contains(key);
  }

  bool _selectionOnly(_ConfigField field) {
    final key = field.key;
    if (_usesRouterData(key) && key != 'on-event') return true;
    return {
      'vlan-filtering',
      'ingress-filtering',
      'passive',
      'send-initial-contact',
      'fib',
      'read-access',
      'write-access',
      'fast-forward',
      'igmp-snooping',
      'multicast-querier',
      'auto-mac',
      'bpdu-guard',
      'trusted',
      'use-service-tag',
      'responder',
      'suppress-hw-offload',
      'match-subdomain',
      'ignore-initial-up',
      'ignore-initial-down',
      'protocol-mode',
      'arp',
      'frame-types',
      'edge',
      'point-to-point',
      'multicast-router',
      'loop-protect',
      'exchange-mode',
      'auth-method',
      'generate-policy',
      'proposal-check',
      'match-by',
      'check-gateway',
      'type',
      'priority',
      'security',
      'authentication-protocol',
      'encryption-protocol',
      'tls-version',
      'policy',
      'chain',
      'action',
      'mac-protocol',
      'log',
      'kind',
      'pcq-classifier',
      'learn',
      'mvrp-registrar-state',
      'mvrp-applicant-state',
    }.contains(key);
  }

  bool _isFieldVisible(_ConfigField field) {
    final endpoint = widget.module.endpoint;
    final key = field.key;
    if (endpoint == '/tool/netwatch') {
      final type = _controllers['type']?.text.trim() ?? '';
      if (key == 'port') return type == 'tcp-conn';
      if (key == 'http-codes') {
        return type == 'http-get' || type == 'https-get';
      }
      if (key == 'packet-count' || key == 'packet-interval') {
        return type.isEmpty || type == 'simple' || type == 'icmp';
      }
    }
    if (endpoint == '/ip/ipsec/identity') {
      final method = _controllers['auth-method']?.text.trim() ?? '';
      if (key == 'secret') {
        return method.isEmpty || method == 'pre-shared-key';
      }
      if (key == 'certificate' || key == 'remote-certificate') {
        return method == 'digital-signature';
      }
    }
    if (endpoint == '/snmp/community') {
      final security = _controllers['security']?.text.trim() ?? '';
      if (key == 'authentication-protocol' ||
          key == 'authentication-password') {
        return security == 'authorized' || security == 'private';
      }
      if (key == 'encryption-protocol' || key == 'encryption-password') {
        return security == 'private';
      }
    }
    if (endpoint == '/ip/dns/static') {
      final type = _controllers['type']?.text.trim() ?? '';
      if (key == 'address') {
        return type.isEmpty || type == 'A' || type == 'AAAA';
      }
      if (key == 'forward-to') return type == 'FWD';
    }
    if (endpoint == '/queue/type') {
      final kind = _controllers['kind']?.text.trim() ?? '';
      if (key.startsWith('pcq-')) return kind == 'pcq';
      if (key.startsWith('cake-')) return kind == 'cake';
      if (key.startsWith('fq-codel-')) return kind == 'fq-codel';
      if (key == 'pfifo-limit') return kind == 'pfifo';
      if (key == 'bfifo-limit') return kind == 'bfifo';
      if (key == 'mq-pfifo-limit') return kind == 'mq-pfifo';
    }
    return true;
  }

  List<_ConfigField> _visibleFields() {
    return widget.module.fields.where(_isFieldVisible).toList();
  }

  Set<String> _primaryFieldKeys() {
    return switch (widget.module.endpoint) {
      '/interface/bridge' => {'name', 'protocol-mode', 'vlan-filtering'},
      '/interface/bridge/port' => {
        'interface',
        'bridge',
        'pvid',
        'frame-types',
      },
      '/interface/bridge/vlan' => {'bridge', 'vlan-ids', 'tagged', 'untagged'},
      '/interface/vlan' => {'name', 'vlan-id', 'interface', 'mtu'},
      '/interface/bridge/filter' || '/interface/bridge/nat' => {
        'chain',
        'action',
        'in-interface',
        'out-interface',
      },
      _ => widget.module.fields.take(5).map((field) => field.key).toSet(),
    };
  }

  Widget _fieldList(List<_ConfigField> fields) {
    return Column(
      children: fields
          .map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildField(field),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    final fields = _visibleFields();
    final primaryKeys = _primaryFieldKeys();
    final primaryFields = fields
        .where((field) => primaryKeys.contains(field.key))
        .toList();
    final advancedFields = fields
        .where((field) => !primaryKeys.contains(field.key))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          MediaQuery.viewInsetsOf(context).bottom + 12,
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
                    child: Icon(
                      widget.module.icon,
                      size: 16,
                      color: AppColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_editing ? 'Edit' : 'Tambah'} ${widget.module.label}',
                          style: TextStyle(
                            color: c.txt,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${fields.length} parameter tersedia',
                          style: TextStyle(color: c.sub, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              if (widget.module.endpoint == '/interface/bridge') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'Bridge hanya membuat grup. Setelah disimpan, buka tab '
                    'Ports untuk memilih interface dan bridge tujuan.',
                    style: TextStyle(color: c.sub, fontSize: 10),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _fieldList(primaryFields),
              if (advancedFields.isNotEmpty) ...[
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: c.card2.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 15,
                          color: AppColors.cyan,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Opsi lengkap',
                            style: TextStyle(
                              color: c.txt,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${advancedFields.length}',
                          style: TextStyle(color: c.sub, fontSize: 10),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          _showAdvanced
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 17,
                          color: c.sub,
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 160),
                  crossFadeState: _showAdvanced
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _fieldList(advancedFields),
                  ),
                ),
              ],
              const SizedBox(height: 8),
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

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }
}

class _ConfigModule {
  final String label;
  final String endpoint;
  final IconData icon;
  final List<String> titleKeys;
  final List<String> subtitleKeys;
  final List<_ConfigField> fields;
  final bool canAdd;
  final bool canDelete;
  final bool canRun;
  final bool canToggle;
  final bool readOnly;

  const _ConfigModule({
    required this.label,
    required this.endpoint,
    required this.icon,
    required this.titleKeys,
    required this.subtitleKeys,
    required this.fields,
    this.canAdd = true,
    this.canDelete = true,
    this.canRun = false,
    this.canToggle = true,
    this.readOnly = false,
  });
}

class _ConfigField {
  final String key;
  final String label;
  final String? hint;
  final bool required;
  final bool multiline;
  final bool obscure;

  const _ConfigField(
    this.key,
    this.label, {
    this.hint,
    this.required = false,
    this.multiline = false,
    this.obscure = false,
  });
}
