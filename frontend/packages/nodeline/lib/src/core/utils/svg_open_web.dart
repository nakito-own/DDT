import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> openSvgExport(String svg) async {
  final bytes = Uint8List.fromList(utf8.encode(svg));
  final blob = web.Blob(
    <JSAny>[bytes.buffer.toJS].toJS,
    web.BlobPropertyBag(type: 'image/svg+xml'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = 'nodeline_export.svg';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return 'SVG downloaded';
}
