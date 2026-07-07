import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';

class HotspotBackupScreen extends StatefulWidget {
  final MikrotikApi api;
  const HotspotBackupScreen({super.key, required this.api});

  @override
  State<HotspotBackupScreen> createState() => _HotspotBackupScreenState();
}

class _HotspotBackupScreenState extends State<HotspotBackupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: AppColors.cyan,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.black,
            unselectedLabelColor: c.sub,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.backup_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Backup'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restore_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Restore'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _BackupTab(api: widget.api),
              _RestoreTab(api: widget.api),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════
// BACKUP TAB
// ════════════════════════════════════════════════════════
class _BackupTab extends StatefulWidget {
  final MikrotikApi api;
  const _BackupTab({required this.api});

  @override
  State<_BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends State<_BackupTab> {
  static const _downloadsChannel = MethodChannel('core_monitor/downloads');
  final _nameCtrl = TextEditingController(text: 'backup-hotspot-user');

  bool _running = false;
  String _log = '';
  bool _success = false;
  bool _hasError = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _setLog(String msg) {
    if (mounted) setState(() => _log = msg);
  }

  Future<void> _startBackup() async {
    final rawName = _sanitizeFileName(_nameCtrl.text);

    setState(() {
      _running = true;
      _success = false;
      _hasError = false;
      _log = '⏳ Memulai backup...';
    });

    try {
      _setLog('⏳ Membaca data user hotspot dari MikroTik...');
      final content = await _buildRscContent();

      if (content.isEmpty) {
        setState(() {
          _running = false;
          _hasError = true;
          _log = '❌ Tidak ada user hotspot!';
        });
        return;
      }

      final fileName = '$rawName.rsc';
      _setLog('⏳ Menyimpan $fileName ke folder Download...');
      final savedPath = await _saveToDevice(fileName, content);

      if (mounted) {
        setState(() {
          _running = false;
          _success = true;
          _log =
              '✅ Backup berhasil!\n\n'
              '📄 $fileName\n'
              '📁 $savedPath';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _hasError = true;
          _log = '❌ Gagal: $e';
        });
      }
    }
  }

  String _sanitizeFileName(String input) {
    final withoutExtension = input.trim().replaceFirst(
      RegExp(r'\.rsc$', caseSensitive: false),
      '',
    );
    final sanitized = withoutExtension
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .trim();
    return sanitized.isEmpty ? 'backup-hotspot-user' : sanitized;
  }

  // Build konten .rsc dari data user hotspot
  Future<String> _buildRscContent() async {
    final users = await widget.api.queryOrThrow([
      '/ip/hotspot/user/print',
    ], timeout: const Duration(seconds: 30));

    if (users.isEmpty) return '';

    return compute(_buildRscFromUsers, users);
  }

  // Build konten .rsc dari daftar user di isolate terpisah
  static String _buildRscFromUsers(List<dynamic> users) {
    final buf = StringBuffer();
    buf.writeln('# Core Monitor Backup');
    buf.writeln('# Generated: ${DateTime.now()}');
    buf.writeln('# Total: ${users.length} users');
    buf.writeln('/ip hotspot user');
    buf.writeln();

    for (final dynamic u in users) {
      final user = u as Map<String, dynamic>;
      final sb = StringBuffer('add');
      void w(String k) {
        final v = (user[k] ?? '').toString().trim();
        if (v.isNotEmpty && v != 'false' && v != '0') {
          if (v.contains(RegExp(r'[\s"\\]'))) {
            final escaped = v.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
            sb.write(' $k="$escaped"');
          } else {
            sb.write(' $k=$v');
          }
        }
      }

      w('name');
      w('password');
      w('profile');
      w('server');
      w('comment');
      w('limit-uptime');
      w('limit-bytes-total');
      buf.writeln(sb.toString());
    }

    return buf.toString();
  }

  // Simpan file ke HP
  Future<String> _saveToDevice(String fileName, String content) async {
    if (Platform.isAndroid) {
      final sdkInt =
          await _downloadsChannel.invokeMethod<int>('getSdkInt') ?? 29;
      if (sdkInt <= 28) {
        final permission = await Permission.storage.request();
        if (!permission.isGranted) {
          throw Exception('Izin penyimpanan diperlukan untuk Android lama.');
        }
      }
      final path = await _downloadsChannel.invokeMethod<String>(
        'saveTextFile',
        {'fileName': fileName, 'content': content},
      );
      if (path == null || path.isEmpty) {
        throw Exception('Lokasi file Download tidak ditemukan.');
      }
      return path;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$fileName');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          _banner(
            icon: Icons.info_outline_rounded,
            color: AppColors.cyan,
            text:
                'Backup mengeksport semua user hotspot '
                'ke file .rsc dan otomatis tersimpan di '
                'folder Download HP.',
            c: c,
          ),

          const SizedBox(height: 16),

          // Form card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.backup_rounded,
                        color: AppColors.cyan,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Backup User Hotspot',
                      style: TextStyle(
                        color: c.txt,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Nama file
                Text(
                  'Nama File Backup',
                  style: TextStyle(
                    color: c.sub,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  style: TextStyle(color: c.txt),
                  enabled: !_running,
                  decoration: InputDecoration(
                    hintText: 'backup-hotspot-user',
                    hintStyle: TextStyle(color: c.sub.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: c.bg,
                    prefixIcon: const Icon(
                      Icons.insert_drive_file_rounded,
                      color: AppColors.cyan,
                      size: 18,
                    ),
                    suffixText: '.rsc',
                    suffixStyle: const TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.bold,
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
                const SizedBox(height: 6),
                Text(
                  'Jika nama sudah ada: backup.rsc → backup(1).rsc',
                  style: TextStyle(
                    color: c.sub.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 20),

                // Button
                _actionButton(
                  label: _running ? 'Sedang Backup...' : 'Mulai Backup',
                  icon: Icons.backup_rounded,
                  loading: _running,
                  color: AppColors.cyan,
                  onTap: _running ? null : _startBackup,
                ),
              ],
            ),
          ),

          // Log output
          if (_log.isNotEmpty) ...[const SizedBox(height: 16), _logBox(c)],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _logBox(AppC c) {
    final color = _success
        ? AppColors.green
        : _hasError
        ? AppColors.red
        : AppColors.cyan;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_running)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
            ),
          Expanded(
            child: Text(
              _log,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// RESTORE TAB
// ════════════════════════════════════════════════════════
class _RestoreTab extends StatefulWidget {
  final MikrotikApi api;
  const _RestoreTab({required this.api});

  @override
  State<_RestoreTab> createState() => _RestoreTabState();
}

class _RestoreTabState extends State<_RestoreTab> {
  bool _running = false;
  String _log = '';
  bool _success = false;
  bool _hasError = false;
  String _fileName = '';
  int _total = 0;
  int _restored = 0;

  void _setLog(String msg) {
    if (mounted) setState(() => _log = msg);
  }

  Future<void> _pickAndRestore() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['rsc', 'txt'],
        dialogTitle: 'Pilih file backup .rsc',
      );
    } catch (e) {
      _showSnack('❌ Tidak bisa buka file picker: $e');
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final path = picked.path ?? '';
    if (path.isEmpty) {
      _showSnack('❌ Tidak bisa membaca path file!');
      return;
    }

    setState(() {
      _running = true;
      _success = false;
      _hasError = false;
      _fileName = picked.name;
      _total = 0;
      _restored = 0;
      _log = '⏳ Membaca file ${picked.name}...';
    });

    try {
      final content = await File(path).readAsString();

      if (content.trim().isEmpty) {
        setState(() {
          _running = false;
          _hasError = true;
          _log = '❌ File kosong atau tidak valid!';
        });
        return;
      }

      await _manualRestore(content);
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _hasError = true;
          _log = '❌ Error: $e';
        });
      }
    }
  }

  // Parse file .rsc dan add user satu per satu
  Future<void> _manualRestore(String content) async {
    _setLog('⏳ Parsing file backup...');

    final lines = content
        .split('\n')
        .where((l) => l.trim().startsWith('add '))
        .toList();

    if (lines.isEmpty) {
      setState(() {
        _running = false;
        _hasError = true;
        _log =
            '❌ Tidak ada data user di file ini!\n\n'
            'Pastikan format file .rsc benar.';
      });
      return;
    }

    setState(() {
      _total = lines.length;
      _log = '⏳ Memulihkan $_total user...';
    });

    int ok = 0;
    int fail = 0;

    for (final line in lines) {
      try {
        final params = _parseRscLine(line.trim());
        if (params != null && params.isNotEmpty) {
          await widget.api.queryOrThrow(['/ip/hotspot/user/add', ...params]);
          ok++;
        } else {
          fail++;
        }
      } catch (_) {
        fail++;
      }

      if (mounted) {
        setState(() {
          _restored = ok;
          _log = '⏳ Memulihkan... ($ok/$_total)';
        });
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (mounted) {
      setState(() {
        _running = false;
        _success = ok > 0;
        _hasError = ok == 0;
        _log = ok > 0
            ? '✅ Restore selesai!\n\n'
                  '✔ Berhasil: $ok user\n'
                  '${fail > 0 ? '⚠ Gagal/duplikat: $fail user' : ''}'
            : '❌ Restore gagal.\n\n'
                  'Tidak ada user yang berhasil dipulihkan.\n'
                  'Gagal/duplikat: $fail user';
      });
    }
  }

  // Parse satu baris RSC → list parameter API
  List<String>? _parseRscLine(String line) {
    if (!line.startsWith('add ')) return null;
    final params = line.substring(4).trim();
    final result = <String>[];
    final regex = RegExp(r'([\w-]+)=("(?:\\.|[^"])*"|\S+)');
    for (final match in regex.allMatches(params)) {
      final key = match.group(1) ?? '';
      var val = match.group(2) ?? '';
      if (val.length >= 2 && val.startsWith('"') && val.endsWith('"')) {
        val = val
            .substring(1, val.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\');
      }
      if (key.isNotEmpty && val.isNotEmpty) {
        result.add('=$key=$val');
      }
    }
    return result.isEmpty ? null : result;
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(
            icon: Icons.info_outline_rounded,
            color: AppColors.orange,
            text:
                'Pilih file .rsc dari HP. Aplikasi '
                'otomatis upload ke MikroTik lalu jalankan '
                '/import — tanpa perlu ketik manual.',
            c: c,
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.restore_rounded,
                        color: AppColors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Restore User Hotspot',
                      style: TextStyle(
                        color: c.txt,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // File terpilih
                if (_fileName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_rounded,
                          color: AppColors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'File dipilih:',
                                style: TextStyle(color: c.sub, fontSize: 10),
                              ),
                              Text(
                                _fileName,
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Progress
                if (_running && _total > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress:',
                        style: TextStyle(color: c.sub, fontSize: 12),
                      ),
                      Text(
                        '$_restored / $_total',
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _total > 0
                          ? (_restored / _total).clamp(0.0, 1.0)
                          : null,
                      backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.orange,
                      ),
                      minHeight: 7,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                _actionButton(
                  label: _running
                      ? 'Sedang Restore...'
                      : 'Pilih File & Restore',
                  icon: Icons.folder_open_rounded,
                  loading: _running,
                  color: AppColors.orange,
                  onTap: _running ? null : _pickAndRestore,
                ),
              ],
            ),
          ),

          if (_log.isNotEmpty) ...[const SizedBox(height: 16), _logBox(c)],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _logBox(AppC c) {
    final color = _success
        ? AppColors.green
        : _hasError
        ? AppColors.red
        : AppColors.orange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_running)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
            ),
          Expanded(
            child: Text(
              _log,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════
Widget _banner({
  required IconData icon,
  required Color color,
  required String text,
  required AppC c,
}) => Container(
  padding: const EdgeInsets.all(13),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.07),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: color.withValues(alpha: 0.2)),
  ),
  child: Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: c.sub, fontSize: 12, height: 1.4),
        ),
      ),
    ],
  ),
);

Widget _actionButton({
  required String label,
  required IconData icon,
  required bool loading,
  required Color color,
  required VoidCallback? onTap,
}) => SizedBox(
  width: double.infinity,
  height: 50,
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: onTap != null ? color : color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      boxShadow: onTap != null
          ? [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    ),
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Mohon tunggu...',
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
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
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
);
