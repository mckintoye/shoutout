import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppFrame extends StatelessWidget {
  final Widget child;
  const AppFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 520; // desktop/tablet-ish
    final shouldFrame = kIsWeb || isWide;

    if (!shouldFrame) return child;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14), // dark surround (premium)
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430), // iPhone-ish width
          child: AspectRatio(
            aspectRatio: 9 / 19.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 30,
                      spreadRadius: 2,
                      offset: Offset(0, 16),
                      color: Colors.black26,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
