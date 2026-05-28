import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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
              gradient: const LinearGradient(
                colors: [AppColors.cyan, AppColors.cyanDark],
              ),
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

class _BackupTab extends StatefulWidget {
  final MikrotikApi api;
  const _BackupTab({required this.api});

  @override
  State<_BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends State<_BackupTab> {
  final _nameCtrl = TextEditingController(text: 'backup_hotspot_user');
  bool _backing = false;
  String _status = '';
  String _statusFile = '';
  bool _done = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _startBackup() async {
    final fileName = _nameCtrl.text.trim().isEmpty
        ? 'backup_hotspot_user'
        : _nameCtrl.text.trim().replaceAll('.rsc', '');

    setState(() {
      _backing = true;
      _done = false;
      _status = '⏳ Mengirim perintah export ke MikroTik...';
      _statusFile = '';
    });

    try {
      await widget.api.query(['/ip/hotspot/user/export', '=file=$fileName']);
      setState(() => _status = '⏳ Menunggu file dibuat di router...');
      await Future.delayed(const Duration(seconds: 3));
      setState(() => _status = '⏳ Mengambil isi file dari router...');

      final files = await widget.api.query(['/file/print', '?name~$fileName']);
      if (files.isEmpty) {
        setState(() {
          _backing = false;
          _status = '❌ File tidak ditemukan di router!';
        });
        return;
      }

      final fileDetail = await widget.api.query([
        '/file/print',
        '?name=${files[0]['name']}',
        '=detail=',
      ]);

      String content = '';
      if (fileDetail.isNotEmpty) {
        content = fileDetail[0]['contents'] ?? '';
      }

      if (content.isEmpty) {
        setState(() => _status = '⏳ Mengambil data user hotspot...');

        final users = await widget.api.query(['/ip/hotspot/user/print']);
        final buffer = StringBuffer();
        buffer.writeln('# Core Monitor Backup - ${DateTime.now()}');
        buffer.writeln('# /ip hotspot user');
        buffer.writeln();

        for (final u in users) {
          final cmd = StringBuffer('add');
          if ((u['name'] ?? '').isNotEmpty) {
            cmd.write(' name="${u['name']}"');
          }
          if ((u['password'] ?? '').isNotEmpty) {
            cmd.write(' password="${u['password']}"');
          }
          if ((u['profile'] ?? '').isNotEmpty) {
            cmd.write(' profile="${u['profile']}"');
          }
          if ((u['server'] ?? '').isNotEmpty) {
            cmd.write(' server="${u['server']}"');
          }
          if ((u['comment'] ?? '').isNotEmpty) {
            cmd.write(' comment="${u['comment']}"');
          }
          if ((u['limit-uptime'] ?? '').isNotEmpty) {
            cmd.write(' limit-uptime=${u['limit-uptime']}');
          }
          if ((u['limit-bytes-total'] ?? '').isNotEmpty) {
            cmd.write(' limit-bytes-total=${u['limit-bytes-total']}');
          }
          buffer.writeln(cmd.toString());
        }
        content = buffer.toString();
      }

      setState(() => _status = '⏳ Menyimpan file ke HP...');

      String savePath = '';
      try {
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) {
            dir = await getExternalStorageDirectory();
          }
        } else {
          dir = await getApplicationDocumentsDirectory();
        }

        final file = File('${dir!.path}/$fileName.rsc');
        await file.writeAsString(content);
        savePath = file.path;
      } catch (e) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName.rsc');
        await file.writeAsString(content);
        savePath = file.path;
      }

      setState(() {
        _backing = false;
        _done = true;
        _status = '✅ Backup berhasil!';
        _statusFile = savePath;
      });
    } catch (e) {
      setState(() {
        _backing = false;
        _status = '❌ Error: $e';
      });
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_rounded, color: AppColors.cyan, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Backup akan mengexport semua user hotspot ke file .rsc dan otomatis tersimpan di folder Download HP kamu.',
                    style: TextStyle(color: c.sub, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                  decoration: InputDecoration(
                    hintText: 'backup_hotspot_user',
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
                const SizedBox(height: 8),
                Text(
                  'Contoh: userku → userku.rsc',
                  style: TextStyle(
                    color: c.sub.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _backing || _done
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.cyan, AppColors.cyanDark],
                            ),
                      color: _backing
                          ? AppColors.cyan.withValues(alpha: 0.3)
                          : _done
                          ? AppColors.green.withValues(alpha: 0.2)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _backing || _done
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.cyan.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      onPressed: _backing ? null : _startBackup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _backing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Sedang Backup...',
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
                                Icon(
                                  _done
                                      ? Icons.check_circle_rounded
                                      : Icons.backup_rounded,
                                  color: _done ? AppColors.green : Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _done ? 'Backup Lagi' : 'Mulai Backup',
                                  style: TextStyle(
                                    color: _done
                                        ? AppColors.green
                                        : Colors.white,
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
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _done
                    ? AppColors.green.withValues(alpha: 0.08)
                    : _status.startsWith('❌')
                    ? AppColors.red.withValues(alpha: 0.08)
                    : AppColors.cyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _done
                      ? AppColors.green.withValues(alpha: 0.3)
                      : _status.startsWith('❌')
                      ? AppColors.red.withValues(alpha: 0.3)
                      : AppColors.cyan.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_backing)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cyan,
                          ),
                        ),
                      if (_backing) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: _done
                                ? AppColors.green
                                : _status.startsWith('❌')
                                ? AppColors.red
                                : AppColors.cyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_statusFile.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                color: AppColors.green,
                                size: 15,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'File tersimpan di:',
                                style: TextStyle(
                                  color: AppColors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusFile,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _RestoreTab extends StatefulWidget {
  final MikrotikApi api;
  const _RestoreTab({required this.api});

  @override
  State<_RestoreTab> createState() => _RestoreTabState();
}

class _RestoreTabState extends State<_RestoreTab> {
  bool _restoring = false;
  String _status = '';
  String _fileName = '';
  bool _done = false;
  int _totalUsers = 0;
  int _restoredUsers = 0;
  String _restoreMode = 'import';

  Future<void> _pickAndRestore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['rsc', 'txt'],
        dialogTitle: 'Pilih file backup .rsc',
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final path = file.path ?? '';
      final fName = file.name;

      if (path.isEmpty) {
        _snack('❌ Tidak bisa membaca file!');
        return;
      }

      setState(() {
        _restoring = true;
        _done = false;
        _fileName = fName;
        _status = '⏳ Membaca file $fName...';
        _totalUsers = 0;
        _restoredUsers = 0;
      });

      final content = await File(path).readAsString();

      if (_restoreMode == 'manual') {
        await _manualRestore(content);
      } else {
        await _importRestore(path, fName, content);
      }
    } catch (e) {
      setState(() {
        _restoring = false;
        _status = '❌ Error: $e';
      });
    }
  }

  Future<void> _importRestore(String path, String fName, String content) async {
    try {
      setState(() => _status = '⏳ Upload file ke MikroTik...');
      final cleanName = fName.endsWith('.rsc') ? fName : '$fName.rsc';

      await widget.api.query([
        '/file/add',
        '=name=$cleanName',
        '=contents=$content',
      ]);
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _status = '⏳ Menjalankan import di MikroTik...');
      await widget.api.query(['/import', '=file-name=$cleanName']);
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _restoring = false;
        _done = true;
        _status = '✅ Restore berhasil via import!';
      });
    } catch (e) {
      setState(() => _status = '⚠️ Import gagal, coba manual restore...');
      await _manualRestore(content);
    }
  }

  Future<void> _manualRestore(String content) async {
    try {
      setState(() => _status = '⏳ Parsing file backup...');
      final lines = content.split('\n');
      final addLines = lines
          .where(
            (l) =>
                l.trim().startsWith('add ') || l.trim().startsWith('add name='),
          )
          .toList();
      _totalUsers = addLines.length;

      if (_totalUsers == 0) {
        setState(() {
          _restoring = false;
          _status = '❌ Tidak ada data user di file ini!';
        });
        return;
      }

      setState(() => _status = '⏳ Restoring $_totalUsers user...');

      int success = 0;
      int failed = 0;
      for (final line in addLines) {
        try {
          final parsed = _parseRscLine(line.trim());
          if (parsed == null) continue;
          await widget.api.query(['/ip/hotspot/user/add', ...parsed]);
          success++;
          setState(() {
            _restoredUsers = success;
            _status = '⏳ Restoring... ($success/$_totalUsers)';
          });
        } catch (_) {
          failed++;
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }

      setState(() {
        _restoring = false;
        _done = true;
        _status =
            '✅ Restore selesai!\n$success berhasil${failed > 0 ? ', $failed gagal (mungkin sudah ada)' : ''}';
      });
    } catch (e) {
      setState(() {
        _restoring = false;
        _status = '❌ Error: $e';
      });
    }
  }

  List<String>? _parseRscLine(String line) {
    if (!line.startsWith('add ')) return null;
    final cmd = <String>[];
    final params = line.substring(4);
    final regex = RegExp(r'(\w[\w-]*)=("([^"]*)"|([\S]+))');
    final matches = regex.allMatches(params);

    for (final m in matches) {
      final key = m.group(1) ?? '';
      final value = m.group(3) ?? m.group(4) ?? '';
      if (key.isNotEmpty) cmd.add('=$key=$value');
    }

    return cmd.isEmpty ? null : cmd;
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_rounded,
                  color: AppColors.orange,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pilih file .rsc backup dan aplikasi akan otomatis restore semua user ke MikroTik tanpa perlu ketik manual di terminal.',
                    style: TextStyle(color: c.sub, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Restore',
                  style: TextStyle(
                    color: c.txt,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _modeCard(
                        'import',
                        Icons.upload_file_rounded,
                        'Via Import',
                        'Upload file ke MikroTik lalu jalankan /import otomatis',
                        AppColors.cyan,
                        c,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _modeCard(
                        'manual',
                        Icons.playlist_add_rounded,
                        'Manual Parse',
                        'Parse file & add user satu per satu via API',
                        AppColors.orange,
                        c,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                if (_fileName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_rounded,
                          color: AppColors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'File dipilih:',
                                style: TextStyle(color: c.sub, fontSize: 11),
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
                if (_restoring && _totalUsers > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress:',
                        style: TextStyle(color: c.sub, fontSize: 12),
                      ),
                      Text(
                        '$_restoredUsers / $_totalUsers',
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
                      value: _totalUsers > 0
                          ? _restoredUsers / _totalUsers
                          : null,
                      backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.orange,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _restoring
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.orange, Color(0xFFE65100)],
                            ),
                      color: _restoring
                          ? AppColors.orange.withValues(alpha: 0.3)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _restoring
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.orange.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      onPressed: _restoring ? null : _pickAndRestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _restoring
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
                                  'Sedang Restore...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Pilih File & Restore',
                                  style: TextStyle(
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
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _done
                    ? AppColors.green.withValues(alpha: 0.08)
                    : _status.startsWith('❌')
                    ? AppColors.red.withValues(alpha: 0.08)
                    : AppColors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _done
                      ? AppColors.green.withValues(alpha: 0.3)
                      : _status.startsWith('❌')
                      ? AppColors.red.withValues(alpha: 0.3)
                      : AppColors.orange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_restoring)
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        color: _done
                            ? AppColors.green
                            : _status.startsWith('❌')
                            ? AppColors.red
                            : AppColors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _modeCard(
    String mode,
    IconData icon,
    String title,
    String desc,
    Color color,
    AppC c,
  ) {
    final active = _restoreMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _restoreMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : c.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : c.sub.withValues(alpha: 0.2),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: active ? color : c.sub, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: active ? color : c.txt,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(color: c.sub, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
