import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';
import '../../widgets/skeleton.dart';

class IpScreen extends StatefulWidget {
  final MikrotikApi api;
  final int subIndex;

  const IpScreen({super.key, required this.api, required this.subIndex});

  @override
  State<IpScreen> createState() => _IpScreenState();
}

class _IpScreenState extends State<IpScreen> {
  List<Map<String, String>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(IpScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subIndex != widget.subIndex) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _data = [];
    });
    try {
      List<Map<String, String>> r = [];
      switch (widget.subIndex) {
        case 0:
          r = await widget.api.query(['/ip/address/print']);
          break;
        case 1:
          r = await widget.api.query(['/ip/pool/print']);
          break;
        case 2:
          r = await widget.api.query(['/ip/dhcp-server/print']);
          break;
        case 3:
          r = await widget.api.query(['/ip/dhcp-server/lease/print']);
          break;
      }
      if (mounted)
        setState(() {
          _data = r;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _title() {
    switch (widget.subIndex) {
      case 0:
        return 'IP Address';
      case 1:
        return 'IP Pool';
      case 2:
        return 'DHCP Server';
      case 3:
        return 'DHCP Lease';
      default:
        return 'IP';
    }
  }

  Color _color() {
    switch (widget.subIndex) {
      case 0:
        return AppColors.cyan;
      case 1:
        return AppColors.green;
      case 2:
        return AppColors.orange;
      case 3:
        return AppColors.blue;
      default:
        return AppColors.cyan;
    }
  }

  IconData _icon() {
    switch (widget.subIndex) {
      case 0:
        return Icons.grid_view_rounded;
      case 1:
        return Icons.pool_rounded;
      case 2:
        return Icons.router_rounded;
      case 3:
        return Icons.devices_rounded;
      default:
        return Icons.lan_rounded;
    }
  }

  Widget _buildItem(Map<String, String> item, AppC c) {
    final color = _color();
    switch (widget.subIndex) {
      case 0: // IP Address
        return _card(c, color, [
          _row('Address', item['address'] ?? '-', c),
          _row('Interface', item['interface'] ?? '-', c),
          _row('Network', item['network'] ?? '-', c),
          if ((item['comment'] ?? '').isNotEmpty)
            _row('Comment', item['comment'] ?? '', c),
        ]);

      case 1: // IP Pool
        return _card(c, color, [
          _row('Nama', item['name'] ?? '-', c),
          _row('Ranges', item['ranges'] ?? '-', c),
          if ((item['next-pool'] ?? '').isNotEmpty)
            _row('Next Pool', item['next-pool'] ?? '-', c),
        ]);

      case 2: // DHCP Server
        final disabled = item['disabled'] == 'true';
        return _card(c, disabled ? AppColors.red : color, [
          _row('Nama', item['name'] ?? '-', c),
          _row('Interface', item['interface'] ?? '-', c),
          _row('Pool', item['address-pool'] ?? '-', c),
          _row(
            'Status',
            disabled ? 'DISABLED' : 'AKTIF',
            c,
            valueColor: disabled ? AppColors.red : AppColors.green,
          ),
        ]);

      case 3: // DHCP Lease
        final dynamic_ = item['dynamic'] == 'true';
        final hostname = item['host-name'] ?? '';
        return _card(c, color, [
          _row('IP', item['address'] ?? '-', c),
          _row('MAC', item['mac-address'] ?? '-', c),
          if (hostname.isNotEmpty) _row('Hostname', hostname, c),
          _row(
            'Status',
            dynamic_ ? 'Dynamic' : 'Static',
            c,
            valueColor: dynamic_ ? AppColors.orange : AppColors.cyan,
          ),
          if ((item['expires-after'] ?? '').isNotEmpty)
            _row('Expires', item['expires-after'] ?? '-', c),
        ]);

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);
    final color = _color();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(),
                      style: TextStyle(
                        color: c.txt,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_data.length} data',
                      style: TextStyle(color: c.sub, fontSize: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _fetch,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.refresh_rounded, color: color, size: 18),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SkeletonBox(height: 90, radius: 12),
                  ),
                )
              : _data.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icon(), color: c.sub, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada data',
                        style: TextStyle(color: c.sub, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: color,
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _data.length,
                    itemBuilder: (_, i) => _buildItem(_data[i], c),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _card(AppC c, Color color, List<Widget> rows) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(children: rows),
  );

  Widget _row(String label, String value, AppC c, {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label, style: TextStyle(color: c.sub, fontSize: 12)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? c.txt,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}
