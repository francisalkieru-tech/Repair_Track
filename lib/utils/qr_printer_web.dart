import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Opens the browser print dialog with the sticker at its exact physical size
/// (the page is set to the sticker's mm size, no margins).
/// In the print dialog use: Margins = None, Scale = 100%.
void printStickerPng(Uint8List bytes, double widthMm, double heightMm) {
  final w = widthMm.toStringAsFixed(2);
  final h = heightMm.toStringAsFixed(2);
  final src = 'data:image/png;base64,${base64Encode(bytes)}';

  final page = '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  @page { size: ${w}mm ${h}mm; margin: 0; }
  html, body { margin: 0; padding: 0; background: #fff; }
  img { width: ${w}mm; height: ${h}mm; display: block; }
</style>
</head>
<body>
<img src="$src" onload="setTimeout(function(){ window.focus(); window.print(); }, 150);">
</body>
</html>
''';

  final frame = html.IFrameElement()
    ..style.position = 'fixed'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = '0'
    ..srcdoc = page;

  html.document.body!.append(frame);

  // Clean up after the print dialog has had time to open and close.
  Future.delayed(const Duration(minutes: 2), frame.remove);
}
