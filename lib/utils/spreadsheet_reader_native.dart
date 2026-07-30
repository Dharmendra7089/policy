import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel2003/excel2003.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:xml/xml.dart';

List<List<dynamic>> readSpreadsheetRows(Uint8List bytes, String extension) {
  final normalized = extension.toLowerCase();
  if (normalized == 'csv') {
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceFirst('\ufeff', '');
    return csv.decode(text);
  }
  if (normalized == 'xls') {
    final reader = XlsReader.fromBytes(bytes);
    if (reader.sheetCount == 0) return const [];
    return reader.sheet(0).rows;
  }
  if ({'xlsx', 'xlsm'}.contains(normalized)) {
    return _readOpenXmlRows(bytes);
  }
  if (normalized == 'ods') {
    final decoder = SpreadsheetDecoder.decodeBytes(bytes);
    for (final table in decoder.tables.values) {
      if (table.rows.any(
        (row) =>
            row.any((value) => value?.toString().trim().isNotEmpty == true),
      )) {
        return table.rows;
      }
    }
    return const [];
  }
  throw FormatException(
    '.$extension files are supported in the web app. Use XLSX, XLS, XLSM, ODS, or CSV on this device.',
  );
}

List<List<dynamic>> _readOpenXmlRows(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final files = {
    for (final file in archive.files)
      if (file.isFile) file.name.replaceAll('\\', '/'): file,
  };

  final sharedStrings = <String>[];
  final sharedFile = files['xl/sharedStrings.xml'];
  if (sharedFile != null) {
    final document = XmlDocument.parse(
      utf8.decode(List<int>.from(sharedFile.content as List)),
    );
    for (final item in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'si',
    )) {
      final text = item.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 't')
          .map((element) => element.innerText)
          .join();
      sharedStrings.add(text);
    }
  }

  final worksheetFiles =
      files.entries
          .where(
            (entry) =>
                entry.key.startsWith('xl/worksheets/sheet') &&
                entry.key.endsWith('.xml'),
          )
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));

  for (final entry in worksheetFiles) {
    final document = XmlDocument.parse(
      utf8.decode(List<int>.from(entry.value.content as List)),
    );
    final rows = <List<dynamic>>[];
    for (final rowElement in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'row',
    )) {
      final values = <int, dynamic>{};
      var sequentialColumn = 0;
      for (final cell in rowElement.children.whereType<XmlElement>().where(
        (element) => element.name.local == 'c',
      )) {
        final reference = cell.getAttribute('r') ?? '';
        final column = reference.isEmpty
            ? sequentialColumn
            : _columnIndex(reference);
        sequentialColumn = column + 1;
        final type = cell.getAttribute('t') ?? '';
        final valueElement = cell.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'v')
            .firstOrNull;
        dynamic value;
        if (type == 'inlineStr') {
          value = cell.descendants
              .whereType<XmlElement>()
              .where((element) => element.name.local == 't')
              .map((element) => element.innerText)
              .join();
        } else {
          final raw = valueElement?.innerText ?? '';
          if (type == 's') {
            final index = int.tryParse(raw);
            value = index != null && index >= 0 && index < sharedStrings.length
                ? sharedStrings[index]
                : raw;
          } else if (type == 'b') {
            value = raw == '1';
          } else {
            value = raw;
          }
        }
        values[column] = value;
      }
      if (values.isEmpty) continue;
      final lastColumn = values.keys.reduce((a, b) => a > b ? a : b);
      rows.add([
        for (var column = 0; column <= lastColumn; column++)
          values[column] ?? '',
      ]);
    }
    if (rows.any(
      (row) => row.any((value) => value?.toString().trim().isNotEmpty == true),
    )) {
      return rows;
    }
  }
  return const [];
}

int _columnIndex(String reference) {
  var result = 0;
  for (final unit in reference.codeUnits) {
    if (unit >= 65 && unit <= 90) {
      result = result * 26 + unit - 64;
    } else if (unit >= 97 && unit <= 122) {
      result = result * 26 + unit - 96;
    } else {
      break;
    }
  }
  return result > 0 ? result - 1 : 0;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
