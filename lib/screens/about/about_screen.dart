import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/app_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.cyan, AppColors.cyanDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.router_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            AppInfo.name,
            style: TextStyle(
              color: c.txt,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'v${AppInfo.version}',
            style: const TextStyle(
              color: AppColors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppInfo.desc,
            style: TextStyle(color: c.sub, fontSize: 13),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Features list
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fitur',
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...[
                  (
                    'Dashboard',
                    'Monitor CPU, RAM, Suhu realtime',
                    Icons.dashboard_rounded,
                    AppColors.cyan,
                  ),
                  (
                    'Hotspot',
                    'User aktif, voucher, generate',
                    Icons.wifi_rounded,
                    AppColors.green,
                  ),
                  (
                    'PPPoE',
                    'Client aktif, user, profile, tambah user',
                    Icons.cable_rounded,
                    AppColors.orange,
                  ),
                  (
                    'Load Balance',
                    'PCC, ECMP, NTH otomatis',
                    Icons.balance_rounded,
                    AppColors.purple,
                  ),
                  (
                    'Storage',
                    'Cek & kelola file MikroTik',
                    Icons.storage_rounded,
                    AppColors.blue,
                  ),
                  (
                    'IP Manager',
                    'DHCP, pool, address',
                    Icons.lan_rounded,
                    AppColors.red,
                  ),
                ].map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: item.$4.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.$3, color: item.$4, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: TextStyle(
                                  color: c.txt,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                item.$2,
                                style: TextStyle(color: c.sub, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _infoRow('Platform', 'Flutter (Dart)', c),
                _infoRow('Protocol', 'MikroTik API Port 8728', c),
                _infoRow('Compatible', 'RouterOS 6.x & 7.x', c),
                _infoRow('Build', 'Release ${AppInfo.version}', c),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Made with ❤️ for MikroTik',
            style: TextStyle(color: c.sub, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            AppInfo.name,
            style: const TextStyle(
              color: AppColors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, AppC c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: c.sub, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: c.txt,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
