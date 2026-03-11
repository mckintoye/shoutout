import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'utils/app_frame.dart';

class ShoutOutApp extends StatelessWidget {
  const ShoutOutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'ShoutOut!',
      theme: AppTheme.light(),
      routerConfig: AppRouter.create(),
      builder: (context, child) => AppFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}
