import 'package:flutter/material.dart';
import '../../core/mikrotik_api.dart';
import 'active_screen.dart';
import 'user_screen.dart';
import 'generate_screen.dart';
import 'backup_screen_fixed.dart';

class HotspotScreen extends StatelessWidget {
  final MikrotikApi api;
  final int subIndex;

  const HotspotScreen({super.key, required this.api, required this.subIndex});

  @override
  Widget build(BuildContext context) {
    switch (subIndex) {
      case 0:
        return HotspotActiveScreen(api: api);
      case 1:
        return HotspotUserScreen(api: api);
      case 2:
        return HotspotGenerateScreen(api: api);
      case 3:
        return HotspotBackupScreen(api: api);
      default:
        return HotspotActiveScreen(api: api);
    }
  }
}
