import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// Picks a document (photo or PDF) for case upload and returns a locally-
/// compressed file. Compression is delegated to `image_picker` which uses the
/// platform's native encoder — noticeably cheaper on low-end devices than
/// re-encoding in Dart.
///
/// Motivation: a 4 MB bulletin scan costs a student roughly 200 FCFA on an
/// Orange prepaid plan. Shrinking to ~400 KB at 1600px/quality 70 keeps
/// documents readable for KPB advisors while cutting the airtime cost ~10x.
class DocumentUploadService {
  DocumentUploadService._();

  static const int _maxImageWidth = 1600;
  static const int _imageQuality = 70;

  /// Opens the system camera, compresses the capture, and returns the file.
  /// Returns `null` if the user cancels.
  static Future<File?> captureFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxImageWidth.toDouble(),
      imageQuality: _imageQuality,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Opens the gallery and returns a compressed copy of the picked image.
  static Future<File?> pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxImageWidth.toDouble(),
      imageQuality: _imageQuality,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Maximum allowed file size: 10 MB.
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;

  /// Opens the system file picker for PDFs (no recompression — PDFs already
  /// compress poorly and users expect the exact document).
  /// Throws [FileTooLargeException] if the file exceeds [_maxFileSizeBytes].
  static Future<File?> pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    final file = File(path);
    final sizeInBytes = await file.length();
    if (sizeInBytes > _maxFileSizeBytes) {
      throw FileTooLargeException(
        sizeInBytes: sizeInBytes,
        maxSizeInBytes: _maxFileSizeBytes,
      );
    }
    return file;
  }
}

/// Thrown when a picked file exceeds the maximum allowed size.
class FileTooLargeException implements Exception {
  const FileTooLargeException({
    required this.sizeInBytes,
    required this.maxSizeInBytes,
  });

  final int sizeInBytes;
  final int maxSizeInBytes;

  double get sizeMb => sizeInBytes / (1024 * 1024);
  double get maxSizeMb => maxSizeInBytes / (1024 * 1024);

  @override
  String toString() =>
      'File is too large (${sizeMb.toStringAsFixed(1)} MB). Maximum allowed: ${maxSizeMb.toStringAsFixed(0)} MB.';
}
