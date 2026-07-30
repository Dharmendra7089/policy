import 'dart:io';

import '../lib/utils/spreadsheet_reader_native.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/diagnose_excel_read.dart <file> <extension>',
    );
    exitCode = 64;
    return;
  }
  final bytes = File(arguments.first).readAsBytesSync();
  final extension = arguments.length > 1
      ? arguments[1]
      : arguments.first.split('.').last;
  final rows = readSpreadsheetRows(bytes, extension);
  stdout.writeln('Rows: ${rows.length}');
  for (final row in rows.take(3)) {
    stdout.writeln(row);
  }
}
