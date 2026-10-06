import 'dart:typed_data';

/// Non-web platforms: the dialog shares the PNG instead (print from the
/// share sheet / printer app), so there is nothing to do here.
void printStickerPng(Uint8List bytes, double widthMm, double heightMm) {}
