import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/auth_service.dart';
import '../../../core/hive_boxes.dart';
import '../../../core/sync_service.dart';
import '../../../app/router.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final AsyncValue<User?> authState = ref.watch(authStateChangesProvider);
    final sync = ref.read(syncServiceProvider);
    final user = authState.value;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool supportsAppleSignIn =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Details'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: <Widget>[
          // ── Profile Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.6),
                  scheme.primaryContainer.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: scheme.surface,
                        backgroundImage: user?.photoURL == null || user!.photoURL!.isEmpty
                            ? null
                            : NetworkImage(user.photoURL!),
                        child: user?.photoURL == null || user!.photoURL!.isEmpty
                            ? Icon(Icons.person, size: 40, color: scheme.primary)
                            : null,
                      ),
                    ),
                    if (user != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.surface, width: 2),
                          ),
                          child: const Icon(Icons.check, size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? 'Guest Mode',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                ),
                Text(
                  user?.email ?? 'Cloud sync is disabled',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const _SectionHeader(label: 'CLOUD STORAGE'),
          const SizedBox(height: 12),
          _AccountGroup(
            children: [
              _AccountRow(
                icon: Icons.history_rounded,
                title: 'Last Synced',
                subtitle: sync.lastSyncedAt?.toLocal().toString().split('.').first ?? 'Never',
              ),
              _AccountDivider(),
              _AccountRow(
                icon: Icons.data_usage_rounded,
                title: 'Storage Usage',
                subtitle: _estimateStorage(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (user != null) ...[
            const _SectionHeader(label: 'ACTIONS'),
            const SizedBox(height: 12),
            _AccountGroup(
              children: [
                _ActionTile(
                  icon: Icons.sync_rounded,
                  label: 'Force Cloud Sync',
                  onTap: () => sync.syncAll(messenger: ScaffoldMessenger.of(context)),
                  isPrimary: true,
                ),
                _AccountDivider(),
                _ActionTile(
                  icon: Icons.cloud_off_outlined,
                  label: 'Clear Cloud Backup',
                  onTap: () => _confirmClearCloudBackup(context, sync),
                ),
                _AccountDivider(),
                _ActionTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  onTap: () async {
                    await auth.signOut();
                    ref.read(guestModeProvider.notifier).state = false;
                  },
                  textColor: scheme.error,
                ),
              ],
            ),
          ] else ...[
            const _SectionHeader(label: 'GET STARTED'),
            const SizedBox(height: 12),
            _AccountGroup(
              children: [
                _ActionTile(
                  icon: Icons.g_mobiledata_rounded,
                  label: 'Sign in with Google',
                  onTap: () => _signInAndSync(
                    context: context,
                    auth: auth,
                    sync: sync,
                    useGoogle: true,
                  ),
                  isPrimary: true,
                ),
                if (supportsAppleSignIn) ...[
                  _AccountDivider(),
                  _ActionTile(
                    icon: Icons.apple_rounded,
                    label: 'Sign in with Apple',
                    onTap: () => _signInAndSync(
                      context: context,
                      auth: auth,
                      sync: sync,
                      useGoogle: false,
                    ),
                  ),
                ],
                _AccountDivider(),
                _ActionTile(
                  icon: Icons.email_outlined,
                  label: 'Sign in with Email',
                  onTap: () => _showEmailAuthDialog(
                    context: context,
                    auth: auth,
                    sync: sync,
                    createAccount: false,
                  ),
                ),
                _AccountDivider(),
                _ActionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Create Account',
                  onTap: () => _showEmailAuthDialog(
                    context: context,
                    auth: auth,
                    sync: sync,
                    createAccount: true,
                  ),
                ),
              ],
            ),
          ],
          
          if (user != null) ...[
            const SizedBox(height: 40),
            Center(
              child: TextButton.icon(
                onPressed: () => _confirmDelete(context, auth),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete Account Permanently'),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
              ),
            ),
          ],
          const SizedBox(height: 24),
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
      return '${kb.toStringAsFixed(1)} KB (estimated)';
    }
    return '${(kb / 1024).toStringAsFixed(2)} MB (estimated)';
  }

  Future<void> _signInAndSync({
    required BuildContext context,
    required AuthService auth,
    required SyncService sync,
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

      await sync.syncAll(messenger: messenger);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Signed in and backed up local data to cloud.')),
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
    required SyncService sync,
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

      await sync.syncAll(messenger: messenger);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              createAccount
                  ? 'Account created and local data backed up.'
                  : 'Signed in and local data backed up.',
            ),
          ),
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

// ── Helper Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: textColor ?? (isPrimary ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
                color: textColor ?? (isPrimary ? scheme.primary : scheme.onSurface),
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _AccountDivider extends StatelessWidget {
  const _AccountDivider({super.key});
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 54,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}
