import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';

class UploadSuccessScreen extends StatelessWidget {
  const UploadSuccessScreen({
    super.key,
    required this.eventId,
  });

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uploaded'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppTokens.pagePad,
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.check_circle, size: 56),
              const SizedBox(height: 10),
              Text('Upload complete', style: AppTokens.h1, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTokens.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTokens.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What next?', style: AppTokens.h2),
                    const SizedBox(height: 6),
                    Text(
                      'Create your own ShoutOut, join another event, or review your message archive.',
                      style: AppTokens.sub,
                    ),
                    const SizedBox(height: 14),
                    _CtaButton(
                      icon: Icons.home_outlined,
                      title: 'Go to Home',
                      subtitle: 'Create your own / join another ShoutOut',
                      onTap: () => context.go('/home'),
                    ),
                    const SizedBox(height: 10),
                    _CtaButton(
                      icon: Icons.event_outlined,
                      title: 'Go to Events',
                      subtitle: 'See joined events or leave another message (max 5)',
                      onTap: () => context.go('/events'),
                    ),
                    const SizedBox(height: 10),
                    _CtaButton(
                      icon: Icons.video_library_outlined,
                      title: 'Go to Gallery',
                      subtitle: 'View your message archive',
                      onTap: () => context.go('/uploads'),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/event/$eventId'),
                child: const Text('Back to Event'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTokens.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTokens.stroke),
                ),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTokens.body.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTokens.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}