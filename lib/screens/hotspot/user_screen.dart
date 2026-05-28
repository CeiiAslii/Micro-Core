import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';

class HotspotUserScreen extends StatefulWidget {
  final MikrotikApi api;
  const HotspotUserScreen({super.key, required this.api});

  @override
  State<HotspotUserScreen> createState() => _HotspotUserScreenState();
}

class _HotspotUserScreenState extends State<HotspotUserScreen> {
  List<Map<String, String>> _users = [];
  List<Map<String, String>> _profiles = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _backing = false;

  String _search = '';
  String _filterProfile = 'Semua';
  String _filterComment = '';
  Timer? _searchDebounce;

  int _offset = 0;
  final int _limit = 20;

  // Daftar comment unik untuk filter mikhmon
  List<String> _comments = [];

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
    _fetchUsers(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
    try {
      final r = await widget.api.query(['/ip/hotspot/user/profile/print']);
      final comments = <String>{};
      // Ambil comment unik
      final users = await widget.api.query([
        '/ip/hotspot/user/print',
        '=count-only=',
      ]);
      if (mounted) {
        setState(() => _profiles = r);
      }
    } catch (_) {}
  }

  Future<void> _fetchUsers({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _users = [];
        _offset = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      // Build query dengan filter server-side
      final cmd = <String>['/ip/hotspot/user/print'];

      // Filter by name (server-side)
      if (_search.isNotEmpty) {
        cmd.add('?name~${_search.toLowerCase()}');
      }

      // Filter by profile (server-side)
      if (_filterProfile != 'Semua') {
        cmd.add('?profile=$_filterProfile');
      }

      // Filter by comment (mikhmon format)
      if (_filterComment.isNotEmpty) {
        cmd.add('?comment~$_filterComment');
      }

      // Limit & offset
      cmd.add('=start=$_offset');
      cmd.add('=limit=$_limit');

      final r = await widget.api.query(cmd);

      if (mounted) {
        setState(() {
          if (reset) {
            _users = r;
          } else {
            _users.addAll(r);
          }
          _offset += r.length;
          _hasMore = r.length >= _limit;
          _loading = false;
          _loadingMore = false;

          // Kumpulkan comment unik
          final commentSet = <String>{};
          for (final u in _users) {
            final c = u['comment'] ?? '';
            if (c.isNotEmpty) commentSet.add(c);
          }
          _comments = commentSet.toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _search = val);
      _fetchUsers(reset: true);
    });
  }

  Future<void> _deleteUser(String id, String name) async {
    final c = AppC(context.read<AppProvider>().isDark);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus User', style: TextStyle(color: c.txt)),
        content: Text('Hapus voucher "$name"?', style: TextStyle(color: c.sub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: c.sub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.query(['/ip/hotspot/user/remove', '=.id=$id']);
      _fetchUsers(reset: true);
    }
  }

  Future<void> _backupUsers() async {
    setState(() => _backing = true);
    try {
      // Export ke file .rsc
      await widget.api.query([
        '/ip/hotspot/user/export',
        '=file=backup_hotspot_user',
      ]);
      await Future.delayed(const Duration(seconds: 2));
      _snack('✅ Backup selesai! File: backup_hotspot_user.rsc');
    } catch (e) {
      _snack('❌ Backup gagal: $e');
    } finally {
      if (mounted) setState(() => _backing = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);
    final profileNames = [
      'Semua',
      ..._profiles.map((p) => p['name'] ?? '').where((n) => n.isNotEmpty),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            children: [
              // Search — server-side
              TextField(
                onChanged: _onSearchChanged,
                style: TextStyle(color: c.txt),
                decoration: InputDecoration(
                  hintText: 'Cari voucher... (server-side)',
                  hintStyle: TextStyle(color: c.sub),
                  prefixIcon: Icon(Icons.search, color: c.sub),
                  suffixIcon: Icon(
                    Icons.cloud_rounded,
                    color: AppColors.cyan.withValues(alpha: 0.5),
                    size: 18,
                  ),
                  filled: true,
                  fillColor: c.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Filter profile chips
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: profileNames.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final name = profileNames[i];
                    final active = _filterProfile == name;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _filterProfile = name);
                        _fetchUsers(reset: true);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: active ? AppColors.cyan : c.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? AppColors.cyan
                                : AppColors.cyan.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: active ? Colors.black : c.sub,
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),

              // Filter comment mikhmon
              if (_comments.isNotEmpty)
                SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _comments.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final all = i == 0;
                      final name = all ? 'Semua' : _comments[i - 1];
                      final active = all
                          ? _filterComment.isEmpty
                          : _filterComment == name;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _filterComment = all ? '' : name);
                          _fetchUsers(reset: true);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: active ? AppColors.orange : c.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: active
                                  ? AppColors.orange
                                  : AppColors.orange.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              color: active ? Colors.black : c.sub,
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 6),

              Row(
                children: [
                  Text(
                    '${_users.length} voucher dimuat',
                    style: TextStyle(color: c.sub, fontSize: 11),
                  ),
                  const Spacer(),
                  // Backup button
                  GestureDetector(
                    onTap: _backing ? null : _backupUsers,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.purple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          _backing
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.purple,
                                  ),
                                )
                              : const Icon(
                                  Icons.backup_rounded,
                                  color: AppColors.purple,
                                  size: 13,
                                ),
                          const SizedBox(width: 4),
                          const Text(
                            'Backup',
                            style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _fetchUsers(reset: true),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.cyan,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 6,
                  itemBuilder: (_, __) => SkeletonCard(c: c),
                )
              : _users.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada voucher',
                    style: TextStyle(color: c.sub),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _users.length + (_hasMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _users.length) {
                      // Load more button
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator(
                                  color: AppColors.cyan,
                                )
                              : GestureDetector(
                                  onTap: () => _fetchUsers(reset: false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cyan.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.cyan.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.expand_more_rounded,
                                          color: AppColors.cyan,
                                          size: 18,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Load More',
                                          style: TextStyle(
                                            color: AppColors.cyan,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      );
                    }

                    final u = _users[i];
                    final id = u['.id'] ?? '';
                    final name = u['name'] ?? '-';
                    final pass = u['password'] ?? '-';
                    final prof = u['profile'] ?? '-';
                    final comment = u['comment'] ?? '';
                    final disabled = u['disabled'] == 'true';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: disabled
                              ? AppColors.red.withValues(alpha: 0.2)
                              : AppColors.cyan.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: disabled
                                  ? AppColors.red.withValues(alpha: 0.1)
                                  : AppColors.cyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              disabled
                                  ? Icons.wifi_off_rounded
                                  : Icons.wifi_rounded,
                              color: disabled ? AppColors.red : AppColors.cyan,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: c.txt,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (disabled) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.red.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'OFF',
                                          style: TextStyle(
                                            color: AppColors.red,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  'Pass: $pass  •  $prof',
                                  style: TextStyle(color: c.sub, fontSize: 11),
                                ),
                                if (comment.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 3),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      comment,
                                      style: const TextStyle(
                                        color: AppColors.orange,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_rounded,
                              color: AppColors.red,
                              size: 16,
                            ),
                            onPressed: () => _deleteUser(id, name),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
