import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';

class DrawerWidget extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onSelect;

  const DrawerWidget({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget> {
  // Track expanded sub menu
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final dark = provider.isDark;
    final c = AppC(dark);

    return Drawer(
      backgroundColor: c.surface,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF003A4D), AppColors.cyanDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + App name
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.router_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppInfo.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'v${AppInfo.version}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),

                // Router info
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.routerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${provider.routerModel}  •  RouterOS v${provider.routerVersion}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 14),

                // Theme toggle
                GestureDetector(
                  onTap: () => provider.toggleTheme(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: dark ? Colors.amber : Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dark ? 'Mode Terang' : 'Mode Gelap',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Mini toggle visual
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 18,
                          decoration: BoxDecoration(
                            color: dark ? Colors.amber : Colors.white30,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: dark
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Menu Items ───────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 1. Dashboard
                _menuItem(
                  context: context,
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  c: c,
                ),

                // 2. IP
                _menuGroup(
                  context: context,
                  index: 1,
                  icon: Icons.lan_rounded,
                  label: 'IP',
                  c: c,
                  subItems: [
                    _SubItem(
                      Icons.grid_view_rounded,
                      'IP Address',
                      () => _nav(context, 1, 0),
                    ),
                    _SubItem(
                      Icons.pool_rounded,
                      'IP Pool',
                      () => _nav(context, 1, 1),
                    ),
                    _SubItem(
                      Icons.router_rounded,
                      'DHCP Server',
                      () => _nav(context, 1, 2),
                    ),
                    _SubItem(
                      Icons.dns_rounded,
                      'DHCP Lease',
                      () => _nav(context, 1, 3),
                    ),
                  ],
                ),

                // 3. Hotspot
                _menuGroup(
                  context: context,
                  index: 2,
                  icon: Icons.wifi_rounded,
                  label: 'Hotspot',
                  c: c,
                  subItems: [
                    _SubItem(
                      Icons.people_rounded,
                      'User Aktif',
                      () => _nav(context, 2, 0),
                    ),
                    _SubItem(
                      Icons.list_alt_rounded,
                      'Semua Voucher',
                      () => _nav(context, 2, 1),
                    ),
                    _SubItem(
                      Icons.add_card_rounded,
                      'Generate Voucher',
                      () => _nav(context, 2, 2),
                    ),
                    _SubItem(
                      Icons.backup_rounded,
                      'Backup & Restore',
                      () => _nav(context, 2, 3),
                    ),
                  ],
                ),

                // 4. PPPoE
                _menuGroup(
                  context: context,
                  index: 3,
                  icon: Icons.cable_rounded,
                  label: 'PPPoE',
                  c: c,
                  subItems: [
                    _SubItem(
                      Icons.people_alt_rounded,
                      'Client Aktif',
                      () => _nav(context, 3, 0),
                    ),
                    _SubItem(
                      Icons.manage_accounts_rounded,
                      'Semua User',
                      () => _nav(context, 3, 1),
                    ),
                    _SubItem(
                      Icons.speed_rounded,
                      'Profile',
                      () => _nav(context, 3, 2),
                    ),
                    _SubItem(
                      Icons.person_add_rounded,
                      'Tambah User',
                      () => _nav(context, 3, 3),
                    ),
                  ],
                ),

                // 5. Load Balance
                _menuItem(
                  context: context,
                  index: 4,
                  icon: Icons.balance_rounded,
                  label: 'Load Balance',
                  c: c,
                ),

                // 6. Storage
                _menuItem(
                  context: context,
                  index: 5,
                  icon: Icons.storage_rounded,
                  label: 'Storage',
                  c: c,
                ),

                // 7. About
                _menuItem(
                  context: context,
                  index: 6,
                  icon: Icons.info_rounded,
                  label: 'About',
                  c: c,
                ),

                const SizedBox(height: 8),
                Divider(color: c.sub.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 8),

                // Logout
                _logoutTile(context, c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _nav(BuildContext context, int menuIdx, int subIdx) {
    Navigator.pop(context);
    widget.onSelect(menuIdx * 10 + subIdx);
  }

  Widget _menuItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required AppC c,
  }) {
    final active = widget.selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? AppColors.cyan.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: active ? AppColors.cyan : c.sub, size: 22),
        title: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.cyan : c.txt,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          widget.onSelect(index);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
      ),
    );
  }

  Widget _menuGroup({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required AppC c,
    required List<_SubItem> subItems,
  }) {
    final expanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: expanded
            ? AppColors.cyan.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: expanded
            ? Border.all(color: AppColors.cyan.withValues(alpha: 0.15))
            : null,
      ),
      child: Column(
        children: [
          // Header group
          ListTile(
            leading: Icon(
              icon,
              color: expanded ? AppColors.cyan : c.sub,
              size: 22,
            ),
            title: Text(
              label,
              style: TextStyle(
                color: expanded ? AppColors.cyan : c.txt,
                fontWeight: expanded ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            trailing: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: expanded ? AppColors.cyan : c.sub,
                size: 20,
              ),
            ),
            onTap: () {
              setState(() {
                _expandedIndex = expanded ? null : index;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            dense: true,
          ),

          // Sub items
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: subItems
                  .map(
                    (item) => Container(
                      margin: const EdgeInsets.only(
                        left: 16,
                        right: 4,
                        bottom: 2,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item.icon,
                            color: AppColors.cyan,
                            size: 15,
                          ),
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(color: c.txt, fontSize: 13),
                        ),
                        onTap: () {
                          setState(() => _expandedIndex = null);
                          item.onTap();
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  )
                  .toList(),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _logoutTile(BuildContext context, AppC c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        leading: const Icon(
          Icons.power_settings_new_rounded,
          color: AppColors.red,
          size: 22,
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            color: AppColors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: c.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text('Logout', style: TextStyle(color: c.txt)),
              content: Text(
                'Yakin mau disconnect dari router?',
                style: TextStyle(color: c.sub),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: TextStyle(color: c.sub)),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.read<AppProvider>().disconnect();
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/login');
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
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
      ),
    );
  }
}

class _SubItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SubItem(this.icon, this.label, this.onTap);
}
