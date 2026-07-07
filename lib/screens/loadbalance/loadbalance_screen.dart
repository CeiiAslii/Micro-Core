import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';

class LoadBalanceScreen extends StatefulWidget {
  final MikrotikApi api;

  const LoadBalanceScreen({super.key, required this.api});

  @override
  State<LoadBalanceScreen> createState() => _LoadBalanceScreenState();
}

class _LoadBalanceScreenState extends State<LoadBalanceScreen> {
  final _isp1GatewayCtrl = TextEditingController();
  final _isp2GatewayCtrl = TextEditingController();

  List<Map<String, String>> _interfaces = [];
  bool _applying = false;
  String _method = 'pcc';
  String? _isp1;
  String? _isp2;
  String? _lanIface;

  @override
  void initState() {
    super.initState();
    _fetchInterfaces();
  }

  @override
  void dispose() {
    _isp1GatewayCtrl.dispose();
    _isp2GatewayCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInterfaces() async {
    try {
      final rows = await widget.api.query(['/interface/print']);
      if (!mounted) return;
      setState(() {
        _interfaces = rows
            .where((row) => row['type'] == 'ether' || row['type'] == 'vlan')
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _apply() async {
    if (_isp1 == null || _lanIface == null) {
      _snack('Pilih ISP 1 dan interface LAN.');
      return;
    }
    if (_isp1GatewayCtrl.text.trim().isEmpty) {
      _snack('Gateway ISP 1 wajib diisi.');
      return;
    }
    if (_isp2 != null && _isp2GatewayCtrl.text.trim().isEmpty) {
      _snack('Gateway ISP 2 wajib diisi jika ISP 2 dipilih.');
      return;
    }

    setState(() => _applying = true);
    try {
      if (_method == 'pcc') {
        await _applyPcc();
      } else {
        await _applyEcmp();
      }
      _snack('Load balance berhasil diterapkan.');
    } catch (error) {
      _snack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _applyPcc() async {
    final links = _selectedLinks;
    for (var i = 0; i < links.length; i++) {
      final number = i + 1;
      final link = links[i];
      await _ensureRoutingTable('to-isp$number');
      await widget.api.queryOrThrow([
        '/ip/route/add',
        '=dst-address=0.0.0.0/0',
        '=gateway=${link.gateway}',
        '=routing-table=to-isp$number',
        '=distance=1',
        '=comment=CM-LB-PCC-ROUTE-ISP$number',
      ]);
      await widget.api.queryOrThrow([
        '/ip/firewall/mangle/add',
        '=chain=prerouting',
        '=in-interface=$_lanIface',
        '=dst-address-type=!local',
        '=per-connection-classifier=both-addresses:${links.length}/$i',
        '=action=mark-connection',
        '=new-connection-mark=cm-isp$number-conn',
        '=passthrough=yes',
        '=comment=CM-LB-PCC-CONN-ISP$number',
      ]);
      await widget.api.queryOrThrow([
        '/ip/firewall/mangle/add',
        '=chain=prerouting',
        '=in-interface=$_lanIface',
        '=connection-mark=cm-isp$number-conn',
        '=action=mark-routing',
        '=new-routing-mark=to-isp$number',
        '=passthrough=no',
        '=comment=CM-LB-PCC-MARK-ISP$number',
      ]);
      await widget.api.queryOrThrow([
        '/ip/firewall/nat/add',
        '=chain=srcnat',
        '=out-interface=${link.interfaceName}',
        '=action=masquerade',
        '=comment=CM-LB-NAT-ISP$number',
      ]);
    }
  }

  Future<void> _applyEcmp() async {
    final links = _selectedLinks;
    for (var i = 0; i < links.length; i++) {
      final number = i + 1;
      final link = links[i];
      await widget.api.queryOrThrow([
        '/ip/route/add',
        '=dst-address=0.0.0.0/0',
        '=gateway=${link.gateway}',
        '=distance=1',
        '=comment=CM-LB-ECMP-ISP$number',
      ]);
      await widget.api.queryOrThrow([
        '/ip/firewall/nat/add',
        '=chain=srcnat',
        '=out-interface=${link.interfaceName}',
        '=action=masquerade',
        '=comment=CM-LB-NAT-ISP$number',
      ]);
    }
  }

  Future<void> _ensureRoutingTable(String name) async {
    final existing = await widget.api.query([
      '/routing/table/print',
      '?name=$name',
    ]);
    if (existing.isNotEmpty) return;
    await widget.api.queryOrThrow([
      '/routing/table/add',
      '=name=$name',
      '=fib=yes',
      '=comment=Core Monitor load balance',
    ]);
  }

  List<_WanLink> get _selectedLinks => [
    _WanLink(_isp1!, _isp1GatewayCtrl.text.trim()),
    if (_isp2 != null) _WanLink(_isp2!, _isp2GatewayCtrl.text.trim()),
  ];

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    final ifaceNames = _interfaces
        .map((row) => row['name'] ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Atur pembagian koneksi internet',
            style: TextStyle(
              color: c.txt,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih metode, interface, dan gateway yang akan digunakan.',
            style: TextStyle(color: c.sub, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _methodSection(c),
          const SizedBox(height: 12),
          _interfaceSection(c, ifaceNames),
        ],
      ),
    );
  }

  Widget _methodSection(AppC c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
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
                  'Mark koneksi dan routing per WAN',
                  AppColors.cyan,
                  c,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _methodCard(
                  'ecmp',
                  'ECMP',
                  'Default route equal distance',
                  AppColors.purple,
                  c,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _interfaceSection(AppC c, List<String> ifaceNames) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
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
            (value) => setState(() => _isp1 = value),
          ),
          const SizedBox(height: 8),
          _gatewayField('Gateway ISP 1', _isp1GatewayCtrl, c, AppColors.green),
          const SizedBox(height: 12),
          _ifaceDropdown(
            'ISP 2 (Opsional)',
            _isp2,
            ifaceNames,
            c,
            AppColors.blue,
            (value) => setState(() => _isp2 = value),
          ),
          const SizedBox(height: 8),
          _gatewayField('Gateway ISP 2', _isp2GatewayCtrl, c, AppColors.blue),
          const SizedBox(height: 12),
          _ifaceDropdown(
            'Interface LAN (Wajib)',
            _lanIface,
            ifaceNames,
            c,
            AppColors.orange,
            (value) => setState(() => _lanIface = value),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _applying ? null : _apply,
              icon: _applying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                _applying
                    ? 'Menerapkan...'
                    : 'Apply ${_method.toUpperCase()} Load Balance',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, AppC c) => Text(
    title,
    style: TextStyle(color: c.txt, fontSize: 13, fontWeight: FontWeight.w700),
  );

  Widget _methodCard(
    String type,
    String name,
    String description,
    Color color,
    AppC c,
  ) {
    final active = _method == type;
    return GestureDetector(
      onTap: _applying ? null : () => setState(() => _method = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.10) : c.card2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.65) : c.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              active ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: active ? color : c.sub,
              size: 18,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                color: active ? color : c.txt,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: c.sub, fontSize: 10),
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
    ValueChanged<String?> onChanged,
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
          color: c.card2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : null,
            isExpanded: true,
            dropdownColor: c.card,
            style: TextStyle(color: c.txt),
            hint: Text('Pilih interface', style: TextStyle(color: c.sub)),
            items: items
                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: _applying ? null : onChanged,
          ),
        ),
      ),
    ],
  );

  Widget _gatewayField(
    String label,
    TextEditingController controller,
    AppC c,
    Color color,
  ) => TextField(
    controller: controller,
    enabled: !_applying,
    style: TextStyle(color: c.txt, fontSize: 12),
    decoration: InputDecoration(
      labelText: label,
      hintText: 'contoh: 192.168.1.1',
      prefixIcon: Icon(Icons.alt_route_rounded, color: color, size: 17),
    ),
  );
}

class _WanLink {
  final String interfaceName;
  final String gateway;

  const _WanLink(this.interfaceName, this.gateway);
}
