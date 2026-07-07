import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';

class PppoeAddUserScreen extends StatefulWidget {
  final MikrotikApi api;

  const PppoeAddUserScreen({super.key, required this.api});

  @override
  State<PppoeAddUserScreen> createState() => _PppoeAddUserScreenState();
}

class _PppoeAddUserScreenState extends State<PppoeAddUserScreen> {
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _localCtrl = TextEditingController();
  final _callerCtrl = TextEditingController();
  final _ipv6Ctrl = TextEditingController();
  final _routesCtrl = TextEditingController();
  final _ipv6RoutesCtrl = TextEditingController();
  final _limitInCtrl = TextEditingController();
  final _limitOutCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  List<Map<String, String>> _profiles = [];
  String? _selectedProfile;
  String _selectedService = 'pppoe';
  bool _obscure = true;
  bool _saving = false;
  bool _loadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _ipCtrl.dispose();
    _localCtrl.dispose();
    _callerCtrl.dispose();
    _ipv6Ctrl.dispose();
    _routesCtrl.dispose();
    _ipv6RoutesCtrl.dispose();
    _limitInCtrl.dispose();
    _limitOutCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
    final profiles = await widget.api.query(['/ppp/profile/print']);
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _selectedProfile = profiles.isEmpty ? null : profiles.first['name'];
      _loadingProfiles = false;
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _snack('Username dan password wajib diisi');
      return;
    }
    if (_selectedProfile == null) {
      _snack('Pilih profile terlebih dahulu');
      return;
    }

    setState(() => _saving = true);
    final command = [
      '/ppp/secret/add',
      '=name=${_nameCtrl.text.trim()}',
      '=password=${_passCtrl.text}',
      '=service=$_selectedService',
      '=profile=$_selectedProfile',
    ];
    if (_ipCtrl.text.trim().isNotEmpty) {
      command.add('=remote-address=${_ipCtrl.text.trim()}');
    }
    final optional = {
      'local-address': _localCtrl.text.trim(),
      'caller-id': _callerCtrl.text.trim(),
      'remote-ipv6-prefix': _ipv6Ctrl.text.trim(),
      'routes': _routesCtrl.text.trim(),
      'ipv6-routes': _ipv6RoutesCtrl.text.trim(),
      'limit-bytes-in': _limitInCtrl.text.trim(),
      'limit-bytes-out': _limitOutCtrl.text.trim(),
    };
    for (final entry in optional.entries) {
      if (entry.value.isNotEmpty) command.add('=${entry.key}=${entry.value}');
    }
    if (_commentCtrl.text.trim().isNotEmpty) {
      command.add('=comment=${_commentCtrl.text.trim()}');
    }

    try {
      await widget.api.queryOrThrow(command);
      _nameCtrl.clear();
      _passCtrl.clear();
      _ipCtrl.clear();
      _localCtrl.clear();
      _callerCtrl.clear();
      _ipv6Ctrl.clear();
      _routesCtrl.clear();
      _ipv6RoutesCtrl.clear();
      _limitInCtrl.clear();
      _limitOutCtrl.clear();
      _commentCtrl.clear();
      _snack('PPP Secret berhasil ditambahkan');
    } catch (error) {
      _snack('Gagal: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppColors.orange,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tambah PPP Secret',
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _label('Akun', c),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _nameCtrl,
                    hint: 'Username',
                    icon: Icons.person_outline_rounded,
                    c: c,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _field(
                    controller: _passCtrl,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    c: c,
                    obscureText: _obscure,
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 17,
                        color: c.sub,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _label('Service', c),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _selectedService,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.hub_outlined),
              ),
              items:
                  const [
                        'any',
                        'async',
                        'l2tp',
                        'ovpn',
                        'pppoe',
                        'pptp',
                        'sstp',
                      ]
                      .map(
                        (service) => DropdownMenuItem(
                          value: service,
                          child: Text(service),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedService = value);
                }
              },
            ),
            const SizedBox(height: 10),
            _label('Profile', c),
            const SizedBox(height: 4),
            _profileField(c),
            const SizedBox(height: 10),
            _label('Pengaturan Opsional', c),
            const SizedBox(height: 4),
            _field(
              controller: _ipCtrl,
              hint: 'Remote IP, kosongkan untuk otomatis',
              icon: Icons.lan_outlined,
              c: c,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 7),
            _field(
              controller: _localCtrl,
              hint: 'Local Address',
              icon: Icons.home_work_outlined,
              c: c,
            ),
            const SizedBox(height: 7),
            _field(
              controller: _callerCtrl,
              hint: 'Caller ID',
              icon: Icons.fingerprint_rounded,
              c: c,
            ),
            const SizedBox(height: 7),
            _field(
              controller: _ipv6Ctrl,
              hint: 'Remote IPv6 Prefix',
              icon: Icons.language_rounded,
              c: c,
            ),
            const SizedBox(height: 7),
            _field(
              controller: _routesCtrl,
              hint: 'Routes',
              icon: Icons.alt_route_rounded,
              c: c,
            ),
            const SizedBox(height: 7),
            _field(
              controller: _ipv6RoutesCtrl,
              hint: 'IPv6 Routes',
              icon: Icons.alt_route_rounded,
              c: c,
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _limitInCtrl,
                    hint: 'Limit Bytes In',
                    icon: Icons.download_rounded,
                    c: c,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _field(
                    controller: _limitOutCtrl,
                    hint: 'Limit Bytes Out',
                    icon: Icons.upload_rounded,
                    c: c,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _field(
              controller: _commentCtrl,
              hint: 'Komentar / nama pelanggan',
              icon: Icons.notes_rounded,
              c: c,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 17),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Secret'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileField(AppC c) {
    if (_loadingProfiles) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _profiles.any((p) => p['name'] == _selectedProfile)
              ? _selectedProfile
              : null,
          isExpanded: true,
          dropdownColor: c.card,
          style: TextStyle(color: c.txt, fontSize: 12),
          hint: Text('Pilih profile', style: TextStyle(color: c.sub)),
          items: _profiles
              .map(
                (profile) => DropdownMenuItem<String>(
                  value: profile['name'],
                  child: Text(profile['name'] ?? ''),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedProfile = value),
        ),
      ),
    );
  }

  Widget _label(String text, AppC c) => Text(
    text,
    style: TextStyle(color: c.sub, fontSize: 10, fontWeight: FontWeight.w600),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required AppC c,
    bool obscureText = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) => SizedBox(
    height: 40,
    child: TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: c.txt, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.orange, size: 17),
        suffixIcon: suffix,
      ),
    ),
  );
}
