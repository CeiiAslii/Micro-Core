import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/core_monitor_logo.jpg',
                width: 112,
                height: 112,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppInfo.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.txt,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Core Monitor v${AppInfo.version}',
            style: const TextStyle(
              color: AppColors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _section(
            c,
            title: 'Tentang Aplikasi',
            child: Text(
              'Core Monitor membantu memantau dan mengelola router MikroTik '
              'langsung dari satu aplikasi yang ringkas.',
              style: TextStyle(color: c.sub, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          _section(
            c,
            title: 'Fitur Utama',
            child: Column(
              children: [
                _feature(
                  Icons.dashboard_outlined,
                  'Monitoring router dan interface',
                  AppColors.cyan,
                  c,
                ),
                _feature(
                  Icons.wifi_rounded,
                  'Manajemen Hotspot dan voucher',
                  AppColors.green,
                  c,
                ),
                _feature(
                  Icons.cable_rounded,
                  'Client, user, dan profile PPPoE',
                  AppColors.orange,
                  c,
                ),
                _feature(
                  Icons.lan_outlined,
                  'IP Address, Pool, dan DHCP',
                  AppColors.blue,
                  c,
                ),
                _feature(
                  Icons.storage_outlined,
                  'File, backup, dan storage MikroTik',
                  AppColors.purple,
                  c,
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _section(
            c,
            title: 'Informasi',
            child: Column(
              children: [
                _info('Developer', 'CeiiAslii', c),
                _info('Platform', 'Flutter / Android', c),
                _info('Protokol', 'RouterOS API + FTP', c),
                _info('Kompatibel', 'RouterOS 6 dan 7', c),
                _info('Versi', AppInfo.version, c, last: true),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _section(
            c,
            title: 'Kontak Developer',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _contactButton(
                  context,
                  icon: Icons.code_rounded,
                  label: 'GitHub',
                  color: c.txt,
                  uri: Uri.parse('https://github.com/CeiiAslii'),
                ),
                _contactButton(
                  context,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  color: AppColors.orange,
                  uri: Uri(
                    scheme: 'mailto',
                    path: 'ceiingap@gmail.com',
                    queryParameters: {'subject': 'Core Monitor'},
                  ),
                ),
                _contactButton(
                  context,
                  icon: Icons.send_rounded,
                  label: 'Telegram',
                  color: AppColors.blue,
                  uri: Uri.parse('https://t.me/CoreeNext'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Dibuat untuk monitoring jaringan yang lebih sederhana.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.sub, fontSize: 11),
          ),
          const SizedBox(height: 5),
          const Text(
            'CeiiAslii',
            style: TextStyle(
              color: AppColors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(AppC c, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.txt,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _feature(
    IconData icon,
    String text,
    Color color,
    AppC c, {
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 9),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: TextStyle(color: c.txt, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value, AppC c, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: c.sub, fontSize: 11)),
          ),
          Text(
            value,
            style: TextStyle(
              color: c.txt,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Uri uri,
  }) {
    return InkWell(
      onTap: () => _openLink(context, uri),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tautan tidak dapat dibuka')),
      );
    }
  }
}
