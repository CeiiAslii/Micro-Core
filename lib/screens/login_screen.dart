import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/mikrotik_api.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _showForm = false;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _parseHost(String input) {
    input = input.trim();
    final lastColon = input.lastIndexOf(':');
    if (lastColon != -1) {
      final port = int.tryParse(input.substring(lastColon + 1));
      if (port != null) {
        return {'host': input.substring(0, lastColon), 'port': port};
      }
    }
    return {'host': input, 'port': 8728};
  }

  Future<void> _connect({
    String? host,
    String? user,
    String? pass,
    String? savedName,
  }) async {
    final h = host ?? _hostCtrl.text.trim();
    final u = user ?? _userCtrl.text.trim();
    final p = pass ?? _passCtrl.text.trim();
    final n = savedName ?? _nameCtrl.text.trim();

    if (h.isEmpty || u.isEmpty || p.isEmpty) {
      _snack('Lengkapi semua field!');
      return;
    }

    setState(() => _loading = true);
    try {
      final parsed = _parseHost(h);
      final api = MikrotikApi(
        host: parsed['host'],
        username: u,
        password: p,
        port: parsed['port'],
      );

      final ok = await api.connect();
      if (ok && mounted) {
        context.read<AppProvider>().setApi(api);

        final info = await api.query(['/system/resource/print']);
        final identity = await api.query(['/system/identity/print']);

        String routerName = n;
        if (routerName.isEmpty && identity.isNotEmpty) {
          routerName = identity[0]['name'] ?? h;
        }

        if (mounted && info.isNotEmpty) {
          context.read<AppProvider>().setRouterInfo(
            name: identity.isNotEmpty ? (identity[0]['name'] ?? '-') : '-',
            model: info[0]['board-name'] ?? '-',
            version: info[0]['version'] ?? '-',
          );
        }

        // Simpan ke saved routers
        await context.read<AppProvider>().saveRouter(
          name: routerName.isNotEmpty ? routerName : h,
          host: h,
          username: u,
          password: p,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        _snack('Login gagal, periksa credentials');
      }
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteRouter(String id) async {
    final c = AppC(context.read<AppProvider>().isDark);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Router', style: TextStyle(color: c.txt)),
        content: Text(
          'Hapus router ini dari daftar tersimpan?',
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
      context.read<AppProvider>().deleteRouter(id);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final dark = provider.isDark;
    final c = AppC(dark);
    final routers = provider.savedRouters;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppInfo.name,
                              style: const TextStyle(
                                color: AppColors.cyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pilih Router',
                              style: TextStyle(
                                color: c.txt,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Theme toggle
                            GestureDetector(
                              onTap: () => provider.toggleTheme(),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: c.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.cyan.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  dark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  color: dark ? Colors.amber : Colors.blueGrey,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Add router button
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showForm = !_showForm),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.cyan,
                                      AppColors.cyanDark,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.cyan.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _showForm
                                      ? Icons.close_rounded
                                      : Icons.add_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    Text(
                      routers.isEmpty
                          ? 'Tambah router dengan tombol +'
                          : '${routers.length} router tersimpan',
                      style: TextStyle(color: c.sub, fontSize: 13),
                    ),

                    // Form tambah router
                    if (_showForm) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.cyan.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.add_circle_rounded,
                                  color: AppColors.cyan,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tambah Router Baru',
                                  style: TextStyle(
                                    color: c.txt,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _fld(
                              _nameCtrl,
                              'Nama Router',
                              'Contoh: Router Kantor',
                              Icons.label_rounded,
                              c,
                            ),
                            const SizedBox(height: 10),
                            _fld(
                              _hostCtrl,
                              'IP / Host',
                              '192.168.1.1 atau host:port',
                              Icons.dns_rounded,
                              c,
                              helper: 'Port default: 8728',
                            ),
                            const SizedBox(height: 10),
                            _fld(
                              _userCtrl,
                              'Username',
                              'admin',
                              Icons.person_rounded,
                              c,
                            ),
                            const SizedBox(height: 10),
                            // Password
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Password',
                                  style: TextStyle(
                                    color: c.sub,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _passCtrl,
                                  obscureText: _obscure,
                                  style: TextStyle(color: c.txt),
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    hintStyle: TextStyle(
                                      color: c.sub.withValues(alpha: 0.4),
                                    ),
                                    filled: true,
                                    fillColor: c.bg,
                                    prefixIcon: const Icon(
                                      Icons.lock_rounded,
                                      color: AppColors.cyan,
                                      size: 18,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: c.sub,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.cyan,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.cyan,
                                      AppColors.cyanDark,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.cyan.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _loading ? null : () => _connect(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.flash_on_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'CONNECT & SIMPAN',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Router cards
            routers.isEmpty && !_showForm
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.router_rounded,
                              color: AppColors.cyan,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada router tersimpan',
                            style: TextStyle(
                              color: c.txt,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap tombol + untuk menambah router',
                            style: TextStyle(color: c.sub, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((_, i) {
                        final r = routers[i];
                        return _routerCard(r, c);
                      }, childCount: routers.length),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _routerCard(SavedRouter r, AppC c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _loading
              ? null
              : () => _connect(
                  host: r.host,
                  user: r.username,
                  pass: r.password,
                  savedName: r.name,
                ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003A4D), AppColors.cyanDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.router_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        style: TextStyle(
                          color: c.txt,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        r.host,
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'User: ${r.username}',
                        style: TextStyle(color: c.sub, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Connect button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.cyan, AppColors.cyanDark],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyan.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              children: [
                                Icon(
                                  Icons.flash_on_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Connect',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 6),
                    // Delete button
                    GestureDetector(
                      onTap: () => _deleteRouter(r.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Hapus',
                          style: TextStyle(
                            color: AppColors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fld(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
    AppC c, {
    String? helper,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: c.sub,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        style: TextStyle(color: c.txt),
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: c.sub.withValues(alpha: 0.4),
            fontSize: 13,
          ),
          filled: true,
          fillColor: c.bg,
          prefixIcon: Icon(icon, color: AppColors.cyan, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
          ),
          helperText: helper,
          helperStyle: TextStyle(
            color: c.sub.withValues(alpha: 0.5),
            fontSize: 11,
          ),
          isDense: true,
        ),
      ),
    ],
  );
}
