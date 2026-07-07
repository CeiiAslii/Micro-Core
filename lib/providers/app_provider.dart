import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/mikrotik_api.dart';

class SavedRouter {
  final String id;
  final String name;
  final String host;
  final String username;
  final String password;
  final String lastConnected;

  SavedRouter({
    required this.id,
    required this.name,
    required this.host,
    required this.username,
    required this.password,
    required this.lastConnected,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'username': username,
    'lastConnected': lastConnected,
  };

  factory SavedRouter.fromJson(Map<String, dynamic> j) => SavedRouter(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    host: j['host'] ?? '',
    username: j['username'] ?? '',
    password: j['password'] ?? '',
    lastConnected: j['lastConnected'] ?? '',
  );
}

class AppProvider extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();

  bool _isDark = true;
  MikrotikApi? _api;
  String _routerName = '-';
  String _routerModel = '-';
  String _routerVersion = '-';
  List<SavedRouter> _savedRouters = [];
  List<Map<String, String>>? _dhcpLeaseCache;
  DateTime? _dhcpLeaseCachedAt;
  List<Map<String, String>>? _interfaceCache;
  DateTime? _interfaceCachedAt;
  Timer? _healthTimer;
  int _healthFailures = 0;
  bool _routerOnline = false;
  bool _checkingHealth = false;
  bool _waitingReconnect = false;
  Duration? _apiLatency;
  DateTime? _healthUpdatedAt;
  String? _healthError;

  bool get isDark => _isDark;
  MikrotikApi? get api => _api;
  String get routerName => _routerName;
  String get routerModel => _routerModel;
  String get routerVersion => _routerVersion;
  bool get isConnected => _api?.isConnected ?? false;
  List<SavedRouter> get savedRouters => _savedRouters;
  bool get routerOnline => _routerOnline;
  bool get waitingReconnect => _waitingReconnect;
  Duration? get apiLatency => _apiLatency;
  DateTime? get healthUpdatedAt => _healthUpdatedAt;
  String? get healthError => _healthError;

  AppProvider() {
    _init();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    _isDark = p.getBool('isDark') ?? true;
    await _loadSavedRouters();
    notifyListeners();
  }

  // ── Theme ───────────────────────────────────────────
  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('isDark', _isDark);
  }

  // ── Router connection ────────────────────────────────
  void setApi(MikrotikApi api) {
    clearRouterCaches();
    _stopHealthMonitor();
    _api = api;
    _routerOnline = api.isConnected;
    _healthFailures = 0;
    _healthError = null;
    _apiLatency = null;
    _healthUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void setRouterInfo({
    required String name,
    required String model,
    required String version,
  }) {
    _routerName = name;
    _routerModel = model;
    _routerVersion = version;
    notifyListeners();
  }

  // Logout — TIDAK auto-login lagi
  Future<void> logout() async {
    _api?.disconnect();
    _api = null;
    _stopHealthMonitor();
    clearRouterCaches();
    _routerName = '-';
    _routerModel = '-';
    _routerVersion = '-';
    notifyListeners();
  }

  void disconnect() => logout();

  void startRouterHealthMonitor() {
    if (_api == null || _healthTimer != null || _checkingHealth) return;
    _scheduleHealthCheck(Duration.zero);
  }

  void stopRouterHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  void _scheduleHealthCheck(Duration delay) {
    _healthTimer?.cancel();
    _healthTimer = Timer(delay, _checkRouterHealth);
  }

  Future<void> _checkRouterHealth() async {
    final api = _api;
    if (api == null || _checkingHealth) return;

    _checkingHealth = true;
    final stopwatch = Stopwatch()..start();
    try {
      await api.queryOrThrow([
        '/system/identity/print',
        '=.proplist=name',
      ], timeout: const Duration(seconds: 5));
      stopwatch.stop();
      api.isConnected = true;
      _routerOnline = true;
      _waitingReconnect = false;
      _healthFailures = 0;
      _apiLatency = stopwatch.elapsed;
      _healthUpdatedAt = DateTime.now();
      _healthError = null;
      notifyListeners();
      _scheduleHealthCheck(const Duration(seconds: 30));
    } catch (error) {
      stopwatch.stop();
      if (!identical(api, _api)) return;
      api.isConnected = false;
      _routerOnline = false;
      _healthFailures++;
      _waitingReconnect = true;
      _apiLatency = null;
      _healthUpdatedAt = DateTime.now();
      _healthError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      _scheduleHealthCheck(_reconnectDelay());
    } finally {
      _checkingHealth = false;
    }
  }

  Duration _reconnectDelay() {
    if (_healthFailures <= 1) return const Duration(seconds: 5);
    if (_healthFailures == 2) return const Duration(seconds: 15);
    return const Duration(seconds: 30);
  }

  void _stopHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = null;
    _checkingHealth = false;
    _waitingReconnect = false;
    _routerOnline = false;
    _apiLatency = null;
    _healthUpdatedAt = null;
    _healthError = null;
    _healthFailures = 0;
  }

  Future<List<Map<String, String>>> cachedDhcpLeases({
    Duration maxAge = const Duration(minutes: 1),
  }) async {
    final cached = _dhcpLeaseCache;
    final cachedAt = _dhcpLeaseCachedAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < maxAge) {
      return cached;
    }

    final rows =
        await _api?.query([
          '/ip/dhcp-server/lease/print',
          '=.proplist=.id,mac-address,host-name,comment',
        ]) ??
        const <Map<String, String>>[];
    _dhcpLeaseCache = rows;
    _dhcpLeaseCachedAt = DateTime.now();
    return rows;
  }

  Future<List<Map<String, String>>> cachedInterfaces({
    Duration maxAge = const Duration(seconds: 30),
  }) async {
    final cached = _interfaceCache;
    final cachedAt = _interfaceCachedAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < maxAge) {
      return cached;
    }

    final rows =
        await _api?.query(['/interface/print']) ??
        const <Map<String, String>>[];
    _interfaceCache = rows;
    _interfaceCachedAt = DateTime.now();
    return rows;
  }

  void clearRouterCaches() {
    _dhcpLeaseCache = null;
    _dhcpLeaseCachedAt = null;
    _interfaceCache = null;
    _interfaceCachedAt = null;
  }

  // ── Saved Routers ────────────────────────────────────
  Future<void> _loadSavedRouters() async {
    final p = await SharedPreferences.getInstance();
    final json = p.getString('savedRouters') ?? '[]';
    try {
      final list = jsonDecode(json) as List;
      final routers = <SavedRouter>[];
      var migratedPlainPasswords = false;

      for (final item in list) {
        final data = item as Map<String, dynamic>;
        final router = SavedRouter.fromJson(data);
        var password = await _readRouterPassword(router.id);
        final plainPassword = (data['password'] ?? '').toString();
        if (password.isEmpty && plainPassword.isNotEmpty) {
          password = plainPassword;
          await _writeRouterPassword(router.id, plainPassword);
          migratedPlainPasswords = true;
        }
        routers.add(
          SavedRouter(
            id: router.id,
            name: router.name,
            host: router.host,
            username: router.username,
            password: password,
            lastConnected: router.lastConnected,
          ),
        );
      }
      _savedRouters = routers;
      if (migratedPlainPasswords) await _persistRouters();
    } catch (_) {
      _savedRouters = [];
    }
  }

  Future<void> _persistRouters() async {
    final p = await SharedPreferences.getInstance();
    final json = jsonEncode(_savedRouters.map((r) => r.toJson()).toList());
    await p.setString('savedRouters', json);
  }

  Future<void> saveRouter({
    required String name,
    required String host,
    required String username,
    required String password,
  }) async {
    // Update jika sudah ada (sama host+username)
    final idx = _savedRouters.indexWhere(
      (r) => r.host == host && r.username == username,
    );
    final id = idx >= 0
        ? _savedRouters[idx].id
        : '${DateTime.now().millisecondsSinceEpoch}';
    await _writeRouterPassword(id, password);
    final router = SavedRouter(
      id: id,
      name: name,
      host: host,
      username: username,
      password: password,
      lastConnected: DateTime.now().toIso8601String(),
    );
    if (idx >= 0) {
      _savedRouters[idx] = router;
    } else {
      _savedRouters.insert(0, router);
    }
    await _persistRouters();
    notifyListeners();
  }

  Future<void> updateRouterName(
    String host,
    String username,
    String newName,
  ) async {
    final idx = _savedRouters.indexWhere(
      (r) => r.host == host && r.username == username,
    );
    if (idx >= 0) {
      final old = _savedRouters[idx];
      _savedRouters[idx] = SavedRouter(
        id: old.id,
        name: newName,
        host: old.host,
        username: old.username,
        password: old.password,
        lastConnected: old.lastConnected,
      );
      await _persistRouters();
      notifyListeners();
    }
  }

  Future<void> updateRouter({
    required String id,
    required String name,
    required String host,
    required String username,
    required String password,
  }) async {
    final idx = _savedRouters.indexWhere((r) => r.id == id);
    if (idx < 0) return;

    final old = _savedRouters[idx];
    final updated = SavedRouter(
      id: old.id,
      name: name,
      host: host,
      username: username,
      password: password,
      lastConnected: old.lastConnected,
    );
    _savedRouters[idx] = updated;
    await _writeRouterPassword(id, password);
    await _persistRouters();
    notifyListeners();
  }

  Future<void> deleteRouter(String id) async {
    _savedRouters.removeWhere((r) => r.id == id);
    await _deleteRouterPassword(id);
    await _persistRouters();
    notifyListeners();
  }

  String _routerPasswordKey(String id) => 'router_password_$id';

  Future<String> _readRouterPassword(String id) async {
    if (id.isEmpty) return '';
    try {
      return await _secureStorage.read(key: _routerPasswordKey(id)) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _writeRouterPassword(String id, String password) async {
    if (id.isEmpty) return;
    await _secureStorage.write(key: _routerPasswordKey(id), value: password);
  }

  Future<void> _deleteRouterPassword(String id) async {
    if (id.isEmpty) return;
    await _secureStorage.delete(key: _routerPasswordKey(id));
  }

  @override
  void dispose() {
    _stopHealthMonitor();
    super.dispose();
  }
}
