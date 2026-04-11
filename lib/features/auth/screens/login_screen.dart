import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth_service.dart';
import '../screens/restore_data_screen.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthService authService = ref.read(authServiceProvider);
    final scheme = Theme.of(context).colorScheme;
    final bool supportsAppleSignIn =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFF3D4EBF),
              scheme.primary,
              const Color(0xFF8E54E9),
            ],
            stops: const <double>[0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(flex: 3),
                // App icon
                Center(
                    child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text('📅', style: TextStyle(fontSize: 44)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'DayMark',
                  style: GoogleFonts.nunito(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Track moments & streaks\nthat matter most.',
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 3),
                // Auth card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      _AuthButton(
                        label: 'Continue with Email & Password',
                        icon: Icons.email_outlined,
                        onPressed: () async {
                          await _signInWithEmailPassword(context, authService);
                        },
                      ),
                      const SizedBox(height: 10),
                      _AuthButton(
                        label: 'Continue with Google',
                        icon: Icons.g_mobiledata_rounded,
                        onPressed: () async {
                          try {
                            final credential = await authService.signInWithGoogle();
                            if (credential == null) {
                              return;
                            }
                            if (context.mounted) {
                              await Navigator.of(context).push<bool>(
                                MaterialPageRoute<bool>(
                                  builder: (_) => const RestoreDataScreen(),
                                ),
                              );
                              if (context.mounted) context.go('/home');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Google sign-in failed: $e')),
                              );
                            }
                          }
                        },
                      ),
                      if (supportsAppleSignIn) ...<Widget>[
                        const SizedBox(height: 10),
                        _AuthButton(
                          label: 'Continue with Apple',
                          icon: Icons.apple_rounded,
                          onPressed: () async {
                            try {
                              final credential = await authService.signInWithApple();
                              if (credential == null) {
                                return;
                              }
                              if (context.mounted) {
                                await Navigator.of(context).push<bool>(
                                  MaterialPageRoute<bool>(
                                    builder: (_) => const RestoreDataScreen(),
                                  ),
                                );
                                if (context.mounted) context.go('/home');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Apple sign-in failed: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/home'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text(
                    'Continue as Guest  →',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithEmailPassword(
    BuildContext context,
    AuthService authService,
  ) async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sign in with Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign in'),
            ),
          ],
        );
      },
    );

    if (submit != true) {
      emailController.dispose();
      passwordController.dispose();
      return;
    }

    final String email = emailController.text.trim();
    final String password = passwordController.text;
    emailController.dispose();
    passwordController.dispose();

    if (email.isEmpty || password.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email and password are required.')),
        );
      }
      return;
    }

    try {
      await authService.signInWithEmailPassword(email: email, password: password);
      if (!context.mounted) {
        return;
      }
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const RestoreDataScreen(),
        ),
      );
      if (context.mounted) {
        context.go('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email sign-in failed: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email sign-in failed: $e')),
        );
      }
    }
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Text(
            label,
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF5E6AD2),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
