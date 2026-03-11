import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/tokens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sign in to view profile.')));
    }

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDoc.snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};

          String _s(dynamic v) => (v is String) ? v.trim() : '';
          int _i(dynamic v) => (v is num) ? v.toInt() : 0;

          final firstName = _s(data['firstName']);
          final lastName = _s(data['lastName']);
          final displayName = _s(data['displayName']);
          final email = user.email ?? _s(data['email']);
          final photoUrl = _s(data['photoUrl']);

          final notificationsEnabled =
          (data['notificationsEnabled'] is bool) ? data['notificationsEnabled'] as bool : true;

          final stats = (data['stats'] is Map<String, dynamic>)
              ? data['stats'] as Map<String, dynamic>
              : <String, dynamic>{};

          final eventsCreated = _i(stats['eventsCreated']);
          final eventsJoined = _i(stats['eventsJoined']);
          final messagesSent = _i(stats['messagesSent']);
          final messagesReceived = _i(stats['messagesReceived']);

          final name = (firstName.isNotEmpty || lastName.isNotEmpty)
              ? '$firstName $lastName'.trim()
              : (displayName.isNotEmpty ? displayName : 'Your Name');

          return ListView(
            padding: const EdgeInsets.all(AppTokens.s16),
            children: [
              _ProfileHeader(
                name: name,
                email: email,
                photoUrl: photoUrl,
                onEditName: () async {
                  final updated = await showModalBottomSheet<_NameUpdate>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _EditNameSheet(firstName: firstName, lastName: lastName),
                  );
                  if (updated == null) return;

                  await userDoc.set(
                    {
                      'firstName': updated.firstName.trim(),
                      'lastName': updated.lastName.trim(),
                      'displayName': '${updated.firstName} ${updated.lastName}'.trim(),
                      'lastActiveAt': FieldValue.serverTimestamp(),
                    },
                    SetOptions(merge: true),
                  );
                },
                onChangePhoto: () => _changeProfilePhoto(context, user.uid, userDoc),
              ),

              const SizedBox(height: AppTokens.s16),

              _ActivityCard(
                eventsCreated: eventsCreated,
                eventsJoined: eventsJoined,
                messagesSent: messagesSent,
                messagesReceived: messagesReceived,
              ),

              const SizedBox(height: AppTokens.s16),

              _SectionTitle('Notifications'),
              const SizedBox(height: AppTokens.s8),

              Container(
                decoration: BoxDecoration(
                  color: AppTokens.card,
                  borderRadius: BorderRadius.circular(AppTokens.r16),
                  border: Border.all(color: AppTokens.stroke),
                ),
                child: SwitchListTile(
                  title: const Text('Push notifications'),
                  subtitle: Text(
                    notificationsEnabled ? 'On' : 'Off',
                    style: AppTokens.small.copyWith(color: AppTokens.subInk),
                  ),
                  value: notificationsEnabled,
                  onChanged: (v) async {
                    await userDoc.set({'notificationsEnabled': v}, SetOptions(merge: true));
                  },
                ),
              ),

              const SizedBox(height: AppTokens.s24),

              _SectionTitle('Premium'),
              const SizedBox(height: AppTokens.s8),

              _CardButton(
                icon: Icons.star_outline,
                title: 'VIP ShoutOut!',
                subtitle: 'Coming soon',
                onTap: () => _vipDialog(context),
              ),
              const SizedBox(height: AppTokens.s12),

              _CardButton(
                icon: Icons.logout,
                title: 'Sign out',
                subtitle: 'Log out of this device',
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) context.go('/auth');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _changeProfilePhoto(
      BuildContext context,
      String uid,
      DocumentReference<Map<String, dynamic>> userDoc,
      ) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (file == null) return;

      _showBlockingProgress(context, 'Updating photo…');

      // Universal upload path; works on iOS/Android/Web.
      final bytes = await file.readAsBytes();
      final ext = (file.name.split('.').length > 1) ? file.name.split('.').last.toLowerCase() : 'jpg';
      final contentType = (ext == 'png') ? 'image/png' : 'image/jpeg';

      final ref = FirebaseStorage.instance.ref('users/$uid/profile.$ext');
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      final url = await task.ref.getDownloadURL();

      await userDoc.set(
        {
          'photoUrl': url,
          'lastActiveAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // close dialog
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (e) {
      if (context.mounted) {
        // close progress if open
        Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update photo: $e')),
        );
      }
    }
  }

  static void _showBlockingProgress(BuildContext context, String label) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }

  static void _vipDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('VIP ShoutOut — Coming soon'),
        content: const Text(
          'VIP ShoutOut will let you book premium shoutouts (celebs/creators) for special moments.\n\n'
              'Learn more at: mckintoye.com/shoutout',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ✅ safest possible close (no crash)
              Navigator.of(dialogCtx, rootNavigator: true).maybePop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String photoUrl;
  final VoidCallback onEditName;
  final VoidCallback onChangePhoto;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onEditName,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: AppTokens.card,
        borderRadius: BorderRadius.circular(AppTokens.r16),
        border: Border.all(color: AppTokens.stroke),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onChangePhoto,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: AppTokens.accentSoft,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(initial, style: AppTokens.h2.copyWith(color: AppTokens.accent))
                  : null,
            ),
          ),
          const SizedBox(width: AppTokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTokens.h2.copyWith(color: AppTokens.ink)),
                const SizedBox(height: 4),
                Text(email, style: AppTokens.small.copyWith(color: AppTokens.subInk)),
                const SizedBox(height: 4),
                Text(
                  'Tap photo to change (optional)',
                  style: AppTokens.small.copyWith(color: AppTokens.subInk),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEditName, child: const Text('Edit')),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatefulWidget {
  final int eventsCreated;
  final int eventsJoined;
  final int messagesSent;
  final int messagesReceived;

  const _ActivityCard({
    required this.eventsCreated,
    required this.eventsJoined,
    required this.messagesSent,
    required this.messagesReceived,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.card,
        borderRadius: BorderRadius.circular(AppTokens.r16),
        border: Border.all(color: AppTokens.stroke),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            borderRadius: BorderRadius.circular(AppTokens.r16),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.s16),
              child: Row(
                children: [
                  Text('Your activity', style: AppTokens.h2.copyWith(color: AppTokens.ink)),
                  const Spacer(),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppTokens.s16),
              child: Column(
                children: [
                  _StatRow(label: 'Events created', value: widget.eventsCreated),
                  const SizedBox(height: AppTokens.s8),
                  _StatRow(label: 'Events joined', value: widget.eventsJoined),
                  const SizedBox(height: AppTokens.s8),
                  _StatRow(label: 'Messages sent', value: widget.messagesSent),
                  const SizedBox(height: AppTokens.s8),
                  _StatRow(label: 'Messages received', value: widget.messagesReceived),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTokens.body.copyWith(color: AppTokens.ink))),
        Text('$value', style: AppTokens.h2.copyWith(color: AppTokens.ink)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTokens.h2.copyWith(color: AppTokens.ink));
  }
}

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CardButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.r16),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.s16),
        decoration: BoxDecoration(
          color: AppTokens.card,
          borderRadius: BorderRadius.circular(AppTokens.r16),
          border: Border.all(color: AppTokens.stroke),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTokens.ink),
            const SizedBox(width: AppTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTokens.body.copyWith(color: AppTokens.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTokens.small.copyWith(color: AppTokens.subInk)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _EditNameSheet extends StatefulWidget {
  final String firstName;
  final String lastName;
  const _EditNameSheet({required this.firstName, required this.lastName});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController first;
  late final TextEditingController last;

  @override
  void initState() {
    super.initState();
    first = TextEditingController(text: widget.firstName);
    last = TextEditingController(text: widget.lastName);
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Edit name', style: AppTokens.h2),
          const SizedBox(height: 12),
          TextField(controller: first, decoration: const InputDecoration(labelText: 'First name')),
          const SizedBox(height: 12),
          TextField(controller: last, decoration: const InputDecoration(labelText: 'Last name')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _NameUpdate(first.text, last.text)),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NameUpdate {
  final String firstName;
  final String lastName;
  const _NameUpdate(this.firstName, this.lastName);
}