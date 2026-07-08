import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';

class HotspotGenerateScreen extends StatefulWidget {
  final MikrotikApi api;
  const HotspotGenerateScreen({super.key, required this.api});

  @override
  State<HotspotGenerateScreen> createState() => _HotspotGenerateScreenState();
}

class _HotspotGenerateScreenState extends State<HotspotGenerateScreen> {
  List<Map<String, String>> _profiles = [];
  List<Map<String, String>> _servers = [];
  String? _selectedProfile;
  String? _selectedServer; // null = all
  bool _loadingData = true;
  bool _generating = false;

  int _qty = 5;
  int _length = 6;
  bool _samePassUser = true; // username = password
  String _charType = 'alpha_num'; // num | alpha | ALPHA | alpha_num | all

  final _prefixCtrl = TextEditingController();
  List<Map<String, String>> _generated = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final profiles = await widget.api.query([
        '/ip/hotspot/user/profile/print',
      ]);
      final servers = await widget.api.query(['/ip/hotspot/print']);
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _servers = servers;
          _selectedProfile = profiles.isNotEmpty ? profiles[0]['name'] : null;
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  String _genChar() {
    switch (_charType) {
      case 'num':
        return '0123456789';
      case 'alpha':
        return 'abcdefghijklmnopqrstuvwxyz';
      case 'ALPHA':
        return 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      case 'alpha_num':
        return 'abcdefghijklmnopqrstuvwxyz0123456789';
      case 'all':
        return 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      default:
        return 'abcdefghijklmnopqrstuvwxyz0123456789';
    }
  }

  String _randomStr(int len) {
    final chars = _genChar();
    var seed = DateTime.now().microsecondsSinceEpoch;
    var result = '';
    for (int i = 0; i < len; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      result += chars[seed % chars.length];
    }
    return result;
  }

  Future<void> _generate() async {
    if (_selectedProfile == null) {
      _snack('Pilih profile dulu!');
      return;
    }
    setState(() {
      _generating = true;
      _generated = [];
    });

    final results = <Map<String, String>>[];
    try {
      for (int i = 0; i < _qty; i++) {
        final prefix = _prefixCtrl.text.trim();
        final name = prefix.isNotEmpty
            ? '$prefix${_randomStr(_length)}'
            : _randomStr(_length);
        final pass = _samePassUser ? name : _randomStr(_length);

        final cmd = [
          '/ip/hotspot/user/add',
          '=name=$name',
          '=password=$pass',
          '=profile=$_selectedProfile',
        ];

        if (_selectedServer != null && _selectedServer!.isNotEmpty) {
          cmd.add('=server=$_selectedServer');
        }

        await widget.api.queryOrThrow(cmd);
        results.add({'name': name, 'password': pass});
        await Future.delayed(const Duration(milliseconds: 80));
      }

      if (mounted) {
        setState(() {
          _generated = results;
          _generating = false;
        });
        _snack('✅ ${results.length} voucher berhasil!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        _snack('❌ $e');
      }
    }
  }

  void _copyAll() {
    final text = _generated
        .map((v) => '${v['name']} | ${v['password']}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _snack('✅ Semua voucher disalin!');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
            ),
            child: _loadingData
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.cyan),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: AppColors.cyan,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Generate Voucher',
                            style: TextStyle(
                              color: c.txt,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      _label('Profile Paket', c),
                      const SizedBox(height: 6),
                      _dropdown(
                        value: _selectedProfile,
                        items: _profiles
                            .map(
                              (p) => DropdownMenuItem(
                                value: p['name'],
                                child: Text(p['name'] ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedProfile = v),
                        hint: 'Pilih profile',
                        color: AppColors.cyan,
                        c: c,
                      ),

                      const SizedBox(height: 12),

                      _label('Server Hotspot', c),
                      const SizedBox(height: 6),
                      _dropdown(
                        value: _selectedServer,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              'all (semua server)',
                              style: TextStyle(color: c.txt),
                            ),
                          ),
                          ..._servers.map(
                            (s) => DropdownMenuItem(
                              value: s['name'],
                              child: Text(s['name'] ?? ''),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedServer = v),
                        hint: 'all',
                        color: AppColors.green,
                        c: c,
                      ),

                      const SizedBox(height: 12),

                      _label('Prefix Username (opsional)', c),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _prefixCtrl,
                        style: TextStyle(color: c.txt),
                        decoration: InputDecoration(
                          hintText: 'Contoh: VCH- atau HS-',
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
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Jumlah (Qty)', c),
                                const SizedBox(height: 6),
                                _counter(
                                  value: _qty,
                                  min: 1,
                                  max: 100,
                                  onDec: () => setState(() => _qty--),
                                  onInc: () => setState(() => _qty++),
                                  c: c,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Panjang Karakter', c),
                                const SizedBox(height: 6),
                                _counter(
                                  value: _length,
                                  min: 4,
                                  max: 12,
                                  onDec: () => setState(() => _length--),
                                  onInc: () => setState(() => _length++),
                                  c: c,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _label('Pilihan Karakter', c),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _charChip('num', '123 Angka', c),
                          _charChip('alpha', 'abc Huruf Kecil', c),
                          _charChip('ALPHA', 'ABC Huruf Besar', c),
                          _charChip('alpha_num', 'abc123 Mix', c),
                          _charChip('all', 'Abc123 All', c),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _label('User Mode', c),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _modeBtn(
                              true,
                              'Username = Password',
                              'User & pass sama',
                              c,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _modeBtn(
                              false,
                              'Username & Password',
                              'User & pass berbeda',
                              c,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.cyan,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: _generating ? null : _generate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _generating
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Generating...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.bolt_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Generate $_qty Voucher',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
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

          if (_generated.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Hasil (${_generated.length})',
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _copyAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.copy_all_rounded,
                          color: AppColors.green,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Copy Semua',
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: _generated.asMap().entries.map((e) {
                  final idx = e.key;
                  final v = e.value;
                  final name = v['name'] ?? '';
                  final pass = v['password'] ?? '';
                  final same = name == pass;

                  return GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: same ? name : '$name | $pass'),
                      );
                      _snack('Disalin: $name');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: c.bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${idx + 1}.',
                            style: TextStyle(
                              color: c.sub,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: same
                                ? Text(
                                    name,
                                    style: const TextStyle(
                                      color: AppColors.cyan,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: AppColors.cyan,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      Text(
                                        '  |  ',
                                        style: TextStyle(
                                          color: c.sub,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        pass,
                                        style: TextStyle(
                                          color: c.txt,
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          Icon(Icons.copy_rounded, color: c.sub, size: 13),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _label(String text, AppC c) => Text(
    text,
    style: TextStyle(color: c.sub, fontSize: 12, fontWeight: FontWeight.w600),
  );

  Widget _dropdown({
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required Function(String?) onChanged,
    required String hint,
    required Color color,
    required AppC c,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: c.bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: value,
        isExpanded: true,
        dropdownColor: c.card,
        style: TextStyle(color: c.txt),
        hint: Text(hint, style: TextStyle(color: c.sub)),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Widget _counter({
    required int value,
    required int min,
    required int max,
    required VoidCallback onDec,
    required VoidCallback onInc,
    required AppC c,
  }) => Container(
    decoration: BoxDecoration(
      color: c.bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: value > min ? onDec : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.remove_rounded,
              color: value > min ? AppColors.cyan : c.sub,
              size: 18,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                color: c.txt,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: value < max ? onInc : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.add_rounded,
              color: value < max ? AppColors.cyan : c.sub,
              size: 18,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _charChip(String type, String label, AppC c) {
    final active = _charType == type;
    return GestureDetector(
      onTap: () => setState(() => _charType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.cyan : c.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.cyan
                : AppColors.cyan.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : c.sub,
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _modeBtn(bool val, String title, String sub, AppC c) {
    final active = _samePassUser == val;
    return GestureDetector(
      onTap: () => setState(() => _samePassUser = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? AppColors.cyan.withValues(alpha: 0.12) : c.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.cyan : c.sub.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              val ? Icons.link_rounded : Icons.link_off_rounded,
              color: active ? AppColors.cyan : c.sub,
              size: 18,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: active ? AppColors.cyan : c.txt,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              sub,
              style: TextStyle(color: c.sub, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
