import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mikrotik_api.dart';
import '../core/theme.dart';
import '../providers/app_provider.dart';
import 'skeleton.dart';

class DashboardInterfaceCard extends StatefulWidget {
  final MikrotikApi api;
  final AppC c;
  final VoidCallback onOpenDetails;

  const DashboardInterfaceCard({
    super.key,
    required this.api,
    required this.c,
    required this.onOpenDetails,
  });

  @override
  State<DashboardInterfaceCard> createState() => _DashboardInterfaceCardState();
}

class _DashboardInterfaceCardState extends State<DashboardInterfaceCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _maxSamples = 60;

  final List<double> _rxHistory = [];
  final List<double> _txHistory = [];
  List<double> _previousRxHistory = [];
  List<double> _previousTxHistory = [];
  List<String> _interfaces = [];
  Timer? _timer;
  late final AnimationController _chartAnimation;
  String? _selected;
  bool _loading = true;
  bool _polling = false;
  int _rx = 0;
  int _tx = 0;
  int? _touchedSample;
  bool _active = true;

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
      _poll();
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (_active) _poll();
    });
  }

  Future<void> _loadInterfaces() async {
    try {
      final rows = await context.read<AppProvider>().cachedInterfaces();
      final names = rows
          .where((row) => row['disabled'] != 'true')
          .map((row) => row['name'] ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _interfaces = names;
        if (_selected == null || !names.contains(_selected)) {
          _selected = names.isEmpty ? null : names.first;
        }
        _loading = false;
      });
      await _poll();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _poll() async {
    final selected = _selected;
    if (selected == null || _polling) return;
    _polling = true;
    try {
      final rows = await widget.api.queryOrThrow([
        '/interface/monitor-traffic',
        '=interface=$selected',
        '=once=',
      ], timeout: const Duration(seconds: 10));
      if (!mounted || selected != _selected || rows.isEmpty) return;
      final rx = int.tryParse(rows.first['rx-bits-per-second'] ?? '0') ?? 0;
      final tx = int.tryParse(rows.first['tx-bits-per-second'] ?? '0') ?? 0;
      setState(() {
        _previousRxHistory = List<double>.from(_rxHistory);
        _previousTxHistory = List<double>.from(_txHistory);
        _rx = rx;
        _tx = tx;
        _append(_rxHistory, rx.toDouble());
        _append(_txHistory, tx.toDouble());
      });
      _chartAnimation.forward(from: 0);
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  void _append(List<double> values, double value) {
    values.add(value);
    if (values.length > _maxSamples) values.removeAt(0);
  }

  String _rate(int bits) {
    if (bits >= 1000000000) {
      return '${(bits / 1000000000).toStringAsFixed(1)} Gbps';
    }
    if (bits >= 1000000) {
      return '${(bits / 1000000).toStringAsFixed(1)} Mbps';
    }
    if (bits >= 1000) return '${(bits / 1000).toStringAsFixed(1)} Kbps';
    return '$bits bps';
  }

  void _selectInterface(String value) {
    if (value == _selected) return;
    setState(() {
      _selected = value;
      _rxHistory.clear();
      _txHistory.clear();
      _previousRxHistory = [];
      _previousTxHistory = [];
      _touchedSample = null;
      _chartAnimation.value = 1;
    });
    _poll();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.sub.withValues(alpha: 0.12)),
      ),
      child: _loading
          ? const Column(
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 125, height: 32, radius: 9),
                    Spacer(),
                    SkeletonBox(width: 38, height: 38, radius: 9),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 31, radius: 9)),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 31, radius: 9)),
                  ],
                ),
                SizedBox(height: 10),
                SkeletonBox(height: 68, radius: 4),
              ],
            )
          : _interfaces.isEmpty
          ? SizedBox(
              height: 90,
              child: Center(
                child: Text(
                  'Interface tidak ditemukan',
                  style: TextStyle(color: c.sub, fontSize: 12),
                ),
              ),
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PopupMenuButton<String>(
                        tooltip: 'Pilih interface',
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, 5),
                        color: c.card,
                        elevation: 4,
                        constraints: const BoxConstraints(
                          minWidth: 180,
                          maxWidth: 260,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: c.border),
                        ),
                        onSelected: _selectInterface,
                        itemBuilder: (_) => _interfaces
                            .map(
                              (name) => PopupMenuItem<String>(
                                value: name,
                                height: 38,
                                child: Row(
                                  children: [
                                    Icon(
                                      name == _selected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      color: name == _selected
                                          ? AppColors.cyan
                                          : c.sub,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: c.txt,
                                          fontSize: 11,
                                          fontWeight: name == _selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: c.bg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.settings_ethernet_rounded,
                                color: AppColors.cyan,
                                size: 15,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  _selected ?? 'Pilih interface',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.txt,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: c.sub,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Lihat aktivitas penuh',
                      onPressed: widget.onOpenDetails,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: c.bg,
                        minimumSize: const Size(38, 38),
                      ),
                      icon: Icon(
                        Icons.open_in_full_rounded,
                        color: c.sub,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _metric('RX', _rate(_rx), AppColors.green, c),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metric('TX', _rate(_tx), AppColors.orange, c),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 72,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      void updateTouch(Offset position) {
                        if (_rxHistory.isEmpty) return;
                        final ratio = (position.dx / constraints.maxWidth)
                            .clamp(0.0, 1.0);
                        final index = (ratio * (_rxHistory.length - 1)).round();
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
                            painter: _MiniTrafficPainter(
                              previousRx: _previousRxHistory,
                              previousTx: _previousTxHistory,
                              rx: _rxHistory,
                              tx: _txHistory,
                              progress: Curves.easeOutCubic.transform(
                                _chartAnimation.value,
                              ),
                              maxSamples: _maxSamples,
                              touchedIndex: _touchedSample,
                              gridColor: c.sub.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _metric(String label, String value, Color color, AppC c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: c.sub, fontSize: 9)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: c.txt,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTrafficPainter extends CustomPainter {
  final List<double> previousRx;
  final List<double> previousTx;
  final List<double> rx;
  final List<double> tx;
  final double progress;
  final int maxSamples;
  final int? touchedIndex;
  final Color gridColor;

  const _MiniTrafficPainter({
    required this.previousRx,
    required this.previousTx,
    required this.rx,
    required this.tx,
    required this.progress,
    required this.maxSamples,
    required this.touchedIndex,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );
    final animatedRx = _interpolate(previousRx, rx);
    final animatedTx = _interpolate(previousTx, tx);
    final maxValue = math.max(
      1.0,
      [...animatedRx, ...animatedTx].fold<double>(0, math.max),
    );
    _line(canvas, size, animatedRx, maxValue, AppColors.green);
    _line(canvas, size, animatedTx, maxValue, AppColors.orange);
    _touch(canvas, size, animatedRx, animatedTx, maxValue);
  }

  List<double> _interpolate(List<double> from, List<double> to) {
    if (to.isEmpty) return const [];
    final shifting = from.length == maxSamples && to.length == maxSamples;
    return List<double>.generate(to.length, (index) {
      final start = shifting
          ? (index + 1 < from.length ? from[index + 1] : from.last)
          : (index < from.length
                ? from[index]
                : (from.isEmpty ? 0 : from.last));
      return start + ((to[index] - start) * progress);
    });
  }

  void _touch(
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
    final x = _sampleX(index, animatedRx.length, size.width);
    final rxY = size.height - animatedRx[index] / maxValue * size.height;
    final txY = size.height - animatedTx[index] / maxValue * size.height;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(x, rxY), 3.5, Paint()..color = AppColors.green);
    canvas.drawCircle(Offset(x, txY), 3.5, Paint()..color = AppColors.orange);

    final text =
        'RX ${_formatRate(animatedRx[index])}\n'
        'TX ${_formatRate(animatedTx[index])}';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = textPainter.width + 12;
    final height = textPainter.height + 8;
    final left = x + width + 6 <= size.width ? x + 6 : x - width - 6;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 3, width, height),
      const Radius.circular(7),
    );
    canvas.drawRRect(box, Paint()..color = const Color(0xE6222235));
    textPainter.paint(canvas, Offset(left + 6, 7));
  }

  String _formatRate(double bits) {
    if (bits >= 1000000000) {
      return '${(bits / 1000000000).toStringAsFixed(2)}G';
    }
    if (bits >= 1000000) {
      return '${(bits / 1000000).toStringAsFixed(2)}M';
    }
    if (bits >= 1000) return '${(bits / 1000).toStringAsFixed(1)}K';
    return '${bits.round()}b';
  }

  void _line(
    Canvas canvas,
    Size size,
    List<double> values,
    double maxValue,
    Color color,
  ) {
    if (values.isEmpty) return;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      points.add(
        Offset(
          _sampleX(i, values.length, size.width),
          size.height - values[i] / maxValue * size.height,
        ),
      );
    }
    final path = _smoothPath(points);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
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

  double _sampleX(int index, int length, double width) {
    if (length <= 1) return width;
    final step = width / math.max(1, maxSamples - 1);
    if (!_isShifting(length)) return index * step;

    final endX = index * step;
    final startX = index + 1 >= length ? width : (index + 1) * step;
    return startX + ((endX - startX) * progress);
  }

  bool _isShifting(int length) {
    return previousRx.length == maxSamples &&
        previousTx.length == maxSamples &&
        length == maxSamples;
  }

  @override
  bool shouldRepaint(covariant _MiniTrafficPainter oldDelegate) => true;
}
