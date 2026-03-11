import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/repositories/upload_repository.dart';
import '../../theme/tokens.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.eventId,
    required this.payload,
  });

  final String eventId;

  /// Expected payload (any of these):
  /// - {'file': File, 'source': 'camera'|'library'}
  /// - {'xfile': XFile, 'source': ...}
  /// - {'path': String, 'source': ...}
  final dynamic payload;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  static const int _maxSeconds = 60;

  final _repo = UploadRepository();
  final _auth = FirebaseAuth.instance;

  VideoPlayerController? _controller;
  Duration? _duration;

  File? _file;
  dynamic _xfile; // XFile if provided
  String _fileName = 'video.mp4';
  String _source = 'library';

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hydratePayload();
    _initVideo();
  }

  void _hydratePayload() {
    final p = widget.payload;

    if (p is Map) {
      _source = (p['source'] ?? 'library').toString();

      final f = p['file'];
      final xf = p['xfile'];
      final path = p['path'];

      if (f is File) {
        _file = f;
        _fileName = f.path.split('/').last;
      } else if (xf != null) {
        _xfile = xf;
        final name = xf.name;
        final xp = xf.path?.toString();
        _fileName = (name ?? (xp?.split('/').last ?? 'video.mp4')).toString();
        if (!kIsWeb && xp != null) _file = File(xp);
      } else if (path is String && path.isNotEmpty) {
        _file = File(path);
        _fileName = path.split('/').last;
      }
    }
  }

  Future<void> _initVideo() async {
    try {
      VideoPlayerController controller;

      if (kIsWeb) {
        // Only works if payload provides a playable URL (e.g., blob URL) in xfile.path.
        final url = (_xfile?.path ?? '').toString();
        if (url.isEmpty) {
          setState(() => _error = 'Preview not available on web for this upload.');
          return;
        }
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        final f = _file;
        if (f == null) {
          setState(() => _error = 'Missing video file.');
          return;
        }
        controller = VideoPlayerController.file(f);
      }

      _controller = controller;
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _duration = controller.value.duration;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load preview.');
    }
  }

  String _fmt(Duration? d) {
    if (d == null) return '—';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'You must be signed in.');
      return;
    }

    final dur = _duration;
    if (dur != null && dur.inSeconds > _maxSeconds) {
      setState(() => _error = 'Video too long. Max is $_maxSeconds seconds.');
      return;
    }

    if (kIsWeb) {
      setState(() => _error = 'Video uploading is not wired for web in this build (File is required).');
      return;
    }

    final f = _file;
    if (f == null) {
      setState(() => _error = 'Missing video file.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _repo.createUpload(
        eventId: widget.eventId,
        userId: uid,
        file: f,
        durationSec: dur?.inSeconds ?? 0,
        source: _source,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true); // or route to success if you have it
    } catch (e) {
      final msg = e.toString();
      if (msg.toLowerCase().contains('only submit up to') || msg.contains('5')) {
        setState(() => _error = 'Upload limit reached (5/5) for this event.');
      } else {
        setState(() => _error = 'Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFAF8FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text('Review', style: AppTokens.h2.copyWith(color: AppTokens.ink)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s16),
          child: Column(
            children: [
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTokens.s12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTokens.r16),
                    border: Border.all(color: AppTokens.stroke),
                  ),
                  child: Text(_error!, style: AppTokens.body.copyWith(color: Colors.red.shade700)),
                ),
                const SizedBox(height: AppTokens.s12),
              ],
              Container(
                padding: const EdgeInsets.all(AppTokens.s16),
                decoration: BoxDecoration(
                  color: AppTokens.card,
                  borderRadius: BorderRadius.circular(AppTokens.r24),
                  border: Border.all(color: AppTokens.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ready to share?', style: AppTokens.h2.copyWith(color: AppTokens.ink)),
                    const SizedBox(height: AppTokens.s6),
                    Text('$_maxSeconds seconds max. Portrait is best.',
                        style: AppTokens.body.copyWith(color: AppTokens.subInk)),
                    const SizedBox(height: AppTokens.s12),
                    Container(
                      height: 500,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTokens.bg,
                        borderRadius: BorderRadius.circular(AppTokens.r16),
                        border: Border.all(color: AppTokens.stroke),
                      ),
                      alignment: Alignment.center,
                      child: _controller != null && _controller!.value.isInitialized
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.r16),
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      )
                          : const CircularProgressIndicator(),
                    ),
                    const SizedBox(height: AppTokens.s12),
                    Text(_fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.body.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppTokens.s4),
                    Text('Duration: ${_fmt(_duration)}', style: AppTokens.small.copyWith(color: AppTokens.subInk)),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_submitting ? 'Uploading…' : 'Submit'),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}