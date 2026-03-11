import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.coverUrl,
    required this.coverPath,
    this.fit = BoxFit.cover,
  });

  final String coverUrl;
  final String coverPath;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl.trim();
    final path = coverPath.trim();

    if (url.isNotEmpty) {
      return _NetImage(url: url, fit: fit);
    }

    if (path.isNotEmpty) {
      return FutureBuilder<String>(
        future: FirebaseStorage.instance.ref(path).getDownloadURL(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _placeholder();
          }
          if (snap.hasError) {
            debugPrint('❌ getDownloadURL failed');
            debugPrint('path=$path');
            debugPrint('error=${snap.error}');
            return _error();
          }
          final dl = (snap.data ?? '').trim();
          if (dl.isEmpty) return _error();
          return _NetImage(url: dl, fit: fit);
        },
      );
    }

    return _placeholder();
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFEFF4FF),
    alignment: Alignment.center,
    child: const Icon(Icons.celebration, size: 22, color: Color(0xFF2D6BFF)),
  );

  Widget _error() => Container(
    color: const Color(0xFFF7F7F7),
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined, size: 22, color: Colors.redAccent),
  );
}

class _NetImage extends StatelessWidget {
  const _NetImage({required this.url, required this.fit});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, err, st) {
        debugPrint('❌ Image.network failed');
        debugPrint('url=$url');
        debugPrint('error=$err');
        if (st != null) debugPrint('$st');
        return Container(
          color: const Color(0xFFF7F7F7),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, size: 22, color: Colors.redAccent),
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFEFF4FF),
          alignment: Alignment.center,
          child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}