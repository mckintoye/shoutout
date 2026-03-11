import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../data/repositories/upload_repository.dart';
import '../../router/app_router.dart';
import '../../theme/tokens.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.eventId});
  final String eventId;


  @override
  State<RecordScreen> createState() => _RecordScreenState();
}


class _RecordScreenState extends State<RecordScreen> {
  bool _busy = false;
  bool _autoOpened = false;
  String? _error;


  final _auth = FirebaseAuth.instance;
  final _repo = UploadRepository();
  static const int _maxSeconds = 60;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Auto-open camera once after screen is laid out
    if (_autoOpened) return;
    _autoOpened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openCamera();
    });
  }

  Future<void> _uploadPicked(XFile picked, {required String source}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'You must be signed in.');
      return;
    }

    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final f = File(picked.path);

      // Compute duration (needed for 60s enforcement + repo validation).
      final vc = VideoPlayerController.file(f);
      await vc.initialize();
      final dur = vc.value.duration;
      await vc.dispose();

      final seconds = dur.inSeconds;
      if (seconds <= 0) {
        throw Exception('Could not read video duration.');
      }
      if (seconds > _maxSeconds) {
        throw Exception('Video must be $_maxSeconds seconds or less.');
      }

      await _repo.createUpload(
        eventId: widget.eventId,
        userId: uid,
        file: f,
        durationSec: seconds,
        source: source, // "camera" | "library"
      );

      if (!mounted) return;

      // Close the loop: land in Gallery filtered to the event.
      context.go('${AppRoutes.uploadsPath}?eventId=${widget.eventId}');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('only submit up to') || msg.contains('5')) {
        setState(() => _error = 'Upload limit reached (5/5) for this event.');
      } else if (msg.contains('seconds')) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      } else {
        setState(() => _error = 'Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCamera() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: _maxSeconds),
      );

      // If user cancelled, stop busy and stay here.
      if (!mounted) return;
      setState(() => _busy = false);
      if (file == null) return;

      await _uploadPicked(file, source: 'camera');
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        final code = e.code.toLowerCase();
        if (code.contains('camera_access_denied') || code.contains('photo_access_denied')) {
          _error = 'Permission denied. Enable Camera/Photos access in Settings.';
        } else if (code.contains('microphone_access_denied')) {
          _error = 'Microphone permission denied. Enable Microphone access in Settings.';
        } else {
          _error = 'Could not open camera. Please try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not open camera. Please try again.';
      });
    }
  }

  Future<void> _pickFromLibrary() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(source: ImageSource.gallery);

      if (!mounted) return;
      setState(() => _busy = false);
      if (file == null) return;

      await _uploadPicked(file, source: 'library');
    } on PlatformException catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Permission denied. Enable Photos access in Settings.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not open library. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text('Record', style: AppTokens.h2.copyWith(color: AppTokens.ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTokens.stroke),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(
                      'Opening camera…',
                      style: AppTokens.body.copyWith(color: AppTokens.subInk),
                    ),
                  ] else ...[
                    Text(
                      'Record or upload a message',
                      style: AppTokens.h2.copyWith(color: AppTokens.ink),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Camera opens automatically. You can also choose a video from your library.',
                      style: AppTokens.small.copyWith(color: AppTokens.subInk),
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openCamera,
                        icon: const Icon(Icons.videocam),
                        label: const Text('Open Camera'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickFromLibrary,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Choose from Library'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}