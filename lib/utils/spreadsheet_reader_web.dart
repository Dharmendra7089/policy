import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('policyReadSpreadsheetJson')
external JSString _policyReadSpreadsheetJson(
  JSUint8Array bytes,
  JSString extension,
);

List<List<dynamic>> readSpreadsheetRows(Uint8List bytes, String extension) {
  final json = _policyReadSpreadsheetJson(bytes.toJS, extension.toJS).toDart;
  final decoded = jsonDecode(json);
  if (decoded is! List) return const [];
  return decoded
      .whereType<List>()
      .map((row) => List<dynamic>.from(row))
      .toList();
}
