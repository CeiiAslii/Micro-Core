import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mikrotik_api.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';

class InterfaceScreen extends StatefulWidget {
  final MikrotikApi api;
  final int subIndex;
  const InterfaceScreen({super.key, required this.api, required this.subIndex});

  @override
  State<InterfaceScreen> createState() => _InterfaceScreenState();
}

class _InterfaceScreenState extends State<InterfaceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final List<double> _rxHistory = [];
  final List<double> _txHistory = [];
  List<double> _previousRxHistory = [];
  List<double> _previousTxHistory = [];
  List<Map<String, String>> _interfaces = [];
  Timer? _timer;
  late final AnimationController _chartAnimation;
  String? _selected;
  bool _loading = true;
  bool _polling = false;
  int _rx = 0;
  int _tx = 0;
  int _rxBytes = 0;
  int _txBytes = 0;
  int? _touchedSample;
  bool _active = true;
  DateTime? _lastUpdated;

  Map<String, String>? get _selectedData {
    for (final item in _interfaces) {
      if (item['name'] == _selected) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chartAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..value = 1;
    _loadInterfaces();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _chartAnimation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _pollTraffic();
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (_active) _pollTraffic();
    });
  }

  Future<void> _loadInterfaces() async {
    try {
      final rows = await context.read<AppProvider>().cachedInterfaces();
      rows.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      if (!mounted) return;
      setState(() {
        _interfaces = rows;
        _selected ??= rows
            .where((item) => item['disabled'] != 'true')
            .map((item) => item['name'])
            .firstOrNull;
        _loading = false;
      });
      await _pollTraffic();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Gagal membaca interface: $error');
    }
  }

  Future<void> _pollTraffic() async {
    final selected = _selected;
    if (selected == null || _polling) return;
    _polling = true;
    try {
      final results = await Future.wait([
        widget.api.queryOrThrow([
          '/interface/monitor-traffic',
          '=interface=$selected',
          '=once=',
        ], timeout: const Duration(seconds: 8)),
        widget.api.queryOrThrow([
          '/interface/print',
          '?name=$selected',
        ], timeout: const Duration(seconds: 8)),
      ]);
      if (!mounted || selected != _selected) return;

      final traffic = results[0].isNotEmpty ? results[0].first : const {};
      final details = results[1].isNotEmpty ? results[1].first : null;
      final rx = int.tryParse(traffic['rx-bits-per-second'] ?? '0') ?? 0;
      final tx = int.tryParse(traffic['tx-bits-per-second'] ?? '0') ?? 0;
      setState(() {
        _previousRxHistory = List<double>.from(_rxHistory);
        _previousTxHistory = List<double>.from(_txHistory);
        _rx = rx;
        _tx = tx;
        _appendSample(_rxHistory, rx.toDouble());
        _appendSample(_txHistory, tx.toDouble());
        _lastUpdated = DateTime.now();
        if (details != null) {
          _rxBytes = int.tryParse(details['rx-byte'] ?? '0') ?? 0;
          _txBytes = int.tryParse(details['tx-byte'] ?? '0') ?? 0;
          final index = _interfaces.indexWhere(
            (item) => item['name'] == selected,
          );
          if (index != -1) _interfaces[index] = details;
        }
      });
      _chartAnimation.forward(from: 0);
    } catch (_) {
      // Nilai terakhir dipertahankan saat satu polling gagal.
    } finally {
      _polling = false;
    }
  }

  void _appendSample(List<double> history, double value) {
    history.add(value);
    if (history.length > 60) history.removeAt(0);
  }

  void _selectInterface(String name) {
    setState(() {
      _selected = name;
      _rx = 0;
      _tx = 0;
      _rxHistory.clear();
      _txHistory.clear();
      _previousRxHistory = [];
      _previousTxHistory = [];
      _touchedSample = null;
    });
    _pollTraffic();
  }

  String _formatRate(int bits) {
    if (bits >= 1000000000) {
      return '${(bits / 1000000000).toStringAsFixed(1)} Gbps';
    }
    if (bits >= 1000000) {
      return '${(bits / 1000000).toStringAsFixed(1)} Mbps';
    }
    if (bits >= 1000) return '${(bits / 1000).toStringAsFixed(1)} Kbps';
    return '$bits bps';
  }

  String _formatClock(DateTime? time) {
    if (time == null) return '--:--:--';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1099511627776) {
      return '${(bytes / 1099511627776).toStringAsFixed(1)} TB';
    }
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppC(context.watch<AppProvider>().isDark);
    final selected = _selectedData;
    final running = selected?['running'] == 'true';

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.cyan),
      );
    }

    if (widget.subIndex == 1) {
      return _buildStatusList(c);
    }

    return RefreshIndicator(
      color: AppColors.cyan,
      onRefresh: _loadInterfaces,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _interfaceSelector(c),
          const SizedBox(height: 14),
          if (selected != null) ...[
            Row(
              children: [
                Expanded(
                  child: _rateCard(
                    c,
                    'Download',
                    _formatRate(_rx),
                    Icons.download_rounded,
                    AppColors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _rateCard(
                    c,
                    'Upload',
                    _formatRate(_tx),
                    Icons.upload_rounded,
                    AppColors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 230,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Traffic Realtime',
                        style: TextStyle(
                          color: c.txt,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _polling ? null : _pollTraffic,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(28, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: c.sub,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 2),
                      _legend('RX', AppColors.green, c),
                      const SizedBox(width: 10),
                      _legend('TX', AppColors.orange, c),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        void updateTouch(Offset position) {
                          if (_rxHistory.isEmpty) return;
                          final ratio = (position.dx / constraints.maxWidth)
                              .clamp(0.0, 1.0);
                          final index = (ratio * (_rxHistory.length - 1))
                              .round();
                          if (_touchedSample != index) {
                            setState(() => _touchedSample = index);
                          }
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) =>
                              updateTouch(details.localPosition),
                          onHorizontalDragStart: (details) =>
                              updateTouch(details.localPosition),
                          onHorizontalDragUpdate: (details) =>
                              updateTouch(details.localPosition),
                          onHorizontalDragEnd: (_) =>
                              setState(() => _touchedSample = null),
                          onTapUp: (_) => Future<void>.delayed(
                            const Duration(seconds: 2),
                            () {
                              if (mounted) {
                                setState(() => _touchedSample = null);
                              }
                            },
                          ),
                          child: AnimatedBuilder(
                            animation: CurvedAnimation(
                              parent: _chartAnimation,
                              curve: Curves.easeOutCubic,
                            ),
                            builder: (_, _) => CustomPaint(
                              painter: _TrafficChartPainter(
                                previousRx: _previousRxHistory,
                                previousTx: _previousTxHistory,
                                rx: _rxHistory,
                                tx: _txHistory,
                                progress: Curves.easeOutCubic.transform(
                                  _chartAnimation.value,
                                ),
                                touchedIndex: _touchedSample,
                                gridColor: c.sub.withValues(alpha: 0.12),
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update ${_formatClock(_lastUpdated)} - 60 sampel - refresh 3 detik',
                    style: TextStyle(color: c.sub, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _detailRow(
                    c,
                    'Status',
                    running ? 'RUNNING' : 'DOWN',
                    valueColor: running ? AppColors.green : AppColors.red,
                  ),
                  _detailRow(c, 'Type', selected['type'] ?? '-'),
                  _detailRow(c, 'MAC', selected['mac-address'] ?? '-'),
                  _detailRow(c, 'MTU', selected['actual-mtu'] ?? '-'),
                  _detailRow(c, 'Total RX', _formatBytes(_rxBytes)),
                  _detailRow(c, 'Total TX', _formatBytes(_txBytes)),
                  _detailRow(c, 'Link Downs', selected['link-downs'] ?? '0'),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.settings_ethernet_rounded,
                    color: AppColors.orange,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Interface tidak ditemukan',
                    style: TextStyle(color: c.txt, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tarik ke bawah untuk mencoba memuat ulang.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.sub, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusList(AppC c) {
    return RefreshIndicator(
      color: AppColors.cyan,
      onRefresh: _loadInterfaces,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _interfaces.length,
        itemBuilder: (_, index) {
          final item = _interfaces[index];
          final name = item['name'] ?? '-';
          final running = item['running'] == 'true';
          final disabled = item['disabled'] == 'true';
          final color = disabled
              ? AppColors.red
              : running
              ? AppColors.green
              : AppColors.orange;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.settings_ethernet_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: c.txt,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${item['type'] ?? '-'} • '
                        '${item['mac-address'] ?? 'tanpa MAC'}',
                        style: TextStyle(color: c.sub, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  disabled
                      ? 'DISABLED'
                      : running
                      ? 'RUNNING'
                      : 'DOWN',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _interfaceSelector(AppC c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.settings_ethernet_rounded,
                color: AppColors.cyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Pilih Interface',
                style: TextStyle(color: c.txt, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_interfaces.length} interface',
                style: TextStyle(color: c.sub, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selected,
            dropdownColor: c.card,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: c.card2,
              prefixIcon: const Icon(
                Icons.settings_ethernet_rounded,
                color: AppColors.cyan,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: _interfaces.map((item) {
              final name = item['name'] ?? '-';
              final running = item['running'] == 'true';
              return DropdownMenuItem(
                value: name,
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 9,
                      color: running ? AppColors.green : AppColors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.txt),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) _selectInterface(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _rateCard(
    AppC c,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: c.sub, fontSize: 11)),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color, AppC c) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: c.sub, fontSize: 10)),
      ],
    );
  }

  Widget _detailRow(AppC c, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: c.sub, fontSize: 12)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? c.txt,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficChartPainter extends CustomPainter {
  final List<double> previousRx;
  final List<double> previousTx;
  final List<double> rx;
  final List<double> tx;
  final double progress;
  final int? touchedIndex;
  final Color gridColor;

  const _TrafficChartPainter({
    required this.previousRx,
    required this.previousTx,
    required this.rx,
    required this.tx,
    required this.progress,
    required this.touchedIndex,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final animatedRx = _interpolate(previousRx, rx);
    final animatedTx = _interpolate(previousTx, tx);
    final maxValue = math.max(
      1.0,
      [...animatedRx, ...animatedTx].fold<double>(0, math.max),
    );
    _drawLine(canvas, size, animatedRx, maxValue, AppColors.green);
    _drawLine(canvas, size, animatedTx, maxValue, AppColors.orange);
    _drawTouchIndicator(canvas, size, animatedRx, animatedTx, maxValue);
  }

  List<double> _interpolate(List<double> from, List<double> to) {
    if (to.isEmpty) return const [];
    return List<double>.generate(to.length, (index) {
      final start = index < from.length
          ? from[index]
          : (from.isEmpty ? 0 : from.last);
      return start + ((to[index] - start) * progress);
    });
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<double> values,
    double maxValue,
    Color color,
  ) {
    if (values.isEmpty) return;
    final points = <Offset>[];
    final denominator = math.max(59, values.length - 1);
    for (var i = 0; i < values.length; i++) {
      points.add(
        Offset(
          size.width * i / denominator,
          size.height - (values[i] / maxValue * size.height),
        ),
      );
    }
    final path = _smoothPath(points);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final middle = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, middle.dx, middle.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  void _drawTouchIndicator(
    Canvas canvas,
    Size size,
    List<double> animatedRx,
    List<double> animatedTx,
    double maxValue,
  ) {
    final index = touchedIndex;
    if (index == null ||
        index < 0 ||
        index >= animatedRx.length ||
        index >= animatedTx.length) {
      return;
    }

    final denominator = math.max(59, animatedRx.length - 1);
    final x = size.width * index / denominator;
    final rxY = size.height - animatedRx[index] / maxValue * size.height;
    final txY = size.height - animatedTx[index] / maxValue * size.height;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(x, rxY), 4, Paint()..color = AppColors.green);
    canvas.drawCircle(Offset(x, txY), 4, Paint()..color = AppColors.orange);

    final text =
        'RX ${_formatRate(animatedRx[index])}\n'
        'TX ${_formatRate(animatedTx[index])}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final boxWidth = painter.width + 16;
    final boxHeight = painter.height + 10;
    final left = (x + 8 + boxWidth <= size.width) ? x + 8 : x - boxWidth - 8;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 6, boxWidth, boxHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xE6222235));
    painter.paint(canvas, Offset(left + 8, 11));
  }

  String _formatRate(double bits) {
    if (bits >= 1000000000) {
      return '${(bits / 1000000000).toStringAsFixed(2)} Gbps';
    }
    if (bits >= 1000000) {
      return '${(bits / 1000000).toStringAsFixed(2)} Mbps';
    }
    if (bits >= 1000) return '${(bits / 1000).toStringAsFixed(1)} Kbps';
    return '${bits.round()} bps';
  }

  @override
  bool shouldRepaint(covariant _TrafficChartPainter oldDelegate) => true;
}
