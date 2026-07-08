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
  bool _formLoading = false;
  String? _connectingRouterId;
  bool _showForm = false;
  final bool _saveAccount = true;

  bool get _busy => _formLoading || _connectingRouterId != null;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _parseHost(String input) {
    var value = input.trim();
    value = value.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
    final slashIndex = value.indexOf('/');
    if (slashIndex != -1) {
      value = value.substring(0, slashIndex);
    }

    final lastColon = value.lastIndexOf(':');
    if (lastColon != -1) {
      final port = int.tryParse(value.substring(lastColon + 1).trim());
      if (port != null && port > 0 && port <= 65535) {
        return {'host': value.substring(0, lastColon).trim(), 'port': port};
      }
    }
    return {'host': value.trim(), 'port': 8728};
  }

  Future<void> _connect({
    String? host,
    String? user,
    String? pass,
    String? savedName,
    String? routerId,
  }) async {
    final provider = context.read<AppProvider>();
    final h = host ?? _hostCtrl.text.trim();
    final u = user ?? _userCtrl.text.trim();
    final p = pass ?? _passCtrl.text.trim();
    final n = savedName ?? _nameCtrl.text.trim();

    if (h.isEmpty || u.isEmpty || p.isEmpty) {
      _snack('Lengkapi semua field!');
      return;
    }

    final parsed = _parseHost(h);
    if ((parsed['host'] as String).isEmpty) {
      _snack('IP/host VPN wajib diisi');
      return;
    }
    if (parsed['port'] == 8291) {
      _snack(
        'Port 8291 adalah WinBox. Core Monitor membutuhkan RouterOS API: '
        'gunakan tunnel ke port 8728, atau 8729 untuk API-SSL.',
      );
      return;
    }

    final savedRouterLogin = routerId != null;
    setState(() {
      if (savedRouterLogin) {
        _connectingRouterId = routerId;
      } else {
        _formLoading = true;
      }
    });
    try {
      final api = MikrotikApi(
        host: parsed['host'],
        username: u,
        password: p,
        port: parsed['port'],
      );

      final ok = await api.connect();
      if (ok && mounted) {
        provider.setApi(api);

        final info = await api.query(['/system/resource/print']);
        final identity = await api.query(['/system/identity/print']);

        String routerName = n;
        if (routerName.isEmpty && identity.isNotEmpty) {
          routerName = identity[0]['name'] ?? h;
        }

        if (mounted && info.isNotEmpty) {
          provider.setRouterInfo(
            name: identity.isNotEmpty ? (identity[0]['name'] ?? '-') : '-',
            model: info[0]['board-name'] ?? '-',
            version: info[0]['version'] ?? '-',
          );
        }

        if (_saveAccount || savedName != null) {
          await provider.saveRouter(
            name: routerName.isNotEmpty ? routerName : h,
            host: h,
            username: u,
            password: p,
          );
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        _snack('Login gagal, periksa credentials');
      }
    } catch (e) {
      _snack(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          if (savedRouterLogin) {
            if (_connectingRouterId == routerId) _connectingRouterId = null;
          } else {
            _formLoading = false;
          }
        });
      }
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
      if (!mounted) return;
      context.read<AppProvider>().deleteRouter(id);
    }
  }

  Future<void> _editRouter(SavedRouter router) async {
    final c = AppC(context.read<AppProvider>().isDark);
    final nameCtrl = TextEditingController(text: router.name);
    final hostCtrl = TextEditingController(text: router.host);
    final userCtrl = TextEditingController(text: router.username);
    final passCtrl = TextEditingController(text: router.password);
    var obscure = true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Edit Router', style: TextStyle(color: c.txt)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, 'Nama Router', Icons.label_rounded, c),
                const SizedBox(height: 10),
                _dialogField(hostCtrl, 'IP / Host', Icons.dns_rounded, c),
                const SizedBox(height: 10),
                _dialogField(userCtrl, 'Username', Icons.person_rounded, c),
                const SizedBox(height: 10),
                _dialogField(
                  passCtrl,
                  'Password',
                  Icons.lock_rounded,
                  c,
                  obscure: obscure,
                  suffix: IconButton(
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: c.sub,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Batal', style: TextStyle(color: c.sub)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final name = nameCtrl.text.trim();
      final host = hostCtrl.text.trim();
      final user = userCtrl.text.trim();
      final pass = passCtrl.text.trim();
      if (name.isEmpty || host.isEmpty || user.isEmpty || pass.isEmpty) {
        _snack('Data router belum lengkap');
      } else if (mounted) {
        await context.read<AppProvider>().updateRouter(
          id: router.id,
          name: name,
          host: host,
          username: user,
          password: pass,
        );
      }
    }

    nameCtrl.dispose();
    hostCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
  }

  String _friendlyError(Object error) {
    var message = error.toString().trim();
    while (message.startsWith(RegExp(r'(Exception|SocketException):\s*'))) {
      message = message.replaceFirst(
        RegExp(r'^(Exception|SocketException):\s*'),
        '',
      );
    }
    return message;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, maxLines: 4, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.cyan.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    'assets/images/core_monitor_logo.jpg',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      AppInfo.name,
                                      style: TextStyle(
                                        color: AppColors.cyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Router Workspace',
                                      style: TextStyle(
                                        color: c.txt,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Row(
                          children: [
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
                            GestureDetector(
                              onTap: _busy
                                  ? null
                                  : () =>
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
                          ? 'Tambahkan router untuk memulai monitoring dan administrasi.'
                          : '${routers.length} router siap dikelola',
                      style: TextStyle(color: c.sub, fontSize: 13),
                    ),

                    if (_showForm) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            _fld(
                              _nameCtrl,
                              'Nama Router',
                              'Contoh: Router Kantor',
                              Icons.label_rounded,
                              c,
                            ),
                            const SizedBox(height: 9),
                            _fld(
                              _hostCtrl,
                              'IP / Host',
                              '',
                              Icons.dns_rounded,
                              c,
                            ),
                            const SizedBox(height: 9),
                            _fld(
                              _userCtrl,
                              'Username',
                              '',
                              Icons.person_rounded,
                              c,
                            ),
                            const SizedBox(height: 9),
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
                                  style: TextStyle(color: c.txt, fontSize: 13),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    filled: true,
                                    fillColor: c.bg,
                                    prefixIcon: const Icon(
                                      Icons.lock_rounded,
                                      color: AppColors.cyan,
                                      size: 18,
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 40,
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
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.cyan,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ElevatedButton(
                                  onPressed: _formLoading
                                      ? null
                                      : () => _connect(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _formLoading
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
                                                fontSize: 12,
                                                letterSpacing: 0.6,
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

            if (_showForm)
              const SliverToBoxAdapter(child: SizedBox(height: 24))
            else if (routers.isEmpty)
              SliverFillRemaining(
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
            else
              SliverPadding(
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
    final connecting = _connectingRouterId == r.id;
    final disabled = _busy && !connecting;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled || connecting
              ? null
              : () => _connect(
                  host: r.host,
                  user: r.username,
                  pass: r.password,
                  savedName: r.name,
                  routerId: r.id,
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003A4D), AppColors.cyanDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.router_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.txt,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Router tersimpan',
                        style: TextStyle(color: c.sub, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _routerAction(
                      tooltip: 'Connect',
                      color: AppColors.cyan,
                      onTap: disabled || connecting
                          ? null
                          : () => _connect(
                              host: r.host,
                              user: r.username,
                              pass: r.password,
                              savedName: r.name,
                              routerId: r.id,
                            ),
                      child: connecting
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.flash_on_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                    ),
                    const SizedBox(width: 6),
                    _routerAction(
                      tooltip: 'Edit',
                      color: AppColors.orange,
                      onTap: _busy ? null : () => _editRouter(r),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.orange,
                        size: 16,
                      ),
                      filled: false,
                    ),
                    const SizedBox(width: 6),
                    _routerAction(
                      tooltip: 'Hapus',
                      color: AppColors.red,
                      onTap: _busy ? null : () => _deleteRouter(r.id),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.red,
                        size: 16,
                      ),
                      filled: false,
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

  Widget _routerAction({
    required String tooltip,
    required Color color,
    required Widget child,
    required VoidCallback? onTap,
    bool filled = true,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
            border: filled
                ? null
                : Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    AppC c, {
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(color: c.txt),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.sub, fontSize: 12),
        filled: true,
        fillColor: c.bg,
        prefixIcon: Icon(icon, color: AppColors.cyan, size: 18),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
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
        style: TextStyle(color: c.txt, fontSize: 13),
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: c.sub.withValues(alpha: 0.4),
            fontSize: 13,
          ),
          filled: true,
          fillColor: c.bg,
          prefixIcon: Icon(icon, color: AppColors.cyan, size: 18),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 40,
          ),
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
        ),
      ),
    ],
  );
}
