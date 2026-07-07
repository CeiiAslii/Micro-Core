import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/app_provider.dart';

class DrawerWidget extends StatefulWidget {
  final int selectedIndex;
  final int selectedSubIndex;
  final ValueChanged<int> onSelect;

  const DrawerWidget({
    super.key,
    required this.selectedIndex,
    required this.selectedSubIndex,
    required this.onSelect,
  });

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget> {
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.selectedIndex == 12) {
      _expandedIndex = _configGroupKey(widget.selectedSubIndex);
    } else if ({1, 2, 3, 6}.contains(widget.selectedIndex)) {
      _expandedIndex = widget.selectedIndex;
    }
  }

  @override
  void didUpdateWidget(covariant DrawerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.selectedSubIndex != widget.selectedSubIndex) {
      if (widget.selectedIndex == 12) {
        _expandedIndex = _configGroupKey(widget.selectedSubIndex);
      } else if ({1, 2, 3, 6}.contains(widget.selectedIndex)) {
        _expandedIndex = widget.selectedIndex;
      }
    }
  }

  int _configGroupKey(int module) {
    if (module <= 3 || module >= 21 && module <= 26) return 120;
    if (module <= 7) return 121;
    if (module <= 12) return 122;
    if (module <= 15 || module >= 27 && module <= 29) return 123;
    if (module <= 17) return 124;
    return 125;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final c = AppC(provider.isDark);

    return Drawer(
      width: 280,
      backgroundColor: c.surface,
      child: SafeArea(
        child: Column(
          children: [
            _header(provider, c),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                children: [
                  _sectionLabel('MONITORING', c),
                  _item(0, Icons.dashboard_rounded, 'Dashboard', c),
                  _item(9, Icons.health_and_safety_rounded, 'Health Center', c),
                  _group(6, Icons.monitor_heart_rounded, 'Interface', c, [
                    _SubItem(Icons.show_chart_rounded, 'Traffic Realtime', 60),
                    _SubItem(Icons.lan_rounded, 'Status Interface', 61),
                  ]),
                  _sectionLabel('JARINGAN', c),
                  _group(1, Icons.hub_rounded, 'IP & DHCP', c, [
                    _SubItem(Icons.grid_view_rounded, 'IP Address', 10),
                    _SubItem(Icons.pool_rounded, 'IP Pool', 11),
                    _SubItem(Icons.router_rounded, 'DHCP Server', 12),
                    _SubItem(Icons.devices_rounded, 'DHCP Lease', 13),
                    _SubItem(Icons.dns_rounded, 'DNS Settings', 14),
                  ]),
                  _item(
                    11,
                    Icons.admin_panel_settings_rounded,
                    'Firewall',
                    c,
                    selectCode: -11,
                  ),
                  _group(
                    12,
                    Icons.device_hub_rounded,
                    'Switching & VLAN',
                    c,
                    [
                      _SubItem(Icons.device_hub_rounded, 'Bridge', 1200),
                      _SubItem(
                        Icons.settings_ethernet_rounded,
                        'Bridge Ports',
                        1201,
                      ),
                      _SubItem(Icons.view_week_outlined, 'Bridge VLANs', 1202),
                      _SubItem(Icons.account_tree_outlined, 'VLAN', 1203),
                      _SubItem(
                        Icons.account_tree_rounded,
                        'Bridge MSTIs',
                        1225,
                      ),
                      _SubItem(Icons.alt_route_rounded, 'MST Overrides', 1226),
                      _SubItem(
                        Icons.filter_alt_outlined,
                        'Bridge Filters',
                        1221,
                      ),
                      _SubItem(Icons.swap_horiz_rounded, 'Bridge NAT', 1222),
                      _SubItem(Icons.devices_outlined, 'Bridge Hosts', 1223),
                      _SubItem(Icons.hub_outlined, 'Bridge MDB', 1224),
                    ],
                    expansionKey: 120,
                  ),
                  _group(12, Icons.vpn_key_outlined, 'VPN', c, [
                    _SubItem(Icons.vpn_key_outlined, 'WireGuard', 1204),
                    _SubItem(
                      Icons.people_outline_rounded,
                      'WireGuard Peers',
                      1205,
                    ),
                    _SubItem(Icons.security_rounded, 'IPsec Peers', 1206),
                    _SubItem(Icons.key_rounded, 'IPsec Identity', 1207),
                  ], expansionKey: 121),
                  _group(12, Icons.alt_route_rounded, 'Routing & IP', c, [
                    _SubItem(Icons.alt_route_rounded, 'Routes', 1208),
                    _SubItem(Icons.table_rows_outlined, 'Routing Tables', 1209),
                    _SubItem(Icons.dns_rounded, 'DNS Static', 1210),
                    _SubItem(Icons.lan_outlined, 'ARP', 1211),
                    _SubItem(Icons.radar_outlined, 'Neighbors', 1212),
                  ], expansionKey: 122),
                  _item(4, Icons.balance_rounded, 'Load Balance', c),
                  _sectionLabel('QOS & MONITOR', c),
                  _group(12, Icons.speed_rounded, 'Queue & Monitor', c, [
                    _SubItem(Icons.speed_rounded, 'Simple Queue', 1213),
                    _SubItem(
                      Icons.settings_ethernet_rounded,
                      'Interface Queues',
                      1227,
                    ),
                    _SubItem(Icons.account_tree_outlined, 'Queue Tree', 1228),
                    _SubItem(Icons.tune_rounded, 'Queue Types', 1229),
                    _SubItem(Icons.visibility_outlined, 'Netwatch', 1214),
                    _SubItem(Icons.sensors_outlined, 'SNMP Community', 1215),
                  ], expansionKey: 123),
                  _sectionLabel('AKSES PENGGUNA', c),
                  _group(2, Icons.wifi_rounded, 'Hotspot', c, [
                    _SubItem(Icons.people_rounded, 'User Aktif', 20),
                    _SubItem(Icons.confirmation_number_rounded, 'Voucher', 21),
                    _SubItem(Icons.add_card_rounded, 'Generate Voucher', 22),
                    _SubItem(
                      Icons.settings_backup_restore_rounded,
                      'Backup',
                      23,
                    ),
                    _SubItem(Icons.router_outlined, 'Servers', 24),
                    _SubItem(Icons.web_outlined, 'Server Profiles', 25),
                    _SubItem(Icons.badge_outlined, 'User Profiles', 26),
                  ]),
                  _group(3, Icons.cable_rounded, 'PPP', c, [
                    _SubItem(
                      Icons.people_alt_rounded,
                      'Active Connections',
                      30,
                    ),
                    _SubItem(Icons.manage_accounts_rounded, 'Secrets', 31),
                    _SubItem(Icons.speed_rounded, 'Profiles', 32),
                    _SubItem(Icons.person_add_rounded, 'Tambah Secret', 33),
                    _SubItem(Icons.router_outlined, 'PPPoE Servers', 34),
                  ]),
                  _sectionLabel('TOOLS', c),
                  _group(12, Icons.code_rounded, 'Automation', c, [
                    _SubItem(Icons.code_rounded, 'Scripts', 1216),
                    _SubItem(Icons.schedule_rounded, 'Scheduler', 1217),
                  ], expansionKey: 124),
                  _item(
                    10,
                    Icons.terminal_rounded,
                    'RouterOS Terminal',
                    c,
                    selectCode: -10,
                  ),
                  _item(
                    14,
                    Icons.troubleshoot_rounded,
                    'Diagnostics',
                    c,
                    selectCode: -14,
                  ),
                  _item(5, Icons.folder_copy_rounded, 'File & Storage', c),
                  _item(8, Icons.receipt_long_rounded, 'Log Router', c),
                  _sectionLabel('SISTEM', c),
                  _group(
                    12,
                    Icons.admin_panel_settings_outlined,
                    'Administration',
                    c,
                    [
                      _SubItem(
                        Icons.manage_accounts_rounded,
                        'Router Users',
                        1218,
                      ),
                      _SubItem(
                        Icons.miscellaneous_services_rounded,
                        'IP Services',
                        1219,
                      ),
                      _SubItem(Icons.inventory_2_outlined, 'Packages', 1220),
                      _SubItem(
                        Icons.verified_user_outlined,
                        'Certificates',
                        1221,
                      ),
                    ],
                    expansionKey: 125,
                  ),
                  _item(
                    13,
                    Icons.settings_rounded,
                    'System Control',
                    c,
                    selectCode: -13,
                  ),
                  _item(7, Icons.info_outline_rounded, 'Tentang', c),
                ],
              ),
            ),
            _footer(context, provider, c),
          ],
        ),
      ),
    );
  }

  Widget _header(AppProvider provider, AppC c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.sub.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
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
                    const Text(
                      AppInfo.name,
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Router Management',
                      style: TextStyle(color: c.sub, fontSize: 9),
                    ),
                  ],
                ),
              ),
              Text(
                'v${AppInfo.version}',
                style: TextStyle(color: c.sub, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: AppColors.green, size: 8),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.routerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.txt,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${provider.routerModel} • RouterOS ${provider.routerVersion}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.sub, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, AppC c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 15, 8, 6),
      child: Text(
        label,
        style: TextStyle(
          color: c.sub.withValues(alpha: 0.75),
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _item(
    int index,
    IconData icon,
    String label,
    AppC c, {
    int? selectCode,
  }) {
    final active = widget.selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active
            ? AppColors.cyan.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          minTileHeight: 42,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Icon(icon, color: active ? AppColors.cyan : c.sub, size: 18),
          title: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.cyan : c.txt,
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          trailing: active
              ? Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.cyan,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : null,
          onTap: () => _select(selectCode ?? index),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          dense: true,
        ),
      ),
    );
  }

  Widget _group(
    int index,
    IconData icon,
    String label,
    AppC c,
    List<_SubItem> children, {
    int? expansionKey,
  }) {
    final groupKey = expansionKey ?? index;
    final expanded = _expandedIndex == groupKey;
    final active =
        widget.selectedIndex == index &&
        children.any((item) {
          final subIndex = index == 12 ? item.code - 1200 : item.code % 10;
          return widget.selectedSubIndex == subIndex;
        });
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? AppColors.cyan.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ListTile(
            minTileHeight: 42,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            leading: Icon(
              icon,
              color: active || expanded ? AppColors.cyan : c.sub,
              size: 18,
            ),
            title: Text(
              label,
              style: TextStyle(
                color: active || expanded ? AppColors.cyan : c.txt,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            trailing: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: c.sub,
                size: 19,
              ),
            ),
            onTap: () =>
                setState(() => _expandedIndex = expanded ? null : groupKey),
            dense: true,
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 4, 7),
              child: Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AppColors.cyan.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                child: Column(
                  children: children.map((item) {
                    final subIndex = index == 12
                        ? item.code - 1200
                        : item.code % 10;
                    final subActive =
                        active && widget.selectedSubIndex == subIndex;
                    return Material(
                      color: subActive
                          ? AppColors.cyan.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      child: ListTile(
                        minTileHeight: 36,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 9,
                        ),
                        leading: Icon(
                          item.icon,
                          color: subActive ? AppColors.cyan : c.sub,
                          size: 15,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: subActive ? AppColors.cyan : c.txt,
                            fontSize: 11,
                            fontWeight: subActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: subActive
                            ? const Icon(
                                Icons.circle,
                                color: AppColors.cyan,
                                size: 5,
                              )
                            : null,
                        onTap: () => _select(item.code),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, AppProvider provider, AppC c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.sub.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: provider.toggleTheme,
              icon: Icon(
                provider.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                size: 18,
              ),
              label: Text(provider.isDark ? 'Terang' : 'Gelap'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                provider.disconnect();
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Keluar'),
            ),
          ),
        ],
      ),
    );
  }

  void _select(int code) {
    Navigator.pop(context);
    widget.onSelect(code);
  }
}

class _SubItem {
  final IconData icon;
  final String label;
  final int code;

  const _SubItem(this.icon, this.label, this.code);
}
