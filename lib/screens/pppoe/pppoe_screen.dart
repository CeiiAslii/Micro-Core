import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';
import 'active_screen.dart';
import 'user_screen.dart';
import 'profile_screen.dart';
import 'add_user_screen.dart';
import 'server_screen.dart';

class PppoeScreen extends StatefulWidget {
  final MikrotikApi api;
  final int subIndex;

  const PppoeScreen({super.key, required this.api, required this.subIndex});

  @override
  State<PppoeScreen> createState() => _PppoeScreenState();
}

class _PppoeScreenState extends State<PppoeScreen> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.subIndex.clamp(0, 4);
  }

  @override
  void didUpdateWidget(covariant PppoeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subIndex != widget.subIndex) {
      _selected = widget.subIndex.clamp(0, 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    return Column(
      children: [
        _tabs(c),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() {
    switch (_selected) {
      case 0:
        return PppoeActiveScreen(api: widget.api);
      case 1:
        return PppoeUserScreen(api: widget.api);
      case 2:
        return PppoeProfileScreen(api: widget.api);
      case 3:
        return PppoeAddUserScreen(api: widget.api);
      case 4:
        return PppoeServerScreen(api: widget.api);
      default:
        return PppoeActiveScreen(api: widget.api);
    }
  }

  Widget _tabs(AppC c) {
    const tabs = [
      (0, 'Active', Icons.link_rounded),
      (1, 'Secrets', Icons.manage_accounts_rounded),
      (2, 'Profiles', Icons.speed_rounded),
      (4, 'Servers', Icons.router_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: c.card2.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: tabs.map((tab) {
                  final selected =
                      _selected == tab.$1 || (_selected == 3 && tab.$1 == 1);
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selected = tab.$1),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.orange
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tab.$3,
                              size: 14,
                              color: selected ? AppColors.darkBg : c.sub,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              tab.$2,
                              style: TextStyle(
                                color: selected ? AppColors.darkBg : c.txt,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 7),
          IconButton.filled(
            tooltip: 'Tambah PPP Secret',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _selected = 3),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
