import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';

// Adjust these imports to your actual locations if needed:
import '../../theme/tokens.dart';
import '../../utils/cover_image.dart';

class EventsListScreen extends StatelessWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Create Event',
            onPressed: () => context.pushNamed(AppRoutes.createEvent),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Expanded(child: _MyEventsHalf(uid: uid)),
              const SizedBox(height: 12),
              Expanded(child: _JoinedEventsHalf(uid: uid)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Host events live in /events where createdByUid == uid
/// NOTE: We intentionally DO NOT orderBy here to avoid composite-index requirements.
/// We sort client-side by createdAt.
Query<Map<String, dynamic>> _myEventsQuery(String uid) {
  return FirebaseFirestore.instance
      .collection('events')
      .where('createdByUid', isEqualTo: uid);
}

/// Joined events are tracked in /users/{uid}/events/{eventId}
/// NOTE: This uses only ONE orderBy (no where), so it avoids composite index pain.
Query<Map<String, dynamic>> _joinedEventsQuery(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('events')
      .orderBy('lastUploadAt', descending: true);
}

class _MyEventsHalf extends StatelessWidget {
  const _MyEventsHalf({required this.uid});

  final String uid;

  // Controls how tall each card is in the list
  static const double _rowHeight = 92;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myEventsQuery(uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _EventsSection(
            title: 'My Events',
            subtitle: "You're collecting the memories.",
            badgeCount: 0,
            backgroundTint: AppTokens.tintBlue,
            child: _ErrorCard(message: snap.error.toString()),
          );
        }

        if (!snap.hasData) {
          return _EventsSection(
            title: 'My Events',
            subtitle: "You're collecting the memories.",
            badgeCount: 0,
            backgroundTint: AppTokens.tintBlue,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snap.data!.docs
            .where((d) => !_isDeletedEvent(d.data()))
            .toList();

        // Sort client-side by createdAt desc (Timestamp or int). Safe fallback: 0.
        docs.sort((a, b) {
          final ta = _readComparableTime(a.data()['createdAt']);
          final tb = _readComparableTime(b.data()['createdAt']);
          return tb.compareTo(ta);
        });

        final count = docs.length;

        final body = docs.isEmpty
            ? _EmptyCard(
          message: 'You haven’t created any events yet.',
          onPrimary: () => context.pushNamed(AppRoutes.createEvent),
          primaryText: 'Create your first event',
        )
            : LayoutBuilder(

          builder: (context, constraints) {
            final maxListHeight = _rowHeight * 3.5;
            final listHeight = constraints.maxHeight < maxListHeight
                ? constraints.maxHeight
                : maxListHeight;

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: listHeight,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();

                    final title = (data['title'] ?? data['name'] ?? 'Event').toString();
                    final coverUrl = (data['coverUrl'] ??
                        data['coverImageUrl'] ??
                        data['posterUrl'])
                        ?.toString();

                    return _EventCard(
                      title: title,
                      subtitle: 'Host • Tap to manage',
                      coverUrl: coverUrl,
                      onTap: () => context.pushNamed(
                        AppRoutes.eventDetail,
                        pathParameters: {'eventId': d.id},
                      ),
                      trailing: const Icon(Icons.more_horiz),
                    );
                  },
                ),
              ),
            );
          },
        );

        return _EventsSection(
          title: 'My Events',
          subtitle: "You're collecting the memories.",
          badgeCount: count,
          backgroundTint: AppTokens.tintBlue,
          child: body,
        );
      },
    );
  }
}

class _JoinedEventsHalf extends StatelessWidget {
  const _JoinedEventsHalf({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _joinedEventsQuery(uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _EventsSection(
            title: 'Joined Events',
            subtitle: "Events you've joined by submitting a message.",
            badgeCount: 0,
            backgroundTint: AppTokens.tintLav,
            child: _FriendlyIndexCard(),
          );
        }

        if (!snap.hasData) {
          return _EventsSection(
            title: 'Joined Events',
            subtitle: "Events you've joined by submitting a message.",
            badgeCount: 0,
            backgroundTint: AppTokens.tintLav,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snap.data!.docs;

        // HIDE: only show joined events where user has successfully submitted at least one upload.
        final filtered = docs.where((d) {
          final m = d.data();
          return (m['hasUploaded'] == true);
        }).toList();

        final count = filtered.length;

        final body = filtered.isEmpty
            ? _EmptyCard(
          message:
          'When you submit a message to an event, '
              'it will appear here.',
          onPrimary: () => context.goNamed(AppRoutes.home),
          primaryText: 'Join an event',
        )
            : ListView.separated(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final joinedDoc = filtered[i];
            final eventId = joinedDoc.id;

            // Pull event display data from /events so title/cover show correctly.
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .doc(eventId)
                  .snapshots(),
              builder: (context, evSnap) {
                // If event doc is gone, don't show a ghost card.
                if (evSnap.hasData && evSnap.data != null && !evSnap.data!.exists) {
                  return const SizedBox.shrink();
                }

                final ev = evSnap.data?.data();

                // If event is soft-deleted, hide it.
                if (ev != null && _isDeletedEvent(ev)) {
                  return const SizedBox.shrink();
                }

                final title = (ev?['title'] ??
                    ev?['name'] ??
                    joinedDoc.data()['eventTitle'] ??
                    joinedDoc.data()['eventName'] ??
                    'Event')
                    .toString();

                final coverUrl = (ev?['coverUrl'] ??
                    ev?['coverImageUrl'] ??
                    ev?['posterUrl'] ??
                    joinedDoc.data()['coverUrl'])
                    ?.toString();

                return _EventCard(
                  title: title,
                  subtitle: 'Tap to view details',
                  coverUrl: coverUrl,
                  onTap: () => context.pushNamed(
                    AppRoutes.eventDetail,
                    pathParameters: {'eventId': eventId},
                  ),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            );
          },
        );

        return _EventsSection(
          title: 'Joined Events',
          subtitle: "Events you've joined by submitting a message.",
          badgeCount: count,
          backgroundTint: AppTokens.tintLav,
          child: body,
        );
      },
    );
  }
}

class _EventsSection extends StatelessWidget {
  const _EventsSection({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.backgroundTint,
    required this.badgeCount,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Color backgroundTint;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundTint,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTokens.title,
                ),
              ),
              _Badge(count: badgeCount),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTokens.sub),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text('$count', style: AppTokens.badge),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.coverUrl,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? coverUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              _CoverThumb(url: coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTokens.sub,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 56,
        height: 56,
        child: hasUrl
        // ✅ Correct CoverImage usage
            ? CoverImage(
          coverUrl: url!,
          coverPath: '',
          fit: BoxFit.cover,
        )
            : Container(
          color: Colors.black.withOpacity(0.04),
          child: Icon(
            Icons.image_outlined,
            color: Colors.black.withOpacity(0.35),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.message,
    this.icon,
    this.onPrimary,
    this.primaryText,
  });

  final String message;
  final IconData? icon;
  final VoidCallback? onPrimary;
  final String? primaryText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 44,
              color: Colors.black.withOpacity(0.35),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTokens.sub,
          ),
          if (onPrimary != null && primaryText != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 44,
              width: 260,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  alignment: Alignment.center,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(primaryText!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Professional message instead of dumping the whole Firestore console URL to users.
class _FriendlyIndexCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Something in your Firestore query needs an index.',
            style: AppTokens.h2,
          ),
          const SizedBox(height: 10),
          Text(
            'For MVP, we avoid index-heavy queries.\n'
                'If you still see this, another screen is using a composite query.',
            style: AppTokens.sub,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        'Error:\n$message',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Converts Firestore timestamp/int/date to a comparable int (ms since epoch).
int _readComparableTime(dynamic v) {
  if (v == null) return 0;

  if (v is Timestamp) return v.millisecondsSinceEpoch;
  if (v is int) return v;
  if (v is DateTime) return v.millisecondsSinceEpoch;

  // Some people store as string millis
  if (v is String) {
    final parsed = int.tryParse(v);
    return parsed ?? 0;
  }

  return 0;
}

bool _isDeletedEvent(Map<String, dynamic> data) {
  final status = (data['status'] ?? '').toString().toLowerCase().trim();
  final isDeleted = data['isDeleted'] == true;
  final hasDeletedAt = data['deletedAt'] != null;
  return status == 'deleted' || isDeleted || hasDeletedAt;
}