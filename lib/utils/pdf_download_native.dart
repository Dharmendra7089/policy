import 'dart:typed_data';

import 'package:printing/printing.dart';

class PdfDownloadTarget {
  const PdfDownloadTarget();
}

PdfDownloadTarget preparePdfDownload({required String filename}) {
  return const PdfDownloadTarget();
}

Future<void> completePreparedPdfDownload({
  required PdfDownloadTarget target,
  required Uint8List bytes,
  required String filename,
}) {
  return downloadPdfFile(bytes: bytes, filename: filename);
}

Future<void> downloadPdfFile({
  required Uint8List bytes,
  required String filename,
}) {
  return Printing.sharePdf(bytes: bytes, filename: filename);
}
