import 'package:flutter/material.dart';

class RouterChoiceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final List<String> options;
  final bool obscureText;
  final bool multiSelect;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;
  final bool allowCustom;
  final bool loading;

  const RouterChoiceField({
    super.key,
    required this.controller,
    required this.label,
    required this.options,
    this.hint,
    this.obscureText = false,
    this.multiSelect = false,
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.allowCustom = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentValues = controller.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    final unique = {
      ...currentValues,
      ...options.where((value) => value.trim().isNotEmpty),
    }.toList();
    return TextField(
      controller: controller,
      readOnly: !allowCustom,
      obscureText: obscureText,
      onChanged: onChanged,
      onTap: !allowCustom && !loading && unique.isNotEmpty
          ? () => multiSelect
                ? _showMultiOptions(context, unique)
                : _showOptions(context, unique)
          : null,
      minLines: obscureText ? 1 : minLines,
      maxLines: obscureText ? 1 : maxLines,
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        hintText: loading ? 'Memuat pilihan dari router...' : hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: unique.isEmpty
                    ? 'Tidak ada pilihan tersedia'
                    : 'Pilih nilai',
                onPressed: unique.isEmpty
                    ? null
                    : () => multiSelect
                          ? _showMultiOptions(context, unique)
                          : _showOptions(context, unique),
                icon: const Icon(Icons.arrow_drop_down_rounded),
              ),
      ),
    );
  }

  Future<void> _showOptions(BuildContext context, List<String> options) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 10, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${options.length} pilihan',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  itemCount: options.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: const Icon(Icons.clear_rounded, size: 16),
                        title: const Text(
                          'Kosongkan',
                          style: TextStyle(fontSize: 11),
                        ),
                        onTap: () => Navigator.pop(sheetContext, ''),
                      );
                    }
                    final value = options[index - 1];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(value, style: const TextStyle(fontSize: 11)),
                      trailing: controller.text == value
                          ? const Icon(Icons.check_rounded, size: 16)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    controller
      ..text = selected
      ..selection = TextSelection.collapsed(offset: selected.length);
    onChanged?.call(selected);
  }

  Future<void> _showMultiOptions(
    BuildContext context,
    List<String> options,
  ) async {
    final selected = controller.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.58,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 10, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(selected.clear),
                        child: const Text('Reset'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, selected.join(',')),
                        child: const Text('Selesai'),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount: options.length,
                    itemBuilder: (_, index) {
                      final value = options[index];
                      return CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        value: selected.contains(value),
                        title: Text(
                          value,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onChanged: (checked) => setSheetState(() {
                          if (checked == true) {
                            selected.add(value);
                          } else {
                            selected.remove(value);
                          }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    controller
      ..text = result
      ..selection = TextSelection.collapsed(offset: result.length);
    onChanged?.call(result);
  }
}
