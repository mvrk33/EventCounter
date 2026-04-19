import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/auth_service.dart';
import '../../../core/hive_boxes.dart';
import '../../../core/sync_service.dart';
import '../../../app/router.dart';
import '../../auth/screens/restore_data_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final AsyncValue<User?> authState = ref.watch(authStateChangesProvider);
    final sync = ref.read(syncServiceProvider);
    final user = authState.value;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool supportsAppleSignIn =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: <Widget>[
          // ── Profile Section ────────────────────────────────────────────────
          if (user != null)
            _ProfileCard(
              user: user,
              scheme: scheme,
              isDark: isDark,
            )
          else
            _GuestCard(scheme: scheme, isDark: isDark),
          const SizedBox(height: 28),

          // ── Cloud Storage Info ─────────────────────────────────────────────
          _SectionLabel(label: 'CLOUD STORAGE', scheme: scheme),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.history_rounded,
            label: 'Last Synced',
            value: sync.lastSyncedAt?.toLocal().toString().split('.').first ?? 'Never',
            scheme: scheme,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            icon: Icons.data_usage_rounded,
            label: 'Storage Usage',
            value: _estimateStorage(),
            scheme: scheme,
            isDark: isDark,
          ),
          const SizedBox(height: 28),

          // ── Actions Section ────────────────────────────────────────────────
          if (user != null) ...[
            _SectionLabel(label: 'ACTIONS', scheme: scheme),
            const SizedBox(height: 12),
            _SyncButton(
              scheme: scheme,
              isDark: isDark,
              sync: sync,
            ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: Icons.cloud_off_outlined,
              label: 'Clear Cloud Backup',
              onTap: () => _confirmClearCloudBackup(context, sync),
              scheme: scheme,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              onTap: () async {
                await auth.signOut();
                ref.read(guestModeProvider.notifier).state = false;
              },
              scheme: scheme,
              isDark: isDark,
              isDestructive: false,
            ),
            const SizedBox(height: 28),
          ] else ...[
            // ── Sign In Options ─────────────────────────────────────────────
            _SectionLabel(label: 'GET STARTED', scheme: scheme),
            const SizedBox(height: 12),
            _PrimaryActionButton(
              icon: Icons.g_mobiledata_rounded,
              label: 'Sign in with Google',
              onTap: () => _signInAndSync(
                context: context,
                auth: auth,
                useGoogle: true,
              ),
              scheme: scheme,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            if (supportsAppleSignIn) ...[
              _ActionButton(
                icon: Icons.apple_rounded,
                label: 'Sign in with Apple',
                onTap: () => _signInAndSync(
                  context: context,
                  auth: auth,
                  useGoogle: false,
                ),
                scheme: scheme,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
            ],
            _ActionButton(
              icon: Icons.email_outlined,
              label: 'Sign in with Email',
              onTap: () => _showEmailAuthDialog(
                context: context,
                auth: auth,
                createAccount: false,
              ),
              scheme: scheme,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Create Account',
              onTap: () => _showEmailAuthDialog(
                context: context,
                auth: auth,
                createAccount: true,
              ),
              scheme: scheme,
              isDark: isDark,
            ),
            const SizedBox(height: 28),
          ],

          // ── Danger Zone ─────────────────────────────────────────────────────
          if (user != null) ...[
            _SectionLabel(label: 'DANGER ZONE', scheme: scheme),
            const SizedBox(height: 12),
            _ActionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete Account Permanently',
              onTap: () => _confirmDelete(context, auth),
              scheme: scheme,
              isDark: isDark,
              isDestructive: true,
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );

  }

  String _estimateStorage() {
    int bytes = 0;
    const List<String> knownBoxes = <String>[
      HiveBoxes.events,
      HiveBoxes.habits,
      HiveBoxes.settings,
      HiveBoxes.categories,
      HiveBoxes.syncMeta,
    ];
    for (final String boxName in knownBoxes) {
      if (!Hive.isBoxOpen(boxName)) {
        continue;
      }
      try {
        bytes += Hive.box<dynamic>(boxName).length * 512;
      } catch (_) {
        // ignore
      }
    }
    final double kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  Future<void> _signInAndSync({
    required BuildContext context,
    required AuthService auth,
    required bool useGoogle,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final UserCredential? userCredential = useGoogle
          ? await auth.signInWithGoogle()
          : await auth.signInWithApple();

      if (userCredential == null) {
        if (context.mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Sign-in cancelled.')),
          );
        }
        return;
      }

      if (context.mounted) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(builder: (_) => const RestoreDataScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    }
  }

  Future<void> _showEmailAuthDialog({
    required BuildContext context,
    required AuthService auth,
    required bool createAccount,
  }) async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(createAccount ? 'Create account' : 'Sign in with email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (createAccount)
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Name (optional)'),
                ),
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
              child: Text(createAccount ? 'Create' : 'Sign in'),
            ),
          ],
        );
      },
    );

    if (submit != true) {
      emailController.dispose();
      passwordController.dispose();
      nameController.dispose();
      return;
    }

    final String email = emailController.text.trim();
    final String password = passwordController.text;
    final String name = nameController.text.trim();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();

    if (email.isEmpty || password.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Email and password are required.')),
      );
      return;
    }

    try {
      if (createAccount) {
        await auth.createAccountWithEmailPassword(
          email: email,
          password: password,
          displayName: name.isEmpty ? null : name,
        );
      } else {
        await auth.signInWithEmailPassword(email: email, password: password);
      }

      if (context.mounted) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(builder: (_) => const RestoreDataScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Auth failed: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Auth failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, AuthService auth) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text('This will remove cloud profile, events, habits, and your auth account.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await auth.deleteAccount();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearCloudBackup(
    BuildContext context,
    SyncService sync,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear cloud backup?'),
          content: const Text(
            'This deletes cloud events and habits only. '
            'Your account and local data stay untouched.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear cloud data'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }
    await sync.clearCloudBackup(messenger: ScaffoldMessenger.of(context));
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────

/// Profile card for authenticated users
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.scheme,
    required this.isDark,
  });

  final User user;
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surface.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.1 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        backgroundBlendMode: BlendMode.overlay,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: scheme.primary,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: user.photoURL == null || user.photoURL!.isEmpty
                  ? null
                  : NetworkImage(user.photoURL!),
              child: user.photoURL == null || user.photoURL!.isEmpty
                  ? Icon(Icons.person, size: 40, color: scheme.primary)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'Account User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? 'No email',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Verified',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Guest mode card for unauthenticated users
class _GuestCard extends StatelessWidget {
  const _GuestCard({
    required this.scheme,
    required this.isDark,
  });

  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surface.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.2)
              : scheme.outline.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.secondary.withValues(alpha: isDark ? 0.08 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_outline, size: 28, color: scheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sign in to sync your data across devices',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section label for grouping content
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.scheme,
  });

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Information card showing storage and sync info
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surface.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? scheme.outline.withValues(alpha: 0.15)
              : scheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.05 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary action button (usually for important actions)
class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scheme,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final bool isDark;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: widget.scheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: widget.scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: widget.scheme.primary.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 22, color: widget.scheme.onPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: widget.scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 20, color: widget.scheme.onPrimary),
          ],
        ),
      ),
    );
  }
}

/// Secondary action button
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scheme,
    required this.isDark,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final bool isDark;
  final bool isDestructive;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color fgColor = widget.isDestructive
        ? widget.scheme.error
        : widget.scheme.onSurface;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: widget.isDark
              ? widget.scheme.surface.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isDestructive
                ? widget.scheme.error.withValues(alpha: 0.2)
                : widget.scheme.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: (widget.isDestructive ? widget.scheme.error : widget.scheme.primary)
                        .withValues(alpha: widget.isDark ? 0.04 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 22, color: fgColor),
            const SizedBox(width: 14),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_rounded, size: 20, color: fgColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

/// Sync button with progress bar and animated sync logo
class _SyncButton extends StatefulWidget {
  const _SyncButton({
    required this.scheme,
    required this.isDark,
    required this.sync,
  });

  final ColorScheme scheme;
  final bool isDark;
  final SyncService sync;

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _startSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    _rotationController.repeat();

    try {
      // Sync without messenger to disable snackbar notifications
      await widget.sync.syncAll(messenger: null);
    } finally {
      if (mounted) {
        _rotationController.stop();
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isSyncing ? null : _startSync,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: widget.isDark
              ? widget.scheme.surface.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSyncing
                ? widget.scheme.primary
                : widget.scheme.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.scheme.primary
                  .withValues(alpha: widget.isDark ? 0.04 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Animated sync icon
                RotationTransition(
                  turns: _rotationController,
                  child: Icon(
                    Icons.sync_rounded,
                    size: 22,
                    color: _isSyncing
                        ? widget.scheme.primary
                        : widget.scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _isSyncing ? 'Syncing...' : 'Force Cloud Sync',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _isSyncing
                              ? widget.scheme.primary
                              : widget.scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: widget.scheme.onSurface
                      .withValues(alpha: _isSyncing ? 0.3 : 0.5),
                ),
              ],
            ),
            // Progress bar
            if (_isSyncing) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor:
                      widget.scheme.primary.withValues(alpha: 0.1),
                  color: widget.scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
