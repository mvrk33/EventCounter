import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Full-screen lock overlay shown when app lock is enabled.
/// Calls [onUnlocked] when the user successfully authenticates.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({required this.onUnlocked, super.key});

  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Automatically prompt on load.
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final bool canCheck = await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
      if (!canCheck) {
        setState(() {
          _errorMessage =
              'Your device does not support biometric or device authentication.';
          _isAuthenticating = false;
        });
        return;
      }

      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to open Daymark',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      if (authenticated) {
        widget.onUnlocked();
      } else {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Authentication error: $e';
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: scheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Daymark is locked',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use your fingerprint, face ID, or device PIN to unlock.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.68),
                      ),
                ),
                const SizedBox(height: 32),
                if (_isAuthenticating)
                  const CircularProgressIndicator()
                else ...<Widget>[
                  if (_errorMessage != null) ...<Widget>[
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Unlock'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

