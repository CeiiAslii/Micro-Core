import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_provider.dart';
import '../widgets/drawer_widget.dart';
import 'login_screen.dart';

// Import semua screen
import 'dashboard/dashboard_screen.dart';
import 'ip/ip_screen.dart';
import 'hotspot/hotspot_screen.dart';
import 'pppoe/pppoe_screen.dart';
import 'loadbalance/loadbalance_screen.dart';
import 'storage/storage_screen.dart';
import 'interface/interface_screen.dart';
import 'logs/router_log_screen.dart';
import 'health/health_center_screen.dart';
import 'terminal/safe_terminal_screen.dart';
import 'network_tools/network_tools_screen.dart';
import 'winbox/router_config_screen.dart';
import 'system/system_control_screen.dart';
import 'tools/diagnostic_tools_screen.dart';
import 'about/about_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _subIndex = 0;
  bool _healthMonitorStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_healthMonitorStarted) {
      context.read<AppProvider>().startRouterHealthMonitor();
      _healthMonitorStarted = true;
    }
  }

  @override
  void dispose() {
    context.read<AppProvider>().stopRouterHealthMonitor();
    super.dispose();
  }

  Widget _getScreen() {
    final api = context.read<AppProvider>().api;
    if (api == null) return const SizedBox();

    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          api: api,
          onOpenInterface: () => setState(() {
            _selectedIndex = 6;
            _subIndex = 0;
          }),
        );
      case 1:
        return IpScreen(api: api, subIndex: _subIndex);
      case 2:
        return HotspotScreen(api: api, subIndex: _subIndex);
      case 3:
        return PppoeScreen(api: api, subIndex: _subIndex);
      case 4:
        return LoadBalanceScreen(api: api);
      case 5:
        return StorageScreen(api: api);
      case 6:
        return InterfaceScreen(api: api, subIndex: _subIndex);
      case 7:
        return const AboutScreen();
      case 8:
        return RouterLogScreen(api: api);
      case 9:
        return HealthCenterScreen(api: api);
      case 10:
        return SafeTerminalScreen(api: api);
      case 11:
        return NetworkToolsScreen(api: api);
      case 12:
        return RouterConfigScreen(api: api, moduleIndex: _subIndex);
      case 13:
        return SystemControlScreen(api: api);
      case 14:
        return DiagnosticToolsScreen(api: api);
      default:
        return DashboardScreen(
          api: api,
          onOpenInterface: () => setState(() {
            _selectedIndex = 6;
            _subIndex = 0;
          }),
        );
    }
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'IP';
      case 2:
        return 'Hotspot';
      case 3:
        return 'PPP';
      case 4:
        return 'Load Balance';
      case 5:
        return 'Storage';
      case 6:
        return _subIndex == 1 ? 'Status Interface' : 'Traffic Interface';
      case 7:
        return 'About';
      case 8:
        return 'Log Router';
      case 9:
        return 'Health Center';
      case 10:
        return 'RouterOS Terminal';
      case 11:
        return 'Firewall';
      case 12:
        return _routerConfigTitle(_subIndex);
      case 13:
        return 'System Control';
      case 14:
        return 'Diagnostics';
      default:
        return 'Core Monitor';
    }
  }

  String _getCategory() {
    if (_selectedIndex == 12) return _routerConfigCategory(_subIndex);
    return switch (_selectedIndex) {
      0 || 6 || 9 => 'Monitoring',
      1 || 4 || 11 => 'Jaringan',
      2 || 3 => 'Akses Pengguna',
      5 || 8 || 10 || 14 => 'Tools',
      7 || 13 => 'Sistem',
      _ => 'Core Monitor',
    };
  }

  String _routerConfigCategory(int index) {
    if (index <= 3) return 'Switching & VLAN';
    if (index <= 7) return 'VPN';
    if (index <= 12) return 'Routing & IP';
    if (index <= 15 || index >= 27 && index <= 29) return 'QoS & Monitor';
    if (index <= 17) return 'Automation';
    if (index <= 20) return 'Administration';
    if (index <= 26) return 'Switching & VLAN';
    return 'Router Config';
  }

  void _onMenuSelect(int code) {
    setState(() {
      if (code >= 1200 && code < 1300) {
        _selectedIndex = 12;
        _subIndex = code - 1200;
        return;
      }
      if (code < 0) {
        _selectedIndex = -code;
        _subIndex = 0;
        return;
      }
      _selectedIndex = code ~/ 10 == 0 ? code : code ~/ 10;
      _subIndex = code % 10;
    });
  }

  String _routerConfigTitle(int index) {
    const titles = [
      'Bridge',
      'Bridge Ports',
      'Bridge VLANs',
      'VLAN',
      'WireGuard',
      'WireGuard Peers',
      'IPsec Peers',
      'IPsec Identity',
      'Routes',
      'Routing Tables',
      'DNS Static',
      'ARP',
      'Neighbors',
      'Simple Queue',
      'Netwatch',
      'SNMP Community',
      'Scripts',
      'Scheduler',
      'Router Users',
      'IP Services',
      'Packages',
      'Certificates',
      'Bridge Filters',
      'Bridge NAT',
      'Bridge Hosts',
      'Bridge MDB',
      'Bridge MSTIs',
      'Bridge MST Overrides',
      'Interface Queues',
      'Queue Tree',
      'Queue Types',
    ];
    return index >= 0 && index < titles.length
        ? titles[index]
        : 'Router Config';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final dark = provider.isDark;
    final c = AppC(dark);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: c.txt),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTitle(),
              style: TextStyle(
                color: c.txt,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Icon(Icons.circle, color: _healthColor(provider), size: 7),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '${_healthStatus(provider)} | ${_getCategory()} | ${provider.routerName}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.sub, fontSize: 10),
                  ),
                ),
              ],
            ),
            Text(
              _healthDetail(provider),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.sub, fontSize: 9),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.power_settings_new_rounded,
              color: AppColors.red,
            ),
            onPressed: () => _confirmLogout(context, c),
          ),
        ],
      ),
      drawer: DrawerWidget(
        selectedIndex: _selectedIndex,
        selectedSubIndex: _subIndex,
        onSelect: _onMenuSelect,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey('$_selectedIndex-$_subIndex'),
          child: _getScreen(),
        ),
      ),
    );
  }

  Color _healthColor(AppProvider provider) {
    if (provider.routerOnline) return AppColors.green;
    if (provider.waitingReconnect) return AppColors.orange;
    return AppColors.red;
  }

  String _healthStatus(AppProvider provider) {
    if (provider.routerOnline) return 'Online';
    if (provider.waitingReconnect) return 'Reconnect';
    return 'Offline';
  }

  String _healthDetail(AppProvider provider) {
    final updated = _formatHealthTime(provider.healthUpdatedAt);
    if (provider.routerOnline) {
      final latency = provider.apiLatency;
      final latencyText = latency == null
          ? 'Ping --ms'
          : 'Ping ${latency.inMilliseconds}ms';
      return '$latencyText - update $updated';
    }
    if (provider.waitingReconnect) {
      return 'Coba sambung ulang - update $updated';
    }
    return 'Tidak terhubung - update $updated';
  }

  String _formatHealthTime(DateTime? time) {
    if (time == null) return '--:--';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }

  void _confirmLogout(BuildContext context, AppC c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: TextStyle(color: c.txt)),
        content: Text(
          'Disconnect dari router?',
          style: TextStyle(color: c.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: c.sub)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Logout — tidak auto-login lagi
              final provider = this.context.read<AppProvider>();
              await provider.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                this.context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false, // hapus semua history
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
