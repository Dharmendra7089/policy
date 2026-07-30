import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<({Uint8List bytes, String name})?> pickPdfBytes() {
  final staleInputs = web.document.querySelectorAll('[data-policy-pdf-picker]');
  for (var index = 0; index < staleInputs.length; index++) {
    final staleInput = staleInputs.item(index);
    if (staleInput != null) {
      staleInput.parentNode?.removeChild(staleInput);
    }
  }

  final completer = Completer<({Uint8List bytes, String name})?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.pdf,application/pdf'
    ..multiple = false
    ..setAttribute('data-policy-pdf-picker', 'true')
    ..style.position = 'fixed'
    ..style.left = '-10000px';

  web.document.body?.append(input);

  input.onChange.first.then((_) async {
    try {
      final files = input.files;
      final file = files == null || files.length == 0 ? null : files.item(0);
      if (file == null) {
        completer.complete(null);
        return;
      }
      final buffer = await file.arrayBuffer().toDart;
      final bytes = Uint8List.view(buffer.toDart);
      completer.complete((bytes: bytes, name: file.name));
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      input.remove();
    }
  });

  input.click();
  return completer.future;
}
