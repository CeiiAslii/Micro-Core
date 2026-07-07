import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';

class DiagnosticToolsScreen extends StatefulWidget {
  final MikrotikApi api;

  const DiagnosticToolsScreen({super.key, required this.api});

  @override
  State<DiagnosticToolsScreen> createState() => _DiagnosticToolsScreenState();
}

class _DiagnosticToolsScreenState extends State<DiagnosticToolsScreen> {
  static const _tools = [
    _DiagnosticTool('Ping', Icons.network_ping_rounded),
    _DiagnosticTool('Traceroute', Icons.route_outlined),
    _DiagnosticTool('DNS Resolve', Icons.dns_outlined),
    _DiagnosticTool('IP Scan', Icons.radar_rounded),
    _DiagnosticTool('Torch', Icons.local_fire_department_outlined),
  ];

  final _target = TextEditingController(text: '8.8.8.8');
  final _interface = TextEditingController();
  final _range = TextEditingController();
  int _selected = 0;
  bool _running = false;
  String? _error;
  List<Map<String, String>> _results = [];

  @override
  void dispose() {
    _target.dispose();
    _interface.dispose();
    _range.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) return;
    final target = _target.text.trim();
    if (_selected < 3 && target.isEmpty) {
      _message('Target wajib diisi', error: true);
      return;
    }
    if (_selected >= 3 && _interface.text.trim().isEmpty) {
      _message('Interface wajib diisi', error: true);
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _results = [];
    });
    try {
      final command = switch (_selected) {
        0 => ['/ping', '=address=$target', '=count=5'],
        1 => ['/tool/traceroute', '=address=$target', '=count=2'],
        2 => ['/resolve', '=domain-name=$target'],
        3 => [
          '/tool/ip-scan',
          '=interface=${_interface.text.trim()}',
          if (_range.text.trim().isNotEmpty)
            '=address-range=${_range.text.trim()}',
          '=duration=5',
        ],
        _ => [
          '/tool/torch',
          '=interface=${_interface.text.trim()}',
          '=duration=5',
        ],
      };
      final rows = await widget.api.queryOrThrow(
        command,
        timeout: const Duration(seconds: 20),
      );
      if (mounted) setState(() => _results = rows);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _select(int index) {
    setState(() {
      _selected = index;
      _results = [];
      _error = null;
      if (index == 2 && _target.text == '8.8.8.8') {
        _target.text = 'google.com';
      } else if (index < 2 && _target.text == 'google.com') {
        _target.text = '8.8.8.8';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    return Column(
      children: [
        _toolBar(c),
        _form(c),
        Expanded(child: _output(c)),
      ],
    );
  }

  Widget _toolBar(AppC c) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
        scrollDirection: Axis.horizontal,
        itemCount: _tools.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final tool = _tools[index];
          final active = index == _selected;
          return Material(
            color: active ? AppColors.cyan.withValues(alpha: 0.14) : c.card,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: _running ? null : () => _select(index),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  border: Border.all(color: active ? AppColors.cyan : c.border),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Icon(
                      tool.icon,
                      color: active ? AppColors.cyan : c.sub,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tool.label,
                      style: TextStyle(
                        color: active ? AppColors.cyan : c.txt,
                        fontSize: 10,
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _form(AppC c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          if (_selected < 3)
            TextField(
              controller: _target,
              enabled: !_running,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _run(),
              style: TextStyle(color: c.txt, fontSize: 11),
              decoration: InputDecoration(
                labelText: _selected == 2 ? 'Domain' : 'Address / Host',
                prefixIcon: const Icon(Icons.public_rounded, size: 17),
              ),
            )
          else if (_selected == 3)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _interface,
                    enabled: !_running,
                    style: TextStyle(color: c.txt, fontSize: 11),
                    decoration: const InputDecoration(
                      labelText: 'Interface *',
                      hintText: 'bridge',
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: _range,
                    enabled: !_running,
                    style: TextStyle(color: c.txt, fontSize: 11),
                    decoration: const InputDecoration(
                      labelText: 'Address Range',
                      hintText: '192.168.1.1-254',
                    ),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: _interface,
              enabled: !_running,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _run(),
              style: TextStyle(color: c.txt, fontSize: 11),
              decoration: const InputDecoration(
                labelText: 'Interface *',
                hintText: 'ether1',
                prefixIcon: Icon(Icons.settings_ethernet_rounded, size: 17),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: FilledButton.icon(
              onPressed: _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 17),
              label: Text(_running ? 'Menjalankan...' : 'Jalankan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _output(AppC c) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.red, fontSize: 11),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_tools[_selected].icon, color: c.sub, size: 30),
            const SizedBox(height: 8),
            Text(
              _running ? 'Menunggu hasil...' : 'Hasil tampil di sini',
              style: TextStyle(color: c.sub, fontSize: 11),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 8, 4),
          child: Row(
            children: [
              Text(
                '${_results.length} hasil',
                style: TextStyle(
                  color: c.sub,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Salin hasil',
                visualDensity: VisualDensity.compact,
                onPressed: _copy,
                icon: const Icon(
                  Icons.copy_rounded,
                  color: AppColors.cyan,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: _results.length,
            itemBuilder: (_, index) => _resultCard(_results[index], index, c),
          ),
        ),
      ],
    );
  }

  Widget _resultCard(Map<String, String> row, int index, AppC c) {
    final title =
        row['host'] ??
        row['address'] ??
        row['name'] ??
        row['ip-address'] ??
        'Result ${index + 1}';
    final summary = row.entries
        .where(
          (entry) =>
              entry.value.isNotEmpty &&
              !{'host', 'address', 'name', 'ip-address'}.contains(entry.key),
        )
        .take(4)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('  |  ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.sub, fontSize: 8.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copy() {
    final output = _results
        .map(
          (row) => row.entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join('\n'),
        )
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: output));
    _message('Hasil disalin');
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

class _DiagnosticTool {
  final String label;
  final IconData icon;

  const _DiagnosticTool(this.label, this.icon);
}
