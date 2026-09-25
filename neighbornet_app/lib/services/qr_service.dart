import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import '../models/neighbornet_models.dart';

class QrService {
  /// Decodes a QR code payload from raw image bytes (PNG, JPEG, BMP, etc.).
  /// Works 100% offline with zero native OS dependencies.
  static String? decodeQrFromImageBytes(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final width = image.width;
      final height = image.height;
      final Int32List int32List = Int32List(width * height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y);
          final a = pixel.a.toInt();
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          int32List[y * width + x] = (a << 24) | (r << 16) | (g << 8) | b;
        }
      }

      final source = RGBLuminanceSource(width, height, int32List);
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final reader = QRCodeReader();
      final result = reader.decode(bitmap);
      return result.text;
    } catch (_) {
      // Fallback with GlobalHistogramBinarizer for challenging lighting/contrast
      try {
        final image = img.decodeImage(bytes);
        if (image == null) return null;

        final width = image.width;
        final height = image.height;
        final Int32List int32List = Int32List(width * height);

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final pixel = image.getPixel(x, y);
            final a = pixel.a.toInt();
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();
            int32List[y * width + x] = (a << 24) | (r << 16) | (g << 8) | b;
          }
        }

        final source = RGBLuminanceSource(width, height, int32List);
        final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
        final reader = QRCodeReader();
        final result = reader.decode(bitmap);
        return result.text;
      } catch (_) {
        return null;
      }
    }
  }

  /// Parses a raw scanned string (URI or JSON) into a UserProfile if valid.
  static UserProfile? parseScannedContact(String rawText) {
    return UserProfile.fromContactUri(rawText);
  }
}
