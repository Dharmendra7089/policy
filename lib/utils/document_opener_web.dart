import 'package:web/web.dart' as web;

Future<bool> openDocumentUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..target = '_blank'
    ..rel = 'noopener noreferrer'
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
