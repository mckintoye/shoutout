import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/upload_repository.dart';
import '../../router/app_router.dart';
import '../../services/download_service.dart';
import '../../theme/tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';

class GalleryTab extends StatefulWidget {
  const GalleryTab({super.key});

  @override
  State<GalleryTab> createState() => _GalleryTabState();
}

String _buildFileName(String eventTitle, Map<String, dynamic> u) {
  String safe(String s) =>
      s.trim().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');

  final title = safe(eventTitle.isEmpty ? 'Event' : eventTitle);
  final createdAt = u['createdAt'];
  DateTime dt = DateTime.now();

  if (createdAt is Timestamp) dt = createdAt.toDate();
  final stamp =
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}_'
      '${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}';

  return '${title}_$stamp.mp4';
}

class _GalleryTabState extends State<GalleryTab> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _repo = UploadRepository();
  final _dl = DownloadService();

  bool _busy = false;
  String? _busyText;

  // eventId -> selected uploadIds
  final Map<String, Set<String>> _selectedByEvent = {};
  final Set<String> _selectModeEvents = {};

  // collapsed by default
  final Set<String> _expandedHost = {};
  final Set<String> _expandedMine = {};

  String? get _uid => _auth.currentUser?.uid;

  String? _filterEventId;
  bool _autoExpandedFilter = false;


  Stream<QuerySnapshot<Map<String, dynamic>>> _hostedEventsStream(String uid) {
    // index-safe: no orderBy here; we sort client-side
    return _firestore.collection('events').where('createdByUid', isEqualTo: uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myUploadsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('uploads')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventUploadsStream(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('uploads')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  bool _isSelectMode(String eventId) => _selectModeEvents.contains(eventId);

  bool _isSelected(String eventId, String uploadId) =>
      _selectedByEvent[eventId]?.contains(uploadId) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final uri = GoRouterState.of(context).uri;
    final incoming = uri.queryParameters['eventId'];

    if (incoming != null && incoming.isNotEmpty && incoming != _filterEventId) {
      setState(() {
        _filterEventId = incoming;
        _autoExpandedFilter = false;
      });
    } else if ((incoming == null || incoming.isEmpty) && _filterEventId != null) {
      setState(() {
        _filterEventId = null;
        _autoExpandedFilter = false;
      });
    }
  }

  void _toggleSelectMode(String eventId) {
    setState(() {
      if (_selectModeEvents.contains(eventId)) {
        _selectModeEvents.remove(eventId);
        _selectedByEvent.remove(eventId);
      } else {
        _selectModeEvents.add(eventId);
        _selectedByEvent.putIfAbsent(eventId, () => <String>{});
        _expandedHost.add(eventId);
        _expandedMine.add(eventId);
      }
    });
  }

  void _toggleSelected(String eventId, String uploadId) {
    setState(() {
      final set = _selectedByEvent.putIfAbsent(eventId, () => <String>{});
      if (set.contains(uploadId)) {
        set.remove(uploadId);
      } else {
        set.add(uploadId);
      }
    });
  }



  List<Map<String, dynamic>> _filterSelected(String eventId, List<Map<String, dynamic>> uploads) {
    final selected = _selectedByEvent[eventId] ?? <String>{};
    if (selected.isEmpty) return <Map<String, dynamic>>[];

    return uploads.where((u) => selected.contains((u['uploadId'] ?? '').toString())).toList();
  }

  void _selectAll(String eventId, List<Map<String, dynamic>> uploads) {
    setState(() {
      final set = _selectedByEvent.putIfAbsent(eventId, () => <String>{});
      for (final u in uploads) {
        final id = (u['uploadId'] ?? '').toString();
        if (id.isNotEmpty) set.add(id);
      }
    });
  }





  Future<void> _downloadUploads({
    required String eventTitle,
    required List<Map<String, dynamic>> uploads,
  }) async {
    if (uploads.isEmpty) return;

    setState(() {
      _busy = true;
      _busyText = 'Preparing download…';
    });

    try {
      final urls = <Uri>[];
      final names = <String>[];

      for (final u in uploads) {
        final raw = (u['downloadUrl'] ?? '').toString().trim();
        if (raw.isEmpty) continue;

        final uri = Uri.tryParse(raw);
        if (uri == null) continue;

        urls.add(uri);
        names.add(_buildFileName(eventTitle, u));
      }

      if (urls.isEmpty) return;

      setState(() => _busyText = 'Downloading…');

      final savedPaths = await _dl.downloadMany(
        urls: urls,
        fileNames: names,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() => _busyText = 'Downloading $done / $total…');
        },
      );

      await _dl.shareFiles(context, savedPaths);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download complete')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyText = null;
      });
    }
  }

  void _openPlayback(
      BuildContext context, {
        required String eventTitle,
        required Map<String, dynamic> upload,
      }) {
    final url = (upload['downloadUrl'] ?? '').toString().trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video not ready yet.')),
      );
      return;
    }

    context.pushNamed(
      AppRoutes.playback,
      extra: <String, dynamic>{
        'title': eventTitle.isEmpty ? 'Video message' : eventTitle,
        'videoUrl': url,
      },
    );
  }

  Future<void> _deleteUploadsEverywhere({
    required String eventId,
    required String eventTitle,
    required String userId,
    required List<Map<String, dynamic>> uploads,
  }) async {
    if (uploads.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete message?'),
        content: Text(
          uploads.length == 1
              ? 'This will permanently remove your message from \"$eventTitle\"'
              : 'This will permanently remove ${uploads.length} messages from "$eventTitle".',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      _busy = true;
      _busyText = 'Removing…';
    });

    try {
      for (final u in uploads) {
        final uploadId = (u['uploadId'] ?? '').toString();
        if (uploadId.isEmpty) continue;

        await _repo.deleteUpload(
          eventId: eventId,
          uploadId: uploadId,
          userId: userId,
          storagePath: (u['storagePath'] as String?),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Remove failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyText = null;
      });
    }
  }

  Future<void> _deleteCollectionEvent({
    required BuildContext context,
    required String eventId,
    required String title,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text(
          'This will permanently delete "$title" and all its videos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('deleteEventCascade');
      await fn.call({'eventId': eventId});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }




  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Not signed in')));

    return Scaffold(
      appBar: AppBar(title: const Text('Gallery'), centerTitle: true),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: AppTokens.pagePad,
              child: Column(
                children: [
                  Expanded(
                    child: _Section(
                      title: 'My Collections',
                      subtitle: 'Video messages from events you host.',
                      tint: AppTokens.tintBlue,
                      child: _CollectionsHalf(uid: uid, parent: this),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _Section(
                      title: 'My Messages',
                      subtitle: 'Video messages you have submitted, grouped by event.',
                      tint: AppTokens.tintLav,
                      child: _MessagesHalf(uid: uid, parent: this),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.12),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTokens.stroke),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(_busyText ?? 'Working…', style: AppTokens.body),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTokens.title),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTokens.sub),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CollectionsHalf extends StatelessWidget {
  const _CollectionsHalf({required this.uid, required this.parent});

  final String uid;
  final _GalleryTabState parent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: parent._hostedEventsStream(uid),
      builder: (context, snap) {
        if (snap.hasError) return _ErrorCard(message: snap.error.toString());
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final events = snap.data!.docs.toList();

        // newest first, client-side
        events.sort((a, b) {
          final at = a.data()['createdAt'];
          final bt = b.data()['createdAt'];
          final ad = at is Timestamp ? at.toDate() : null;
          final bd = bt is Timestamp ? bt.toDate() : null;
          return (bd ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(ad ?? DateTime.fromMillisecondsSinceEpoch(0));
        });

        if (events.isEmpty) {
          return _EmptyCard(
            icon: Icons.video_collection_outlined,
            title: 'No collections yet',
            message: 'Create an event to start collecting videos.',
            ctaText: 'Create your first event',
            onCta: () => context.go('${AppRoutes.eventsPath}/create'),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final d = events[i];
            final data = d.data();
            final eventId = d.id;
            final rawTitle = (data['title'] ?? data['name'] ?? data['eventName']) as String?;
            final title = (rawTitle ?? '').trim().isEmpty ? 'Untitled event' : rawTitle!.trim();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: parent._eventUploadsStream(eventId),
              builder: (context, upSnap) {
                final uploadsDocs = upSnap.data?.docs ?? const [];
                final uploads = uploadsDocs.map((e) => e.data()).toList();
                final count = uploads.length;

                final expanded = parent._expandedHost.contains(eventId);

                return _EventGroupCard(
                  title: title,
                  count: count,
                  expanded: expanded,
                  onToggleExpanded: () {
                    parent.setState(() {
                      expanded ? parent._expandedHost.remove(eventId) : parent._expandedHost.add(eventId);
                    });
                  },
                  leadingIcon: Icons.collections_bookmark_outlined,
                  leadingCoverUrl: (data['coverUrl'] ?? '').toString(),
                  actions: [
                    IconButton(
                      tooltip: parent._isSelectMode(eventId) ? 'Done' : 'Select',
                      onPressed: () => parent._toggleSelectMode(eventId),
                      icon: Icon(parent._isSelectMode(eventId)
                          ? Icons.check_circle
                          : Icons.check_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Delete collection',
                      onPressed: parent._busy
                          ? null
                          : () => parent._deleteCollectionEvent(
                        context: context,
                        eventId: eventId,
                        title: title,
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                    IconButton(
                      tooltip: 'Download all',
                      onPressed: count == 0 ? null : () => parent._downloadUploads(eventTitle: title, uploads: uploads),
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ],
                  children: uploads.isEmpty

                      ? [const Padding(padding: EdgeInsets.fromLTRB(12, 10, 12, 12), child: Text('No messages yet.'))]
                      : uploads

                      .map((u) => _UploadRow(
                    upload: u,
                    selectable: parent._isSelectMode(eventId),
                    selected: parent._isSelected(eventId, (u['uploadId'] ?? '').toString()),
                    onToggleSelected: () => parent._toggleSelected(eventId, (u['uploadId'] ?? '').toString()),
                    onPlay: () => parent._openPlayback(
                      context,
                      eventTitle: title,
                      upload: u,
                    ),
                  ))
                      .toList(),
                  footer: parent._isSelectMode(eventId) && count > 0
                      ? _SelectFooter(
                    selectedCount: parent._selectedByEvent[eventId]?.length ?? 0,
                    onDownloadSelected: () {
                      final selected = parent._filterSelected(eventId, uploads);
                      if (selected.isEmpty) return;
                      parent._downloadUploads(eventTitle: title, uploads: selected);
                    },
                  )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MessagesHalf extends StatelessWidget {
  const _MessagesHalf({required this.uid, required this.parent});

  final String uid;
  final _GalleryTabState parent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: parent._myUploadsStream(uid),
      builder: (context, snap) {
        if (snap.hasError) return _ErrorCard(message: snap.error.toString());
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final uploads = snap.data!.docs.map((d) => d.data()).toList();
        if (uploads.isEmpty) {
          return _EmptyCard(
            icon: Icons.forum_outlined,
            title: 'No messages yet',
            message: 'When you submit a message to an event, it will appear here.',
            ctaText: 'Join an event',
            onCta: () => context.go(AppRoutes.homePath),
          );
        }

        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final u in uploads) {
          final eventId = (u['eventId'] ?? '').toString();
          if (eventId.isEmpty) continue;
          grouped.putIfAbsent(eventId, () => []).add(u);
        }

        // ✅ Optional filter: /app/uploads?eventId=XYZ
        final filterId = parent._filterEventId;
        if (filterId != null && filterId.isNotEmpty) {
          grouped.removeWhere((eventId, _) => eventId != filterId);

          // Auto-expand the filtered event once.
          if (!parent._autoExpandedFilter) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!parent.mounted) return;
              parent.setState(() {
                parent._expandedMine.add(filterId);
                parent._autoExpandedFilter = true;
              });
            });
          }
        }



        final groups = grouped.entries.toList()
          ..sort((a, b) => _latestDate(b.value).compareTo(_latestDate(a.value)));


        return Column(
          children: [
            if (filterId != null && filterId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/app/uploads'),
                    icon: const Icon(Icons.close),
                    label: const Text('Clear filter'),
                  ),
                ),
              ),

            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final entry = groups[i];
                  final eventId = entry.key;
                  final groupUploads = entry.value;
                  final expanded = parent._expandedMine.contains(eventId);

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: parent._firestore.collection('events').doc(eventId).snapshots(),
                    builder: (context, evSnap) {
                      final rawTitle = (evSnap.data?.data()?['title'] ??
                          evSnap.data?.data()?['name'] ??
                          evSnap.data?.data()?['eventTitle'])
                          ?.toString();

                      final title = (rawTitle == null || rawTitle.trim().isEmpty)
                          ? 'Untitled event'
                          : rawTitle.trim();



                      return _EventGroupCard(
                        title: title,
                        count: groupUploads.length,
                        expanded: expanded,
                        onToggleExpanded: () {
                          parent.setState(() {
                            expanded
                                ? parent._expandedMine.remove(eventId)
                                : parent._expandedMine.add(eventId);
                          });
                        },
                        leadingIcon: Icons.video_camera_front_outlined,
                        leadingCoverUrl: 'coverUrl',
                        actions: [
                          IconButton(
                            tooltip: parent._isSelectMode(eventId) ? 'Done' : 'Select',
                            onPressed: () => parent._toggleSelectMode(eventId),
                            icon: Icon(parent._isSelectMode(eventId)
                                ? Icons.check_circle
                                : Icons.check_circle_outline),
                          ),
                        ],
                        children: [
                          ...groupUploads.map((u) {
                            final uploadId = (u['uploadId'] ?? '').toString();
                            final selected = parent._selectedByEvent[eventId]?.contains(uploadId) ?? false;

                            return _UploadRow(
                              upload: u,
                              selectable: parent._isSelectMode(eventId),
                              selected: selected,
                              onToggleSelected: () => parent._toggleSelected(eventId, uploadId),
                              onPlay: () => parent._openPlayback(
                                context,
                                eventTitle: title,
                                upload: u,
                              ),
                            );
                          }),
                          if (parent._isSelectMode(eventId))
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: parent._busy
                                              ? null
                                              : () {
                                            final selectedUploads =
                                            parent._filterSelected(eventId, groupUploads);
                                            parent._downloadUploads(
                                              eventTitle: title,
                                              uploads: selectedUploads,
                                            );
                                          },
                                          icon: const Icon(Icons.download),
                                          label: const Text('Download'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: parent._busy
                                              ? null
                                              : () {
                                            final selectedUploads =
                                            parent._filterSelected(eventId, groupUploads);
                                            parent._deleteUploadsEverywhere(
                                              eventId: eventId,
                                              eventTitle: title,
                                              userId: parent._uid!,
                                              uploads: selectedUploads,
                                            );
                                          },
                                          icon: const Icon(Icons.delete_outline),
                                          label: const Text('Delete'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: parent._busy ? null : () => parent._selectAll(eventId, groupUploads),
                                      child: const Text('Select all'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  DateTime _latestDate(List<Map<String, dynamic>> uploads) {
    DateTime latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final u in uploads) {
      final ts = u['createdAt'];
      final dt = ts is Timestamp ? ts.toDate() : null;
      if (dt != null && dt.isAfter(latest)) latest = dt;
    }
    return latest;
  }
}

class _EventGroupCard extends StatelessWidget {
  const _EventGroupCard({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggleExpanded,
    required this.leadingIcon,
    required this.leadingCoverUrl,
    required this.actions,
    required this.children,
    this.collapsedPreview,
    this.footer,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final IconData leadingIcon;
  final String leadingCoverUrl;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? collapsedPreview;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onToggleExpanded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTokens.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTokens.stroke),
                    ),
              clipBehavior: Clip.antiAlias,
                                   child: leadingCoverUrl.trim().isEmpty
                                     ? Icon(leadingIcon, size: 20)
                                   : Image.network(
                                       leadingCoverUrl,
                                       fit: BoxFit.cover,
                                       errorBuilder: (_, __, ___) => Icon(leadingIcon, size: 20),
                               ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTokens.h2),
                        const SizedBox(height: 4),
                        Text('$count video(s)', style: AppTokens.caption),
                      ],
                    ),
                  ),
                  ...actions,
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),

              // ✅ Collapsed preview (1 row)
              if (!expanded && collapsedPreview != null) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: AppTokens.stroke),
                const SizedBox(height: 8),
                collapsedPreview!,
              ],

              // Expanded list (full)
              if (expanded) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: AppTokens.stroke),
                const SizedBox(height: 8),
                ...children,
                if (footer != null) ...[
                  const SizedBox(height: 10),
                  footer!,
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({
    required this.upload,
    required this.selectable,
    required this.selected,
    required this.onToggleSelected,
    required this.onPlay,
  });

  final Map<String, dynamic> upload;
  final bool selectable;
  final bool selected;
  final VoidCallback onToggleSelected;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final dur = (upload['durationSec'] as int?) ?? 0;
    final createdAt = upload['createdAt'];
    final dt = createdAt is Timestamp ? createdAt.toDate() : null;

    final meta = '${_fmt(dur)}${dt == null ? '' : ' • ${dt.month}/${dt.day}/${dt.year}'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTokens.bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: selectable ? onToggleSelected : onPlay,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                if (selectable)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, size: 20),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(Icons.videocam_outlined, color: AppTokens.subInk),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Video message', style: AppTokens.body.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(meta, style: AppTokens.caption),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Play',
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_circle_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _SelectFooter extends StatelessWidget {
  const _SelectFooter({
    required this.selectedCount,
    required this.onDownloadSelected,
  });

  final int selectedCount;
  final VoidCallback onDownloadSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTokens.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selectedCount == 0
                  ? 'Select videos'
                  : '$selectedCount selected',
              style: AppTokens.body.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton.icon(
            onPressed: selectedCount == 0 ? null : onDownloadSelected,
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.message,
    this.icon,
    this.ctaText,
    this.onCta,
  });

  final String title;
  final String message;
  final IconData? icon;
  final String? ctaText;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTokens.stroke),
      ),
      child: SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 44, color: Colors.black.withOpacity(0.35)),
                const SizedBox(height: 14),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTokens.title,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTokens.sub,
              ),
              if (ctaText != null && onCta != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 44,
                  width: 260,
                  child: ElevatedButton(
                    onPressed: onCta,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      ctaText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTokens.stroke),
      ),
      child: Text('Error:\n$message', style: AppTokens.caption.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}