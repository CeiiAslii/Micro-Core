import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';

class PppoeEditScreen extends StatefulWidget {
  final MikrotikApi api;
  final String username;

  const PppoeEditScreen({super.key, required this.api, required this.username});

  @override
  State<PppoeEditScreen> createState() => _PppoeEditScreenState();
}

class _PppoeEditScreenState extends State<PppoeEditScreen> {
  final _passCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _loading = true;
  bool _isDisabled = false;

  List<Map<String, String>> _profiles = [];
  String? _selectedProfile;
  String? _secretId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final secrets = await widget.api.query([
        '/ppp/secret/print',
        '?name=${widget.username}',
      ]);
      final profiles = await widget.api.query(['/ppp/profile/print']);
      if (mounted) {
        setState(() {
          if (secrets.isNotEmpty) {
            _secretId = secrets[0]['.id'];
            _selectedProfile = secrets[0]['profile'];
            _isDisabled = secrets[0]['disabled'] == 'true';
            _ipCtrl.text = secrets[0]['remote-address'] ?? '';
          }
          _profiles = profiles;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Gagal load: $e');
      }
    }
  }

  Future<void> _savePassword() async {
    if (_passCtrl.text.isEmpty || _secretId == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.queryOrThrow([
        '/ppp/secret/set',
        '=.id=$_secretId',
        '=password=${_passCtrl.text.trim()}',
      ]);
      _snack('✅ Password berhasil diubah!');
      _passCtrl.clear();
    } catch (e) {
      _snack('❌ $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_selectedProfile == null || _secretId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.queryOrThrow([
        '/ppp/secret/set',
        '=.id=$_secretId',
        '=profile=$_selectedProfile',
      ]);
      _snack('✅ Profile berhasil diubah!');
    } catch (e) {
      _snack('❌ $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveIp() async {
    if (_secretId == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.queryOrThrow([
        '/ppp/secret/set',
        '=.id=$_secretId',
        '=remote-address=${_ipCtrl.text.trim()}',
      ]);
      _snack('✅ IP berhasil diubah!');
    } catch (e) {
      _snack('❌ $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleDisable() async {
    if (_secretId == null) return;
    setState(() => _saving = true);
    try {
      final newVal = !_isDisabled;
      await widget.api.queryOrThrow([
        '/ppp/secret/set',
        '=.id=$_secretId',
        '=disabled=${newVal ? 'true' : 'false'}',
      ]);
      if (newVal) {
        try {
          final active = await widget.api.query([
            '/ppp/active/print',
            '?name=${widget.username}',
          ]);
          if (active.isNotEmpty) {
            await widget.api.queryOrThrow([
              '/ppp/active/remove',
              '=.id=${active[0]['.id']}',
            ]);
          }
        } catch (_) {}
      }
      setState(() => _isDisabled = newVal);
      _snack(newVal ? '🔴 User di-disable!' : '🟢 User di-enable!');
    } catch (e) {
      _snack('❌ $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: c.txt),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit PPPoE',
              style: TextStyle(
                color: c.txt,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.username,
              style: const TextStyle(color: AppColors.cyan, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.cyan),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isDisabled
                            ? AppColors.red.withValues(alpha: 0.3)
                            : AppColors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isDisabled
                              ? Icons.person_off_rounded
                              : Icons.person_rounded,
                          color: _isDisabled ? AppColors.red : AppColors.green,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.username,
                                style: TextStyle(
                                  color: c.txt,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _isDisabled ? '🔴 DISABLED' : '🟢 AKTIF',
                                style: TextStyle(
                                  color: _isDisabled
                                      ? AppColors.red
                                      : AppColors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _saving ? null : _toggleDisable,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDisabled
                                ? AppColors.green
                                : AppColors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            _isDisabled ? 'Enable' : 'Disable',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _section(
                    icon: Icons.lock_reset_rounded,
                    color: AppColors.cyan,
                    title: 'Ganti Password',
                    c: c,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: TextStyle(color: c.txt),
                            decoration: InputDecoration(
                              hintText: 'Password baru',
                              hintStyle: TextStyle(
                                color: c.sub.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: c.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.cyan,
                                  width: 1.5,
                                ),
                              ),
                              isDense: true,
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
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saving ? null : _savePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cyan,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Simpan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _section(
                    icon: Icons.speed_rounded,
                    color: AppColors.purple,
                    title: 'Ganti Profile',
                    c: c,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.bg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value:
                                    _profiles.any(
                                      (p) => p['name'] == _selectedProfile,
                                    )
                                    ? _selectedProfile
                                    : null,
                                isExpanded: true,
                                dropdownColor: c.card,
                                style: TextStyle(color: c.txt),
                                hint: Text(
                                  'Pilih profile',
                                  style: TextStyle(color: c.sub),
                                ),
                                items: _profiles
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p['name'],
                                        child: Text(p['name'] ?? ''),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedProfile = v),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Terapkan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _section(
                    icon: Icons.lan_rounded,
                    color: AppColors.blue,
                    title: 'Remote IP',
                    c: c,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ipCtrl,
                            style: TextStyle(color: c.txt),
                            decoration: InputDecoration(
                              hintText: '192.168.2.10 (kosong=auto)',
                              hintStyle: TextStyle(
                                color: c.sub.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: c.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.blue,
                                  width: 1.5,
                                ),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saving ? null : _saveIp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Simpan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required AppC c,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: c.txt,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
