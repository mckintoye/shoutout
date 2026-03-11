import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/event_repository.dart';
import '../../router/app_router.dart';
import '../../theme/tokens.dart';
import '../../utils/cover_image.dart';
import '../../utils/cover_backfill.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    const Color lavender = Color(0xFFFAF8FF);
    final eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: eventRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snap.error}')));
        }

        final doc = snap.data;
        if (doc == null || !doc.exists) {
          return const Scaffold(body: Center(child: Text('Event not found.')));
        }

        final data = doc.data() ?? {};

        final title = (data['title'] ?? data['name'] ?? 'Event').toString();
        final shareCode = (data['shareCode'] ?? '').toString();
        final status = (data['status'] ?? 'open').toString();
        final privacy = (data['privacy'] ?? 'signed_in_only').toString();
        final type = (data['type'] ?? '').toString();

        final coverUrl = (data['coverUrl'] ?? '').toString();
        final coverPath = (data['coverPath'] ?? '').toString();
        final coverAlignY = _parseAlignY(data['coverAlignY']);

        final isCreator = uid != null && (data['createdByUid'] ?? '') == uid;

        final isDeleted = status.toLowerCase().trim() == 'deleted';
        if (isDeleted) {
          return Scaffold(
            backgroundColor: lavender,
            appBar: AppBar(
              backgroundColor: lavender,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.goNamed(AppRoutes.events),
              ),
              centerTitle: true,
              title: const Text('Event deleted'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.s16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('This event has been deleted.',
                        style: AppTokens.title, textAlign: TextAlign.center),
                    const SizedBox(height: AppTokens.s12),
                    Text('Back to Events to continue.',
                        style: AppTokens.sub, textAlign: TextAlign.center),
                    const SizedBox(height: AppTokens.s16),
                    FilledButton(
                      onPressed: () => context.goNamed(AppRoutes.events),
                      child: const Text('Back to Events'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final screenH = MediaQuery.of(context).size.height;
        final heroH = math.min(screenH * 0.45, 420.0); // ✅ cap height
        CoverBackfill.ensureCoverUrl(
          eventId: eventId,
          coverUrl: coverUrl,
          coverPath: coverPath,
        );

        return Scaffold(
          backgroundColor: lavender,
          appBar: AppBar(
            backgroundColor: lavender,
            elevation: 0,
            centerTitle: true,
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _RolePill(label: isCreator ? 'Creator' : 'Member'),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Portrait-ish hero but safely bounded

                  SizedBox(
                    height: heroH,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: coverUrl.isEmpty
                                ? Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image,
                                size: 44,
                                color: Colors.black26,
                              ),
                            )
                                : Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment(0, coverAlignY),
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 44,
                                  color: Colors.black26,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Only creator can adjust cover focal point
                        if (isCreator && coverUrl.isNotEmpty)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _PillIconButton(
                              icon: Icons.tune,
                              label: 'Adjust',
                              onTap: () => _showCoverAdjustSheet(
                                context: context,
                                eventRef: eventRef,
                                coverUrl: coverUrl,
                                initialAlignY: coverAlignY,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),


                  const SizedBox(height: AppTokens.s16),

                  Text(title, style: AppTokens.h1.copyWith(color: AppTokens.ink)),
                  const SizedBox(height: AppTokens.s10),

                  _ShareCodeRow(
                    code: shareCode,
                    onCopy: () async {
                      await Clipboard.setData(ClipboardData(text: shareCode));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied share code')),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: AppTokens.s10),
                  Text(
                    'Portrait • 60 seconds max',
                    style: AppTokens.small.copyWith(color: AppTokens.subInk),
                  ),
                  const SizedBox(height: AppTokens.s10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(text: type.isEmpty ? 'Event' : type),
                      _Chip(text: _formatDate(context, data['eventDate'])),
                      _Chip(text: privacy == 'public' ? 'Public' : 'Private'),
                      _Chip(text: status == 'open' ? 'Open' : status),
                    ],
                  ),

                  const SizedBox(height: AppTokens.s20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => context.goNamed(
                        AppRoutes.gallery,
                        queryParameters: {'eventId': eventId},
                      ),
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('View videos'),
                    ),
                  ),
                  const SizedBox(height: AppTokens.s12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => context.goNamed(
                        AppRoutes.record,
                        pathParameters: {'eventId': eventId},
                      ),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Record or upload video'),
                    ),
                  ),

                  if (isCreator) ...[
                    const SizedBox(height: AppTokens.s14),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Delete event?'),
                              content: const Text('This removes the event for everyone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (ok == true) {
                            try {
                              await EventRepository().deleteEventAsHost(eventId);
                              if (!context.mounted) return;

                              // ✅ IMPORTANT: AppRoutes.events is a NAME, not a path
                              context.goNamed(AppRoutes.events);
                              // (Alternative is also valid): context.go(AppRoutes.eventsPath);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Delete failed: $e')),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Delete event',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ),
                    ),
                  ],

                  // extra bottom padding so content clears bottom nav
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(BuildContext context, dynamic v) {
    if (v is Timestamp) {
      return MaterialLocalizations.of(context).formatMediumDate(v.toDate());
    }
    return 'Date';
  }
}

double _parseAlignY(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble().clamp(-1.0, 1.0);
  final parsed = double.tryParse(v.toString());
  return (parsed ?? 0.0).clamp(-1.0, 1.0);
}

Future<void> _showCoverAdjustSheet({
  required BuildContext context,
  required DocumentReference<Map<String, dynamic>> eventRef,
  required String coverUrl,
  required double initialAlignY,
}) async {
  double temp = initialAlignY;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Adjust cover', style: AppTokens.title),
                const SizedBox(height: 12),

                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    child: Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment(0, temp),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Text('Drag to reposition', style: AppTokens.caption),

                Slider(
                  value: temp,
                  min: -1,
                  max: 1,
                  onChanged: (v) => setSheetState(() => temp = v),
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await eventRef.update({'coverAlignY': temp});
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(label, style: AppTokens.sub),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTokens.stroke),
      ),
      child: Text(label, style: AppTokens.small.copyWith(color: AppTokens.ink)),
    );
  }
}

class _ShareCodeRow extends StatelessWidget {
  const _ShareCodeRow({required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(AppTokens.r16),
        border: Border.all(color: AppTokens.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.body.copyWith(
                color: AppTokens.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.copy), onPressed: onCopy),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTokens.stroke),
      ),
      child: Text(text, style: AppTokens.small.copyWith(color: AppTokens.subInk)),
    );
  }
}