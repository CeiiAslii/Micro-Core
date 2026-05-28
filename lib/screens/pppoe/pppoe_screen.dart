import 'package:flutter/material.dart';
import '../../core/mikrotik_api.dart';

class PppoeScreen extends StatelessWidget {
  final MikrotikApi api;
  final int subIndex;
  const PppoeScreen({super.key, required this.api, required this.subIndex});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'PPPoE Screen - sub: $subIndex',
      style: const TextStyle(color: Colors.white),
    ),
  );
}
