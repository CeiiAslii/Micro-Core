import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';
import 'edit_screen.dart';

class PppoeUserScreen extends StatefulWidget {
  final MikrotikApi api;
  const PppoeUserScreen({super.key, required this.api});

  @override
  State<PppoeUserScreen> createState() => _PppoeUserScreenState();
}

class _PppoeUserScreenState extends State<PppoeUserScreen> {
  List<Map<String, String>> _all = [];
  List<Map<String, String>> _filtered = [];
  List<Map<String, String>> _profiles = [];
  bool _loading = true;
  String _search = '';
  String _filterProfile = 'Semua';
  int _page = 0;
  final int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    try {
      final users = await widget.api.query(['/ppp/secret/print']);
      final profiles = await widget.api.query(['/ppp/profile/print']);
      if (mounted) {
        setState(() {
          _all = users;
          _profiles = profiles;
          _loading = false;
        });
        _applyFilter();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final list = _all.where((u) {
      final name = (u['name'] ?? '').toLowerCase();
      final matchS = name.contains(_search.toLowerCase());
      final matchP =
          _filterProfile == 'Semua' || u['profile'] == _filterProfile;
      return matchS && matchP;
    }).toList();
    setState(() {
      _filtered = list;
      _page = 0;
    });
  }

  List<Map<String, String>> get _paginated {
    final start = _page * _perPage;
    final end = (start + _perPage).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _totalPages => (_filtered.length / _perPage).ceil().clamp(1, 9999);

  Future<void> _toggleDisable(String id, String name, bool isDisabled) async {
    try {
      await widget.api.queryOrThrow([
        '/ppp/secret/set',
        '=.id=$id',
        '=disabled=${isDisabled ? 'false' : 'true'}',
      ]);
      if (!isDisabled) {
        try {
          final active = await widget.api.query([
            '/ppp/active/print',
            '?name=$name',
          ]);
          if (active.isNotEmpty) {
            await widget.api.queryOrThrow([
              '/ppp/active/remove',
              '=.id=${active[0]['.id']}',
            ]);
          }
        } catch (_) {}
      }
      _fetchAll();
    } catch (_) {}
  }

  Future<void> _delete(String id, String name) async {
    final c = AppC(context.read<AppProvider>().isDark);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus User', style: TextStyle(color: c.txt)),
        content: Text(
          'Hapus user PPPoE "$name"?',
          style: TextStyle(color: c.sub),
        ),
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
      await widget.api.queryOrThrow(['/ppp/secret/remove', '=.id=$id']);
      _fetchAll();
    }
  }

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
              TextField(
                onChanged: (v) {
                  _search = v;
                  _applyFilter();
                },
                style: TextStyle(color: c.txt),
                decoration: InputDecoration(
                  hintText: 'Cari user PPPoE...',
                  hintStyle: TextStyle(color: c.sub),
                  prefixIcon: Icon(Icons.search, color: c.sub),
                  filled: true,
                  fillColor: c.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: profileNames.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final name = profileNames[i];
                    final active = _filterProfile == name;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _filterProfile = name);
                        _applyFilter();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: active ? AppColors.orange : c.card,
                          borderRadius: BorderRadius.circular(20),
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
              Row(
                children: [
                  Text(
                    '${_filtered.length} user',
                    style: TextStyle(color: c.sub, fontSize: 11),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _fetchAll,
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
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 5,
                  itemBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SkeletonBox(height: 80, radius: 12),
                  ),
                )
              : _filtered.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada user PPPoE',
                    style: TextStyle(color: c.sub),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _paginated.length,
                  itemBuilder: (_, i) {
                    final u = _paginated[i];
                    final id = u['.id'] ?? '';
                    final name = u['name'] ?? '-';
                    final profile = u['profile'] ?? '-';
                    final disabled = u['disabled'] == 'true';
                    final ip = u['remote-address'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: disabled
                              ? AppColors.red.withValues(alpha: 0.2)
                              : AppColors.orange.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: disabled
                                  ? AppColors.red.withValues(alpha: 0.1)
                                  : AppColors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              disabled
                                  ? Icons.person_off_rounded
                                  : Icons.person_rounded,
                              color: disabled
                                  ? AppColors.red
                                  : AppColors.orange,
                              size: 18,
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
                                          'DISABLED',
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
                                  'Profile: $profile'
                                  '${ip.isNotEmpty ? '  •  IP: $ip' : ''}',
                                  style: TextStyle(color: c.sub, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _toggleDisable(id, name, disabled),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: disabled
                                    ? AppColors.green.withValues(alpha: 0.1)
                                    : AppColors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: disabled
                                      ? AppColors.green.withValues(alpha: 0.3)
                                      : AppColors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                disabled ? 'Enable' : 'Disable',
                                style: TextStyle(
                                  color: disabled
                                      ? AppColors.green
                                      : AppColors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PppoeEditScreen(
                                  api: widget.api,
                                  username: name,
                                ),
                              ),
                            ).then((_) => _fetchAll()),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: AppColors.cyan,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _delete(id, name),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.delete_rounded,
                                color: AppColors.red,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Pagination
        if (!_loading && _filtered.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: c.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: _page > 0 ? AppColors.cyan : c.sub,
                  ),
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                ),
                Text(
                  'Hal ${_page + 1} / $_totalPages',
                  style: TextStyle(color: c.txt, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _page < _totalPages - 1 ? AppColors.cyan : c.sub,
                  ),
                  onPressed: _page < _totalPages - 1
                      ? () => setState(() => _page++)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
