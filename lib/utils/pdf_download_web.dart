import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PdfDownloadTarget {
  final web.Window? window;

  const PdfDownloadTarget(this.window);
}

PdfDownloadTarget preparePdfDownload({required String filename}) {
  final popup = web.window.open('about:blank', '_blank');
  popup?.document.write(
    '''
<!doctype html>
<html>
  <head><title>Preparing PDF</title></head>
  <body style="font-family:Arial,sans-serif;padding:24px;color:#0d1b2a">
    <h3>Preparing PDF...</h3>
    <p>Please keep this tab open. Your download will start automatically.</p>
  </body>
</html>
'''
        .toJS,
  );
  return PdfDownloadTarget(popup);
}

Future<void> completePreparedPdfDownload({
  required PdfDownloadTarget target,
  required Uint8List bytes,
  required String filename,
}) async {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final popup = target.window;

  if (popup == null) {
    _clickDownload(url: url, filename: filename, document: web.document);
    return;
  }

  popup.document.write(
    '''
<!doctype html>
<html>
  <head><title>Download Ready</title></head>
  <body style="font-family:Arial,sans-serif;padding:24px;color:#0d1b2a">
    <h3>Download ready</h3>
    <p>If the download does not start, use the link below.</p>
  </body>
</html>
'''
        .toJS,
  );
  _clickDownload(url: url, filename: filename, document: popup.document);
  Future<void>.delayed(const Duration(seconds: 30), () {
    web.URL.revokeObjectURL(url);
  });
}

Future<void> downloadPdfFile({
  required Uint8List bytes,
  required String filename,
}) async {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  _clickDownload(url: url, filename: filename, document: web.document);
  Future<void>.delayed(const Duration(seconds: 30), () {
    web.URL.revokeObjectURL(url);
  });
}

void _clickDownload({
  required String url,
  required String filename,
  required web.Document document,
}) {
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..textContent = 'Download $filename'
    ..style.display = 'inline-block'
    ..style.marginTop = '12px'
    ..style.padding = '10px 14px'
    ..style.background = '#0D2D4F'
    ..style.color = '#ffffff'
    ..style.borderRadius = '8px'
    ..style.textDecoration = 'none';
  document.body?.append(anchor);
  anchor.click();
}
