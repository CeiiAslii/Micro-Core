import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../core/mikrotik_ftp.dart';
import '../../providers/app_provider.dart';

class StorageScreen extends StatefulWidget {
  final MikrotikApi api;
  const StorageScreen({super.key, required this.api});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  static const _downloadsChannel = MethodChannel('core_monitor/downloads');

  List<Map<String, String>> _files = [];
  bool _loading = true;
  bool _busy = false;
  int _totalSpace = 0;
  int _freeSpace = 0;

  MikrotikFtp get _ftp => MikrotikFtp(
    host: widget.api.host,
    username: widget.api.username,
    password: widget.api.password,
  );

  @override
  void initState() {
    super.initState();
    _fetchStorage();
    _fetchFiles();
  }

  Future<void> _fetchStorage() async {
    try {
      final r = await widget.api.query(['/system/resource/print']);
      if (r.isNotEmpty && mounted) {
        setState(() {
          _totalSpace = int.tryParse(r[0]['total-hdd-space'] ?? '0') ?? 0;
          _freeSpace = int.tryParse(r[0]['free-hdd-space'] ?? '0') ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchFiles() async {
    setState(() => _loading = true);
    try {
      final r = await widget.api.query(['/file/print']);
      if (mounted) {
        setState(() {
          _files = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteFile(String name) async {
    final c = AppC(context.read<AppProvider>().isDark);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus File', style: TextStyle(color: c.txt)),
        content: Text('Hapus "$name"?', style: TextStyle(color: c.sub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: c.sub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.queryOrThrow(['/file/remove', '=numbers=$name']);
      _fetchFiles();
      _fetchStorage();
    }
  }

  Future<void> _createFolder() async {
    final c = AppC(context.read<AppProvider>().isDark);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Buat Folder', style: TextStyle(color: c.txt)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: c.txt),
          decoration: InputDecoration(
            hintText: 'contoh: voucher',
            hintStyle: TextStyle(color: c.sub),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: c.sub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    if (name.contains('/') || name.contains('\\')) {
      _showSnack('Nama folder tidak boleh pakai garis miring.', isError: true);
      return;
    }

    await _runFileAction(() async {
      await _ftp.createDirectory(name);
      await _fetchFiles();
      _showSnack('Folder "$name" dibuat.');
    });
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      _showSnack('Gagal membuka pemilih file: $e', isError: true);
      return;
    }
    final picked = result?.files.single;
    if (picked == null) return;

    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null) {
      _showSnack('File tidak bisa dibaca.', isError: true);
      return;
    }

    await _runFileAction(() async {
      await _ftp.upload(picked.name, bytes!);
      await _fetchFiles();
      await _fetchStorage();
      _showSnack('Upload "${picked.name}" selesai.');
    });
  }

  Future<void> _downloadFile(String name) async {
    await _runFileAction(() async {
      final bytes = await _ftp.download(name);
      final path = await _saveBytesToDevice(name, bytes);
      _showSnack('File tersimpan: $path');
    });
  }

  Future<void> _runFileAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _showSnack('Aksi storage gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _saveBytesToDevice(String fileName, Uint8List bytes) async {
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
        'saveBytesFile',
        {'fileName': fileName, 'bytes': bytes},
      );
      if (path == null || path.isEmpty) {
        throw Exception('Lokasi file Download tidak ditemukan.');
      }
      return path;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.green,
      ),
    );
  }

  String _fmtSize(String size) {
    final v = int.tryParse(size) ?? 0;
    if (v >= 1073741824) return '${(v / 1073741824).toStringAsFixed(1)} GB';
    if (v >= 1048576) return '${(v / 1048576).toStringAsFixed(1)} MB';
    if (v >= 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
    return '$v B';
  }

  IconData _fileIcon(String name) {
    if (name.endsWith('.backup')) return Icons.backup_rounded;
    if (name.endsWith('.rsc')) return Icons.code_rounded;
    if (name.endsWith('.npk')) return Icons.system_update_rounded;
    if (name.endsWith('.txt')) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  bool _isDirectory(Map<String, String> file) {
    final type = (file['type'] ?? '').toLowerCase();
    return type.contains('directory') || type.contains('folder');
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    final c = AppC(dark);
    final used = _totalSpace - _freeSpace;
    final pct = _totalSpace > 0 ? (used / _totalSpace * 100).round() : 0;
    final color = pct > 85
        ? AppColors.red
        : pct > 65
        ? AppColors.orange
        : AppColors.green;

    return Column(
      children: [
        // Storage info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A3E), Color(0xFF2A1A4E)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.storage_rounded,
                      color: AppColors.purple,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MikroTik Storage',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${_fmtSize(used.toString())} '
                            '/ ${_fmtSize(_totalSpace.toString())}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _storageChip(
                      'Terpakai',
                      _fmtSize(used.toString()),
                      AppColors.orange,
                    ),
                    _storageChip(
                      'Tersisa',
                      _fmtSize(_freeSpace.toString()),
                      AppColors.green,
                    ),
                    _storageChip(
                      'Total',
                      _fmtSize(_totalSpace.toString()),
                      AppColors.cyan,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // File list header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'File (${_files.length})',
                style: TextStyle(
                  color: c.txt,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _actionButton(
                label: 'Folder',
                icon: Icons.create_new_folder_rounded,
                color: AppColors.orange,
                onTap: _busy ? null : _createFolder,
              ),
              const SizedBox(width: 8),
              _actionButton(
                label: 'Upload',
                icon: Icons.upload_file_rounded,
                color: AppColors.green,
                onTap: _busy ? null : _uploadFile,
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _fetchFiles();
                  _fetchStorage();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cyan,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.cyan,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Files
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.cyan),
                )
              : _files.isEmpty
              ? Center(
                  child: Text('Tidak ada file', style: TextStyle(color: c.sub)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _files.length,
                  itemBuilder: (_, i) {
                    final f = _files[i];
                    final name = f['name'] ?? '-';
                    final size = f['size'] ?? '0';
                    final type = f['type'] ?? '-';
                    final isDirectory = _isDirectory(f);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.purple.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDirectory
                                ? Icons.folder_rounded
                                : _fileIcon(name),
                            color: AppColors.purple,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: c.txt,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$type  •  ${_fmtSize(size)}',
                                  style: TextStyle(color: c.sub, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (!isDirectory)
                            GestureDetector(
                              onTap: _busy ? null : () => _downloadFile(name),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.cyan.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.download_rounded,
                                  color: AppColors.cyan,
                                  size: 16,
                                ),
                              ),
                            ),
                          GestureDetector(
                            onTap: _busy ? null : () => _deleteFile(name),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.delete_rounded,
                                color: AppColors.red,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _storageChip(String label, String value, Color color) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ],
  );

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onTap == null ? 0.05 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}
