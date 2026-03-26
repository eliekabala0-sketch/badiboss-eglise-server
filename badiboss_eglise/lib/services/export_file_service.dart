import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
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
    String path = safeName;
    File? file;
    try {
      final dir = await getApplicationDocumentsDirectory();
      file = File('${dir.path}/$safeName');
      await file.writeAsString(content, flush: true);
      path = file.path;
    } catch (_) {
      // fallback share-only mode
    }
    var shared = false;
    if (openShareSheet) {
      final xfile = (file != null)
          ? XFile(file.path)
          : XFile.fromData(
              Uint8List.fromList(content.codeUnits),
              mimeType: 'text/csv',
              name: safeName,
            );
      await Share.shareXFiles(
        [xfile],
        text: 'Export Badiboss Eglise',
      );
      shared = true;
    }
    return ExportFileResult(path: path, shared: shared);
  }
}
