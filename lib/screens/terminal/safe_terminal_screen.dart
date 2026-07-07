import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/mikrotik_api.dart';
import '../../core/safe_terminal.dart';

class SafeTerminalScreen extends StatefulWidget {
  final MikrotikApi api;

  const SafeTerminalScreen({super.key, required this.api});

  @override
  State<SafeTerminalScreen> createState() => _SafeTerminalScreenState();
}

class _SafeTerminalScreenState extends State<SafeTerminalScreen> {
  static const _parser = SafeTerminalParser();
  static const _historyKey = 'safeTerminalHistory';
  static const _presets = [
    ('resource', '/system/resource/print'),
    ('interfaces', '/interface/print'),
    ('addresses', '/ip/address/print'),
    ('routes', '/ip/route/print'),
    ('leases', '/ip/dhcp-server/lease/print'),
    ('logs', '/log/print'),
    ('ping', '/ping 8.8.8.8 count=4'),
  ];

  final _commandCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final List<_ConsoleBlock> _blocks = [];
  List<String> _history = [];
  int _historyIndex = -1;
  bool _running = false;

  String get _prompt =>
      '${widget.api.username}@${widget.api.host}:${widget.api.port}';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _blocks.add(
      const _ConsoleBlock(
        command: '',
        output:
            'Core Monitor RouterOS Terminal\n'
            'Ketik "help" untuk bantuan. Full access aktif.',
      ),
    );
  }

  @override
  void dispose() {
    _commandCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _history = preferences.getStringList(_historyKey) ?? [];
    });
  }

  Future<void> _saveHistory(String command) async {
    _history.remove(command);
    _history.insert(0, command);
    if (_history.length > 30) _history.removeRange(30, _history.length);
    _historyIndex = -1;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_historyKey, _history);
  }

  Future<void> _run() async {
    if (_running) return;
    final raw = _commandCtrl.text.trim();
    if (raw.isEmpty) return;
    _commandCtrl.clear();
    _focusNode.requestFocus();

    if (await _handleLocalCommand(raw)) return;

    TerminalCommand command;
    try {
      command = _parser.parse(raw);
    } on FormatException catch (error) {
      _append(raw, 'bash: ${error.message}', isError: true);
      return;
    }

    setState(() => _running = true);
    final stopwatch = Stopwatch()..start();
    try {
      final rows = await widget.api.queryOrThrow(
        command.apiWords,
        timeout: const Duration(seconds: 30),
      );
      stopwatch.stop();
      _append(raw, formatTerminalRows(rows), duration: stopwatch.elapsed);
      await _saveHistory(raw);
    } catch (error) {
      stopwatch.stop();
      _append(
        raw,
        error.toString().replaceFirst('Exception: ', ''),
        duration: stopwatch.elapsed,
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<bool> _handleLocalCommand(String raw) async {
    switch (raw.toLowerCase()) {
      case 'clear':
      case 'cls':
        setState(() => _blocks.clear());
        return true;
      case 'help':
        _append(
          raw,
          'COMMAND FORMAT\n'
          '  /system/resource/print\n'
          '  system resource print\n'
          '  /interface print where running=true\n'
          '  /ping 8.8.8.8 count=4\n\n'
          'LOCAL COMMANDS\n'
          '  help      tampilkan bantuan\n'
          '  clear     bersihkan layar\n'
          '  history   tampilkan riwayat',
        );
        return true;
      case 'history':
        final output = _history.isEmpty
            ? 'history is empty'
            : _history.reversed
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) => '${entry.key + 1}  ${entry.value}')
                  .join('\n');
        _append(raw, output);
        return true;
      default:
        return false;
    }
  }

  void _append(
    String command,
    String output, {
    Duration? duration,
    bool isError = false,
  }) {
    if (!mounted) return;
    setState(() {
      _blocks.add(
        _ConsoleBlock(
          command: command,
          output: output,
          duration: duration,
          isError: isError,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateHistory(int direction) {
    if (_history.isEmpty) return;
    _historyIndex = (_historyIndex + direction)
        .clamp(-1, _history.length - 1)
        .toInt();
    final value = _historyIndex == -1 ? '' : _history[_historyIndex];
    _commandCtrl.text = value;
    _commandCtrl.selection = TextSelection.collapsed(offset: value.length);
    _focusNode.requestFocus();
  }

  void _useCommand(String command) {
    _commandCtrl.text = command;
    _commandCtrl.selection = TextSelection.collapsed(offset: command.length);
    _focusNode.requestFocus();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyConsole() {
    final text = _blocks
        .map(
          (block) => [
            if (block.command.isNotEmpty) '$_prompt\$ ${block.command}',
            block.output,
          ].join('\n'),
        )
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Isi terminal disalin')));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF050805),
      child: Column(
        children: [
          _titleBar(),
          _presetBar(),
          Expanded(
            child: SafeArea(
              top: false,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _focusNode.requestFocus();
                  _scrollToBottom();
                },
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  itemCount: _blocks.length + 1,
                  itemBuilder: (_, index) {
                    if (index == _blocks.length) return _terminalInput();
                    return _consoleBlock(_blocks[index]);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleBar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFF151A15),
      child: Row(
        children: [
          const _WindowDot(Color(0xFFFF5F56)),
          const SizedBox(width: 6),
          const _WindowDot(Color(0xFFFFBD2E)),
          const SizedBox(width: 6),
          const _WindowDot(Color(0xFF27C93F)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$_prompt - routeros',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFB7C5B7),
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ),
          const Text(
            'FULL ACCESS',
            style: TextStyle(
              color: Color(0xFFFFB454),
              fontFamily: 'monospace',
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            tooltip: 'Salin terminal',
            visualDensity: VisualDensity.compact,
            onPressed: _copyConsole,
            icon: const Icon(
              Icons.copy_rounded,
              color: Color(0xFF849084),
              size: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetBar() {
    return Container(
      height: 34,
      color: const Color(0xFF0D120D),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: _presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 5),
        itemBuilder: (_, index) {
          final preset = _presets[index];
          return InkWell(
            onTap: () => _useCommand(preset.$2),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1A211A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                preset.$1,
                style: const TextStyle(
                  color: Color(0xFF9AAC9A),
                  fontFamily: 'monospace',
                  fontSize: 9,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _consoleBlock(_ConsoleBlock block) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.command.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _prompt,
                    style: const TextStyle(color: Color(0xFF64E572)),
                  ),
                  const TextSpan(
                    text: r':~$ ',
                    style: TextStyle(color: Color(0xFF59B7FF)),
                  ),
                  TextSpan(
                    text: block.command,
                    style: const TextStyle(color: Color(0xFFF1F5F1)),
                  ),
                ],
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          if (block.command.isNotEmpty) const SizedBox(height: 3),
          SelectableText(
            block.output,
            style: TextStyle(
              color: block.isError
                  ? const Color(0xFFFF7474)
                  : const Color(0xFFC5D0C5),
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.4,
            ),
          ),
          if (block.duration != null)
            Text(
              '[completed in ${block.duration!.inMilliseconds} ms]',
              style: const TextStyle(
                color: Color(0xFF536053),
                fontFamily: 'monospace',
                fontSize: 8,
              ),
            ),
        ],
      ),
    );
  }

  Widget _terminalInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _prompt,
                style: const TextStyle(color: Color(0xFF64E572)),
              ),
              const TextSpan(
                text: r':~$ ',
                style: TextStyle(color: Color(0xFF59B7FF)),
              ),
            ],
          ),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
        Expanded(
          child: TextField(
            controller: _commandCtrl,
            focusNode: _focusNode,
            autofocus: true,
            enabled: !_running,
            textInputAction: TextInputAction.send,
            onTap: _scrollToBottom,
            onSubmitted: (_) => _run(),
            cursorColor: const Color(0xFF64E572),
            cursorWidth: 7,
            cursorHeight: 14,
            style: const TextStyle(
              color: Color(0xFFF1F5F1),
              fontFamily: 'monospace',
              fontSize: 10.5,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isCollapsed: true,
            ),
          ),
        ),
        if (_running)
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFF64E572),
            ),
          )
        else ...[
          InkWell(
            onTap: () => _navigateHistory(1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Color(0xFF536053),
                size: 16,
              ),
            ),
          ),
          InkWell(
            onTap: () => _navigateHistory(-1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF536053),
                size: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConsoleBlock {
  final String command;
  final String output;
  final Duration? duration;
  final bool isError;

  const _ConsoleBlock({
    required this.command,
    required this.output,
    this.duration,
    this.isError = false,
  });
}

class _WindowDot extends StatelessWidget {
  final Color color;

  const _WindowDot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
