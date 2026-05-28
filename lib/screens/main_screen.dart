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
import 'about/about_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _subIndex = 0;

  Widget _getScreen() {
    final api = context.read<AppProvider>().api;
    if (api == null) return const SizedBox();

    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(api: api);
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
        return const AboutScreen();
      default:
        return DashboardScreen(api: api);
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
        return 'PPPoE';
      case 4:
        return 'Load Balance';
      case 5:
        return 'Storage';
      case 6:
        return 'About';
      default:
        return 'Core Monitor';
    }
  }

  void _onMenuSelect(int code) {
    setState(() {
      _selectedIndex = code ~/ 10 == 0 ? code : code ~/ 10;
      _subIndex = code % 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final dark = provider.isDark;
    final c = AppC(dark);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: c.txt),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: AppColors.green, size: 8),
                  const SizedBox(width: 6),
                  Text(
                    provider.routerName,
                    style: TextStyle(
                      color: c.txt,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(_getTitle(), style: TextStyle(color: c.sub, fontSize: 13)),
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
              await context.read<AppProvider>().logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
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
