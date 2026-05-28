import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
    'id':            id,
    'name':          name,
    'host':          host,
    'username':      username,
    'password':      password,
    'lastConnected': lastConnected,
  };

  factory SavedRouter.fromJson(Map<String, dynamic> j) => SavedRouter(
    id:            j['id'] ?? '',
    name:          j['name'] ?? '',
    host:          j['host'] ?? '',
    username:      j['username'] ?? '',
    password:      j['password'] ?? '',
    lastConnected: j['lastConnected'] ?? '',
  );
}

class AppProvider extends ChangeNotifier {
  bool _isDark = true;
  MikrotikApi? _api;
  String _routerName    = '-';
  String _routerModel   = '-';
  String _routerVersion = '-';
  List<SavedRouter> _savedRouters = [];

  bool get isDark           => _isDark;
  MikrotikApi? get api      => _api;
  String get routerName     => _routerName;
  String get routerModel    => _routerModel;
  String get routerVersion  => _routerVersion;
  bool get isConnected      => _api?.isConnected ?? false;
  List<SavedRouter> get savedRouters => _savedRouters;

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
    _api = api;
    notifyListeners();
  }

  void setRouterInfo({
    required String name,
    required String model,
    required String version,
  }) {
    _routerName    = name;
    _routerModel   = model;
    _routerVersion = version;
    notifyListeners();
  }

  // Logout — TIDAK auto-login lagi
  Future<void> logout() async {
    _api?.disconnect();
    _api           = null;
    _routerName    = '-';
    _routerModel   = '-';
    _routerVersion = '-';
    notifyListeners();
  }

  void disconnect() => logout();

  // ── Saved Routers ────────────────────────────────────
  Future<void> _loadSavedRouters() async {
    final p    = await SharedPreferences.getInstance();
    final json = p.getString('savedRouters') ?? '[]';
    try {
      final list = jsonDecode(json) as List;
      _savedRouters = list
          .map((e) => SavedRouter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _savedRouters = [];
    }
  }

  Future<void> _persistRouters() async {
    final p    = await SharedPreferences.getInstance();
    final json = jsonEncode(
        _savedRouters.map((r) => r.toJson()).toList());
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
        (r) => r.host == host && r.username == username);
    final router = SavedRouter(
      id:            '${DateTime.now().millisecondsSinceEpoch}',
      name:          name,
      host:          host,
      username:      username,
      password:      password,
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

  Future<void> updateRouterName(String host,
      String username, String newName) async {
    final idx = _savedRouters.indexWhere(
        (r) => r.host == host && r.username == username);
    if (idx >= 0) {
      final old = _savedRouters[idx];
      _savedRouters[idx] = SavedRouter(
        id:            old.id,
        name:          newName,
        host:          old.host,
        username:      old.username,
        password:      old.password,
        lastConnected: old.lastConnected,
      );
      await _persistRouters();
      notifyListeners();
    }
  }

  Future<void> deleteRouter(String id) async {
    _savedRouters.removeWhere((r) => r.id == id);
    await _persistRouters();
    notifyListeners();
  }
}