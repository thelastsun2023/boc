import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class MaterialNotes extends StatefulWidget {
  const MaterialNotes({super.key, required this.value, this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;
  @override
  State<MaterialNotes> createState() => _MaterialNotesState();
}

class _MaterialNotesState extends State<MaterialNotes> {
  late final quill.QuillController controller;
  @override
  void initState() {
    super.initState();
    quill.Document document;
    try {
      document = quill.Document.fromJson(jsonDecode(widget.value) as List);
    } catch (_) {
      document = quill.Document();
    }
    controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: widget.onChanged == null,
    );
    controller.addListener(_changed);
  }

  void _changed() => widget.onChanged?.call(
    jsonEncode(controller.document.toDelta().toJson()),
  );
  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.onChanged != null)
        quill.QuillSimpleToolbar(
          controller: controller,
          config: const quill.QuillSimpleToolbarConfig(
            showFontFamily: false,
            showFontSize: false,
            showLink: false,
            showSearchButton: false,
            showInlineCode: false,
            showCodeBlock: false,
          ),
        ),
      Container(
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: quill.QuillEditor.basic(
          controller: controller,
          config: const quill.QuillEditorConfig(
            padding: EdgeInsets.all(12),
            placeholder: '填写备注 / Notes',
          ),
        ),
      ),
    ],
  );
}

Future<void> showMaterialNotes(
  BuildContext context,
  String title,
  String value,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('备注 / Notes · $title'),
    content: SizedBox(width: 600, child: MaterialNotes(value: value)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭 / Close'),
      ),
    ],
  ),
);

bool hasMaterialNotes(String? value) {
  try {
    return (jsonDecode(value ?? '[]') as List).any(
      (op) =>
          op is Map &&
          op['insert'] is String &&
          (op['insert'] as String).trim().isNotEmpty,
    );
  } catch (_) {
    return false;
  }
}
