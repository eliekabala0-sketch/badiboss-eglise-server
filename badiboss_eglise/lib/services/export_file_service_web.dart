import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

final class ExportFileResult {
  final String path;
  final bool shared;
  const ExportFileResult({required this.path, required this.shared});
}

final class ExportFileService {
  const ExportFileService._();

  static Future<ExportFileResult> saveTextFile({
    required String fileName,
    required String content,
    bool openShareSheet = true,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    var shared = false;
    if (openShareSheet) {
      final xfile = XFile.fromData(
        Uint8List.fromList(content.codeUnits),
        mimeType: 'text/plain',
        name: safeName,
      );
      await Share.shareXFiles(
        [xfile],
        text: 'Export Badiboss Eglise',
      );
      shared = true;
    }
    return ExportFileResult(path: safeName, shared: shared);
  }
}
