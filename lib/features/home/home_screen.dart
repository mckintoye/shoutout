import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../theme/tokens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _joinByCode(BuildContext context, String code) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid event code.')),
      );
      return;
    }

    try {
      // Find event by shareCode
      final query = await FirebaseFirestore.instance
          .collection('events')
          .where('shareCode', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event not found.')),
        );
        return;
      }

      final eventDoc = query.docs.first;
      final eventId = eventDoc.id;
      final eventData = eventDoc.data();

      final createdByUid = (eventData['createdByUid'] ?? '').toString();
      final role = (createdByUid == uid) ? 'host' : 'member';

      final batch = FirebaseFirestore.instance.batch();

      // 1) Member doc under event (role & permissions)
      final memberRef = FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('members')
          .doc(uid);

      batch.set(
        memberRef,
        {
          'uid': uid,
          'role': role,
          'joinedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2) Snapshot under user (Joined Events cache)
      // IMPORTANT: initially hasUploaded = false (so it won't appear until they upload)
      final userEventRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc(eventId);

      batch.set(
        userEventRef,
        {
          'eventId': eventId,
          'eventTitle': eventData['title'] ?? 'Untitled',
          'eventCoverUrl': eventData['coverUrl'] ?? '',
          'eventCoverPath': eventData['coverPath'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'deletedAt': null,
          'role': role,
          'hasUploaded': false,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!context.mounted) return;

      // Take them to event details so they can leave a message
      context.go('/app/events/$eventId');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join failed: $e')),
      );
    }
  }

  Future<void> _openJoinSheet(BuildContext context) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _JoinByCodeSheet(),
    );

    if (code == null) return;
    if (!context.mounted) return;
    await _joinByCode(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Home', style: AppTokens.h2.copyWith(color: AppTokens.ink)),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTokens.accentSoft.withOpacity(0.40),
                      AppTokens.bg,
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 100),
                  Text(
                    'Start a ShoutOut!',
                    textAlign: TextAlign.center,
                    style: AppTokens.h1.copyWith(color: AppTokens.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create an event or join with a code.',
                    textAlign: TextAlign.center,
                    style: AppTokens.body.copyWith(color: AppTokens.subInk),
                  ),
                  const SizedBox(height: 50),
                  _ActionCard(
                    icon: '🎉',
                    title: 'Create a ShoutOut',
                    subtitle: 'Private by default • Share a code to invite',
                    tone: _CardTone.primary,
                    onTap: () => context.goNamed(AppRoutes.createEvent),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: '🔗',
                    title: 'Join an Event',
                    subtitle: 'Paste a share code to leave a message.',
                    tone: _CardTone.neutral,
                    onTap: () => _openJoinSheet(context),
                  ),
                  const SizedBox(height: 200),
                  Text(
                    'Tip: Your events live under the Events tab.',
                    textAlign: TextAlign.center,
                    style: AppTokens.small.copyWith(
                      color: AppTokens.subInk.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinByCodeSheet extends StatefulWidget {
  const _JoinByCodeSheet();

  @override
  State<_JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends State<_JoinByCodeSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: _FloatingSheet(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Join an Event',
                style: AppTokens.h2.copyWith(color: AppTokens.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Paste the share code you received.',
                style: AppTokens.small.copyWith(color: AppTokens.subInk),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'shoutout/...sharecode...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTokens.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTokens.stroke),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Join'),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- UI helpers (kept local to avoid breaking other darts) ---

enum _CardTone { primary, neutral }

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final _CardTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _CardTone.primary ? AppTokens.accentSoft : Colors.white;
    final border = tone == _CardTone.primary ? Colors.transparent : AppTokens.stroke;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTokens.stroke),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTokens.h2.copyWith(color: AppTokens.ink)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTokens.small.copyWith(color: AppTokens.subInk)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

class _FloatingSheet extends StatelessWidget {
  const _FloatingSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppTokens.bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTokens.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}