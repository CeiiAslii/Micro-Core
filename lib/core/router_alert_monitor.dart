import 'dart:async';

import 'package:flutter/services.dart';

import 'mikrotik_api.dart';

class RouterAlertMonitor {
  static const _channel = MethodChannel('core_monitor/downloads');
  static const _cooldown = Duration(minutes: 10);
  static const _checkInterval = Duration(seconds: 30);
  static const _resumeGrace = Duration(seconds: 12);
  static const _offlineFailureThreshold = 4;

  final MikrotikApi api;
  Timer? _timer;
  Timer? _resumeTimer;
  bool _checking = false;
  bool _running = false;
  int _consecutiveFailures = 0;
  final Map<String, DateTime> _lastAlerts = {};
  final Map<String, bool> _interfaceRunning = {};

  RouterAlertMonitor(this.api);

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _tryChannelCall('requestNotificationPermission');
    _timer ??= Timer.periodic(_checkInterval, (_) => check());
  }

  void pause() {
    _running = false;
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_running) return;
    _running = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeGrace, () {
      if (!_running) return;
      check();
      _timer ??= Timer.periodic(_checkInterval, (_) => check());
    });
  }

  void dispose() {
    pause();
  }

  Future<void> check() async {
    if (!_running || _checking) return;
    _checking = true;
    try {
      final results = await Future.wait([
        api.queryOrThrow([
          '/system/resource/print',
        ], timeout: const Duration(seconds: 12)),
        api.queryOrThrow([
          '/interface/print',
          '=.proplist=name,type,running,disabled',
        ], timeout: const Duration(seconds: 12)),
      ]);
      _consecutiveFailures = 0;
      _checkResources(results[0]);
      _checkInterfaces(results[1]);
    } catch (_) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _offlineFailureThreshold) {
        await _notify(
          'router-offline',
          1001,
          'Router tidak terhubung',
          'Core Monitor gagal menghubungi ${api.host}:${api.port}.',
        );
      }
    } finally {
      _checking = false;
    }
  }

  void _checkResources(List<Map<String, String>> rows) {
    if (rows.isEmpty) return;
    final data = rows.first;
    final cpu = int.tryParse(data['cpu-load'] ?? '0') ?? 0;
    final totalMemory = int.tryParse(data['total-memory'] ?? '0') ?? 0;
    final freeMemory = int.tryParse(data['free-memory'] ?? '0') ?? 0;
    final totalStorage = int.tryParse(data['total-hdd-space'] ?? '0') ?? 0;
    final freeStorage = int.tryParse(data['free-hdd-space'] ?? '0') ?? 0;
    final ram = totalMemory > 0
        ? (((totalMemory - freeMemory) / totalMemory) * 100).round()
        : 0;
    final storage = totalStorage > 0
        ? (((totalStorage - freeStorage) / totalStorage) * 100).round()
        : 0;

    if (cpu >= 85) {
      _notify('cpu-high', 1002, 'CPU MikroTik tinggi', 'Penggunaan CPU $cpu%.');
    }
    if (ram >= 90) {
      _notify('ram-high', 1003, 'RAM MikroTik tinggi', 'Penggunaan RAM $ram%.');
    }
    if (storage >= 90) {
      _notify(
        'storage-high',
        1004,
        'Storage MikroTik hampir penuh',
        'Penggunaan storage $storage%.',
      );
    }
  }

  void _checkInterfaces(List<Map<String, String>> rows) {
    for (final row in rows) {
      final name = row['name'] ?? '';
      final type = (row['type'] ?? '').toLowerCase();
      final disabled = row['disabled'] == 'true';
      final running = row['running'] == 'true';
      final shouldMonitor =
          !disabled &&
          name.isNotEmpty &&
          (type.contains('ether') ||
              type.contains('wlan') ||
              type.contains('wifi'));
      if (!shouldMonitor) continue;

      final previous = _interfaceRunning[name];
      _interfaceRunning[name] = running;
      if (previous == true && !running) {
        _notify(
          'interface-$name',
          2000 + name.hashCode.abs().remainder(100000),
          'Interface down',
          '$name pada ${api.host}:${api.port} tidak aktif.',
        );
      }
    }
  }

  Future<void> _notify(String key, int id, String title, String body) async {
    final now = DateTime.now();
    final last = _lastAlerts[key];
    if (last != null && now.difference(last) < _cooldown) return;
    _lastAlerts[key] = now;
    await _tryChannelCall('showNotification', {
      'id': id,
      'title': title,
      'body': body,
    });
  }

  Future<void> _tryChannelCall(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
    } on PlatformException {
    }
  }
}
