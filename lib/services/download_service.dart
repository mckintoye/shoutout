import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<Directory> _baseDir() async {
    // MVP-stable: app documents directory on both platforms
    // (User can export from share sheet)
    return getApplicationDocumentsDirectory();
  }

  String _sanitize(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'ShoutOut' : cleaned;
  }

  String buildFileName({
    required String eventTitle,
    required DateTime date,
    required int index,
  }) {
    final d = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final safeTitle = _sanitize(eventTitle);
    return 'ShoutOut_''${safeTitle}''_''$d''_''${index.toString().padLeft(2, '0')}.mp4';
  }

  /// Downloads multiple videos to app documents directory.
  /// Returns list of saved file paths.
  Future<List<String>> downloadMany({
    required List<Uri> urls,
    required List<String> fileNames,
    void Function(int done, int total)? onProgress,
  }) async {
    if (urls.length != fileNames.length) {
      throw ArgumentError('urls and fileNames must have same length');
    }

    final dir = await _baseDir();
    final outDir = Directory('${dir.path}/shoutout_downloads');
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final savedPaths = <String>[];

    for (var i = 0; i < urls.length; i++) {
      final url = urls[i].toString();
      final name = fileNames[i];
      final path = '${outDir.path}/$name';

      await _dio.download(url, path, options: Options(receiveTimeout: const Duration(minutes: 3)));

      savedPaths.add(path);
      onProgress?.call(i + 1, urls.length);
    }

    return savedPaths;
  }

  /// Opens share sheet so user can save/export the downloaded files.
     Future<void> shareFiles(BuildContext context, List<String> paths) async {
         final files = paths.map((p) => XFile(p)).toList();

         final box = context.findRenderObject() as RenderBox?;
         final origin = box != null
             ? (box.localToGlobal(Offset.zero) & box.size)
             : const Rect.fromLTWH(0, 0, 1, 1);

         await Share.shareXFiles(
           files,
           text: 'ShoutOut downloads',
           sharePositionOrigin: origin,
         );
       }
}