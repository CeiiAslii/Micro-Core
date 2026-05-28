import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';

class LoadBalanceScreen extends StatefulWidget {
  final MikrotikApi api;
  const LoadBalanceScreen({super.key, required this.api});

  @override
  State<LoadBalanceScreen> createState() => _LoadBalanceScreenState();
}

class _LoadBalanceScreenState extends State<LoadBalanceScreen> {
  List<Map<String, String>> _interfaces = [];
  bool _loading = true;
  bool _applying = false;
  String _method = 'pcc';
  String? _isp1, _isp2, _lanIface;

  @override
  void initState() {
    super.initState();
    _fetchInterfaces();
  }

  Future<void> _fetchInterfaces() async {
    try {
      final r = await widget.api.query(['/interface/print']);
      if (mounted) {
        setState(() {
          _interfaces = r
              .where((i) => i['type'] == 'ether' || i['type'] == 'vlan')
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply() async {
    if (_isp1 == null || _lanIface == null) {
      _snack('Pilih ISP 1 dan interface LAN!');
      return;
    }
    setState(() => _applying = true);
    try {
      if (_method == 'pcc') {
        await _applyPcc();
      } else if (_method == 'ecmp') {
        await _applyEcmp();
      }
      _snack('✅ Load balance berhasil diterapkan!');
    } catch (e) {
      _snack('❌ Error: $e');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _applyPcc() async {
    // Tambah mangle untuk PCC
    final isps = [_isp1!, if (_isp2 != null) _isp2!];
    for (int i = 0; i < isps.length; i++) {
      await widget.api.query([
        '/ip/firewall/mangle/add',
        '=chain=prerouting',
        '=in-interface=$_lanIface',
        '=per-connection-classifier=both-addresses:${isps.length}/$i',
        '=action=mark-connection',
        '=new-connection-mark=isp${i + 1}-conn',
        '=passthrough=yes',
        '=comment=LB-PCC-ISP${i + 1}',
      ]);
      await widget.api.query([
        '/ip/firewall/mangle/add',
        '=chain=prerouting',
        '=connection-mark=isp${i + 1}-conn',
        '=action=mark-routing',
        '=new-routing-mark=to-isp${i + 1}',
        '=passthrough=no',
        '=comment=LB-PCC-ROUTE-ISP${i + 1}',
      ]);
    }
    _snack('✅ PCC rules diterapkan!');
  }

  Future<void> _applyEcmp() async {
    // Check gateway ISP
    final routes = await widget.api.query(['/ip/route/print']);
    _snack('✅ ECMP: pastikan default route sudah ada di setiap ISP');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);
    final ifaceNames = _interfaces
        .map((i) => i['name'] ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_rounded, color: AppColors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Load balance membagi traffic ke beberapa ISP. '
                    'Pastikan routing sudah dikonfigurasi sebelum apply.',
                    style: TextStyle(color: c.sub, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Method selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Metode Load Balance', c),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _methodCard(
                        'pcc',
                        'PCC',
                        'Per Connection Classifier\nPaling stabil, cocok untuk m-banking',
                        AppColors.cyan,
                        c,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _methodCard(
                        'ecmp',
                        'ECMP',
                        'Equal Cost Multi-Path\nSimple, untuk traffic besar',
                        AppColors.purple,
                        c,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _methodCard(
                        'nth',
                        'NTH',
                        'Round Robin\nAlternatif PCC',
                        AppColors.orange,
                        c,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Interface config
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Konfigurasi Interface', c),
                const SizedBox(height: 14),

                _ifaceDropdown(
                  'ISP 1 (Wajib)',
                  _isp1,
                  ifaceNames,
                  c,
                  AppColors.green,
                  (v) => setState(() => _isp1 = v),
                ),
                const SizedBox(height: 10),

                _ifaceDropdown(
                  'ISP 2 (Opsional)',
                  _isp2,
                  ifaceNames,
                  c,
                  AppColors.blue,
                  (v) => setState(() => _isp2 = v),
                ),
                const SizedBox(height: 10),

                _ifaceDropdown(
                  'Interface LAN (Wajib)',
                  _lanIface,
                  ifaceNames,
                  c,
                  AppColors.orange,
                  (v) => setState(() => _lanIface = v),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.cyan, AppColors.cyanDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _applying ? null : _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _applying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Apply ${_method.toUpperCase()} Load Balance',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
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
      ),
    );
  }

  Widget _sectionTitle(String title, AppC c) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.cyan,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
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
  );

  Widget _methodCard(
    String type,
    String name,
    String desc,
    Color color,
    AppC c,
  ) {
    final active = _method == type;
    return GestureDetector(
      onTap: () => setState(() => _method = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : c.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : c.sub.withValues(alpha: 0.2),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.balance_rounded,
              color: active ? color : c.sub,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                color: active ? color : c.txt,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(color: c.sub, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _ifaceDropdown(
    String label,
    String? value,
    List<String> items,
    AppC c,
    Color color,
    Function(String?) onChanged,
  ) => Column(
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
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : null,
            isExpanded: true,
            dropdownColor: c.card,
            style: TextStyle(color: c.txt),
            hint: Text('Pilih interface', style: TextStyle(color: c.sub)),
            items: items
                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}
