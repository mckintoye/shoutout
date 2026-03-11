import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../theme/tokens.dart';
import 'package:flutter/foundation.dart';

enum _AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  final String? redirectTo;
  const AuthScreen({super.key, this.redirectTo});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _repo = AuthRepository();

  final _email = TextEditingController();
  final _pass = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _loading = false;
  bool _showPass = false;
  String? _error;

  String _prettyError(Object e) {
    final s = e.toString();
    if (s.startsWith('Exception: ')) return s.replaceFirst('Exception: ', '');
    return s;
  }

  void _setLoading(bool v) => setState(() => _loading = v);

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repo.signInWithGoogle();
      final target = widget.redirectTo ?? '/app/home';
      if (mounted) context.go(target);
    } catch (e) {
      if (mounted) setState(() => _error = _prettyError(e));
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _apple() async {
    // Guard: Apple sign-in is iOS only
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      setState(() {
        _error = 'Apple sign-in is only available on iOS devices.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repo.signInWithApple();

      if (!mounted) return;

      final target = widget.redirectTo ?? '/app/home';
      context.go(target);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _prettyError(e);
      });
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;

    if (email.isEmpty || pass.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_mode == _AuthMode.signIn) {
        await _repo.signInEmail(email: email, password: pass);
      } else {
        await _repo.signUpEmail(email: email, password: pass);
      }

      final target = widget.redirectTo ?? '/app/home';
      if (mounted) context.go(target);
    } catch (e) {
      if (mounted) setState(() => _error = _prettyError(e));
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email, then tap “Forgot password?”.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repo.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link sent. Check your email.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = _prettyError(e));
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  void _openEmailSheet() {
    // reset errors but keep typed email if any
    setState(() => _error = null);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isSignIn = _mode == _AuthMode.signIn;
            final primaryLabel = isSignIn ? 'Sign in' : 'Create account';
            final switchLabel = isSignIn ? 'Create an account' : 'I already have an account';

            final canSubmit = _email.text.trim().isNotEmpty && _pass.text.isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: _SheetContainer(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // grab handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppTokens.stroke,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        isSignIn ? 'Continue with email' : 'Create account with email',
                        textAlign: TextAlign.center,
                        style: AppTokens.h2.copyWith(color: AppTokens.ink),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _pass,
                        obscureText: !_showPass,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => (canSubmit && !_loading) ? _submit() : null,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: _loading
                                ? null
                                : () {
                              setState(() => _showPass = !_showPass);
                              setSheetState(() {});
                            },
                            icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                          ),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppTokens.s12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTokens.r16),
                            color: Theme.of(ctx).colorScheme.errorContainer,
                            border: Border.all(
                              color: Theme.of(ctx).colorScheme.error.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (!canSubmit || _loading) ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : Text(primaryLabel),
                        ),
                      ),

                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                          setState(() {
                            _error = null;
                            _mode = isSignIn ? _AuthMode.signUp : _AuthMode.signIn;
                          });
                          setSheetState(() {});
                        },
                        child: Text(switchLabel),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background hero image (logo already in image)
          Positioned.fill(
            child: Image.asset(
             // color: Colors.white.withOpacity(0.01),
              'assets/images/auth_hero_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).size.height * 0.05,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/shoutout_logo.png',
                width: 400,
                fit: BoxFit.contain,
              ),
            ),
          ),


          Positioned(
            bottom: 440, // adjust if needed
            left: 24,
            right: 24,
            child: Column(
              children: [
                Text(
                  'Bring everyone’s message together.',
                  style: AppTokens.body.copyWith(
                    color: Colors.black.withOpacity(0.95),
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Create a shared video tribute in minutes.',
                  style: AppTokens.body.copyWith(
                    color: Colors.black.withOpacity(0.85),
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

          ),


          // Subtle dark fade at bottom to ground the sheet
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.18),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),

          // Bottom sheet content
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: BoxDecoration(
                    color: AppTokens.card.withOpacity(1.0),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTokens.stroke.withOpacity(0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sign in or create account',
                        textAlign: TextAlign.center,
                        style: AppTokens.h2.copyWith(color: AppTokens.ink),
                      ),
                      const SizedBox(height: 14),

                      // Google
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _google,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset('assets/icons/google_g.svg',
                                  height: 18
                              ),
                              const SizedBox(width: 12),
                              const Text('Continue with Google'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Apple
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _apple,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset('assets/icons/apple.svg', height: 18),
                              const SizedBox(width: 12),
                              const Text('Continue with Apple'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Email (opens modal form)
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _openEmailSheet,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mail_outline),
                              SizedBox(width: 12),
                              Text('Continue with email'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      TextButton(
                        onPressed: _loading ? null : _openEmailSheet,
                        child: const Text('View more'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}

/// Shared bottom sheet container styling (CashLens-ish)
class _SheetContainer extends StatelessWidget {
  final Widget child;
  const _SheetContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: AppTokens.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.r24)),
        border: Border.all(color: AppTokens.stroke),
      ),
      child: child,
    );
  }
}
