import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth_service.dart';
import '../../../core/constants.dart';
import '../../../app/router.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthService authService = ref.read(authServiceProvider);
    final bool supportsAppleSignIn = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF12131F),
      body: Stack(
        children: [
          // ── Hero gradient background ────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.62,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B45C8), Color(0xFF5E6AD2), Color(0xFF7C62D8)],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // ── Decorative circles ──────────────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.25,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // ── Full content ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top hero section ──────────────────────────────────────
                Expanded(
                  flex: 58,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 36),
                        // Logo row
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(11),
                                child: Image(image: AssetImage(AppConstants.logoAssetPath)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              AppConstants.appName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(flex: 2),
                        // Headline
                        Text(
                          'Every moment\ncounted.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1.2,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Track what matters. Build what lasts.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.5,
                          ),
                        ),
                        const Spacer(flex: 1),
                        // Feature bullets
                        _FeatureBullet(
                          emoji: '📅',
                          text: 'Countdown to events that matter',
                        ),
                        const SizedBox(height: 10),
                        _FeatureBullet(
                          emoji: '🔥',
                          text: 'Build habits with streak tracking',
                        ),
                        const SizedBox(height: 10),
                        _FeatureBullet(
                          emoji: '📱',
                          text: 'Live widgets on your home screen',
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
                // ── Bottom auth card ──────────────────────────────────────
                Expanded(
                  flex: 42,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12131F),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Get started',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in to sync across devices',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.50),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Google — primary CTA
                          _PremiumAuthButton(
                            label: 'Continue with Google',
                            iconWidget: const _GoogleIcon(),
                            isPrimary: true,
                            onPressed: () async {
                              try {
                                final credential = await authService.signInWithGoogle();
                                if (credential == null) return;
                                if (context.mounted) {
                                  context.go('/restore');
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
                          const SizedBox(height: 12),
                          // Email — secondary
                          _PremiumAuthButton(
                            label: 'Continue with Email',
                            iconWidget: const Icon(Icons.email_outlined, size: 20),
                            isPrimary: false,
                            onPressed: () async {
                              await _signInWithEmailPassword(context, authService);
                            },
                          ),
                          if (supportsAppleSignIn) ...[
                            const SizedBox(height: 12),
                            _PremiumAuthButton(
                              label: 'Continue with Apple',
                              iconWidget: const Icon(Icons.apple_rounded, size: 22),
                              isPrimary: false,
                              onPressed: () async {
                                try {
                                  final credential = await authService.signInWithApple();
                                  if (credential == null) return;
                                  if (context.mounted) {
                                    context.go('/restore');
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
                          const SizedBox(height: 20),
                          // Divider with "or"
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                           const SizedBox(height: 16),
                           // Guest
                           Center(
                             child: TextButton(
                               onPressed: () {
                                 ref.read(guestModeProvider.notifier).state = true;
                                 context.go('/home');
                               },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withValues(alpha: 0.55),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: Text(
                                'Continue as guest  →',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.50),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithEmailPassword(BuildContext context, AuthService authService) async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sign in with Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
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
      if (!context.mounted) return;
      context.go('/restore');
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

// ── Feature bullet ──────────────────────────────────────────────────────────
class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'sans-serif',
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.80),
          ),
        ),
      ],
    );
  }
}

// ── Premium Auth Button ──────────────────────────────────────────────────────
class _PremiumAuthButton extends StatelessWidget {
  const _PremiumAuthButton({
    required this.label,
    required this.iconWidget,
    required this.isPrimary,
    required this.onPressed,
  });

  final String label;
  final Widget iconWidget;
  final bool isPrimary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF3B45C8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 10),
              Text(label),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.85),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: IconThemeData(color: Colors.white.withValues(alpha: 0.75), size: 20),
              child: iconWidget,
            ),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }
}

// ── Google "G" icon ──────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Simplified Google G
    final paint = Paint()..style = PaintingStyle.fill;
    // Blue
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -1.57, 3.14, true, paint);
    // Red
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -1.57, -1.57, true, paint);
    // Yellow
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 1.57, 1.57, true, paint);
    // Green
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 0, 1.57, true, paint);
    // White center hole
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.60, paint);
    // Right cutout for the G bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.18, r, r * 0.36),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
