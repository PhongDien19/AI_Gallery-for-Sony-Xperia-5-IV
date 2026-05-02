import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';

class ExifService {
  /// Reads the actual creation date from EXIF tags
  Future<DateTime?> readExifTime(Uint8List bytes) async {
    try {
      final tags = await readExifFromBytes(bytes);

      if (tags.containsKey('EXIF DateTimeOriginal')) {
        final String value = tags['EXIF DateTimeOriginal']!.printable;
        // EXIF format is usually "YYYY:MM:DD HH:MM:SS"
        // We need "YYYY-MM-DD HH:MM:SS" for DateTime.tryParse
        return DateTime.tryParse(value.replaceAll(':', '-').replaceFirst('-', ':', 11).replaceFirst('-', ':', 14));
      }
    } catch (e) {
      debugPrint("Error reading EXIF: $e");
    }
    return null;
  }
}
