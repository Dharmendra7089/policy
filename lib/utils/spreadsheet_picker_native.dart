import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<({Uint8List bytes, String name})?> pickSpreadsheetBytes() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx', 'xls', 'xlsm', 'xlsb', 'ods', 'csv'],
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  return (bytes: bytes, name: file.name);
}
