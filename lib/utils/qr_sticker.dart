import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Print-ready QR sticker: QR code + "Scan to view the full Service Record"
/// caption + ticket ID, drawn at an exact physical size (mm) and 600 DPI so it
/// prints sharp and at the right size on sticker paper.
class QrSticker {
  final Uint8List png;
  final double widthMm;
  final double heightMm;

  const QrSticker({
    required this.png,
    required this.widthMm,
    required this.heightMm,
  });
}

/// Sticker widths offered in the QR dialog (height follows the layout).
const List<(String, double)> kQrStickerSizes = [
  ('Small', 40),
  ('Standard', 50),
  ('Large', 70),
];

const String kQrStickerCaption = 'Scan to view the full Service Record';

Future<QrSticker> renderQrSticker({
  required String data,
  required String trackingId,
  double widthMm = 50,
  int dpi = 600,
}) async {
  final pxPerMm = dpi / 25.4;
  final w = widthMm * pxPerMm;

  // Layout, all relative to the sticker width. The margin doubles as the QR
  // "quiet zone" (blank border around the code) so phones scan it reliably.
  final margin = 0.11 * w;
  final qrSize = w - 2 * margin;
  final gap = 0.03 * w;
  final contentWidth = w - 2 * margin;

  final caption = TextPainter(
    text: TextSpan(
      text: kQrStickerCaption,
      style: TextStyle(
        color: Colors.black,
        fontSize: 0.058 * w,
        fontWeight: FontWeight.w500,
        height: 1.15,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(minWidth: contentWidth, maxWidth: contentWidth);

  final idText = TextPainter(
    text: TextSpan(
      text: trackingId,
      style: TextStyle(
        color: const Color(0xFF333333),
        fontSize: 0.05 * w,
        letterSpacing: 0.006 * w,
        fontWeight: FontWeight.w600,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(minWidth: contentWidth, maxWidth: contentWidth);

  final h = margin * 0.9 +
      qrSize +
      gap +
      caption.height +
      gap * 0.5 +
      idText.height +
      margin * 0.7;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // White background
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

  // Thin rounded border (cutting guide)
  final stroke = 0.005 * w;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, h - stroke),
      Radius.circular(0.04 * w),
    ),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFF222222),
  );

  // QR code (error correction M so a scratched sticker still scans)
  final top = margin * 0.9;
  canvas.save();
  canvas.translate(margin, top);
  QrPainter(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Colors.black,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Colors.black,
    ),
  ).paint(canvas, Size(qrSize, qrSize));
  canvas.restore();

  // Caption + ticket ID
  var y = top + qrSize + gap;
  caption.paint(canvas, Offset(margin, y));
  y += caption.height + gap * 0.5;
  idText.paint(canvas, Offset(margin, y));

  final image = await recorder.endRecording().toImage(w.round(), h.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw Exception('Unable to create the sticker image.');
  }

  return QrSticker(
    png: bytes.buffer.asUint8List(),
    widthMm: widthMm,
    heightMm: h / pxPerMm,
  );
}
