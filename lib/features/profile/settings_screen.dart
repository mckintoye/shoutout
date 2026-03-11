import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/repositories/auth_repository.dart';

import '../../theme/tokens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // TODO: set these to your real live URLs
  static const String privacyUrl = 'https://mckintoye.com/shoutout/privacy';
  static const String termsUrl = 'https://mckintoye.com/shoutout/terms';
  static const String supportEmail = 'support@mckintoye.com';
  static const String supportSubject = 'ShoutOut! Support';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.s16),
        children: [
          _SectionTitle('About'),
          const SizedBox(height: AppTokens.s8),
          _CardTile(
            icon: Icons.info_outline,
            title: 'About ShoutOut!',
            subtitle: 'What this app does (quick)',
            onTap: () => _showAboutApp(context),
          ),

          const SizedBox(height: AppTokens.s24),
          _SectionTitle('Legal'),
          const SizedBox(height: AppTokens.s8),
          _CardTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Open on web',
            onTap: () => _openUrl(context, privacyUrl),
          ),
          const SizedBox(height: AppTokens.s12),
          _CardTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Open on web',
            onTap: () => _openUrl(context, termsUrl),
          ),

          const SizedBox(height: AppTokens.s24),
          _SectionTitle('Support'),
          const SizedBox(height: AppTokens.s8),
          _CardTile(
            icon: Icons.support_agent_outlined,
            title: 'Contact support',
            subtitle: supportEmail,
            onTap: () => _emailSupport(context),
          ),

          const SizedBox(height: AppTokens.s24),
          _SectionTitle('Account'),
          const SizedBox(height: AppTokens.s8),
          _CardTile(
            icon: Icons.delete_outline,
            title: 'Delete account',
            subtitle: 'Permanently delete your account',
            danger: true,
            onTap: () => _deleteAccountDialog(context),
          ),
        ],
      ),
    );
  }

  static void _showAboutApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About ShoutOut!'),
        content: const Text(
          'ShoutOut helps you create events and collect short video messages from friends and family.\n\n'
              'Hosts see the full tribute. Contributors only see what they submit.\n\n'
              'More features are coming soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  static Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': supportSubject,
      },
    );

    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email app: $e')),
        );
      }
    }
  }

  static void _deleteAccountDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account.\n'
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;

      // Progress modal
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final repo = AuthRepository();

      try {
        await repo.deleteAccount();

        if (context.mounted) {
          Navigator.of(context).pop(); // close progress
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted.')),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // close progress

          if (e.code == 'requires-recent-login') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('For security, please sign in again then retry Delete Account.'),
              ),
            );
            await repo.signOut();
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: ${e.message ?? e.code}')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // close progress
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    });
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

class _CardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _CardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTokens.body.copyWith(
      color: danger ? Colors.red : AppTokens.ink,
      fontWeight: FontWeight.w600,
    );

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
            Icon(icon, color: danger ? Colors.red : AppTokens.ink),
            const SizedBox(width: AppTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
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