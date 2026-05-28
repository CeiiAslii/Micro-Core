import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/mikrotik_api.dart';
import '../../providers/app_provider.dart';

class StorageScreen extends StatefulWidget {
  final MikrotikApi api;
  const StorageScreen({super.key, required this.api});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  List<Map<String, String>> _files = [];
  bool _loading = true;
  String _path = '/';
  int _totalSpace = 0;
  int _freeSpace = 0;

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
      await widget.api.query(['/file/remove', '=numbers=$name']);
      _fetchFiles();
      _fetchStorage();
    }
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
              GestureDetector(
                onTap: () {
                  _fetchFiles();
                  _fetchStorage();
                },
                child: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.cyan,
                  size: 20,
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
                            _fileIcon(name),
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
                          GestureDetector(
                            onTap: () => _deleteFile(name),
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
}
