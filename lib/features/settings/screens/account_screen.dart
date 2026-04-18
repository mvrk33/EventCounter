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
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.photoURL == null || user.photoURL!.isEmpty
                    ? null
                    : NetworkImage(user.photoURL!),
                child: user.photoURL == null || user.photoURL!.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(
                user.displayName ?? 'No name',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              subtitle: Text(
                user.email ?? 'No email',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.68),
                    ),
              ),
            )
          else
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(
                'Guest Mode',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              subtitle: Text(
                'Sign in to enable cloud backup and restore.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.68),
                    ),
              ),
            ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(
              'Last synced',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            subtitle: Text(
              sync.lastSyncedAt?.toLocal().toString() ?? 'Never',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
            ),
          ),
          ListTile(
            title: Text(
              'Storage usage estimate',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            subtitle: Text(
              _estimateStorage(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              await sync.syncAll(messenger: ScaffoldMessenger.of(context));
            },
            child: const Text('Sync Now'),
          ),
          if (user != null) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmClearCloudBackup(context, sync),
              icon: const Icon(Icons.cloud_off_outlined),
              label: const Text('Clear cloud backup'),
            ),
          ],
          const SizedBox(height: 8),
           if (user != null)
             OutlinedButton(
               onPressed: () async {
                 await auth.signOut();
                 ref.read(guestModeProvider.notifier).state = false;
                 // Don't use Navigator.pop() after async auth state change
                 // The auth state change will automatically trigger navigation via GoRouter
                 // Just ensure we're not navigating during a locked state
                 if (context.mounted) {
                   // Let the auth state listener handle navigation
                   // The router will redirect from /settings to /login automatically
                 }
               },
               child: const Text('Sign Out'),
             ),
          if (user == null) ...<Widget>[
            FilledButton.icon(
              onPressed: () => _showEmailAuthDialog(
                context: context,
                auth: auth,
                sync: sync,
                createAccount: false,
              ),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Sign in with Email & backup local data'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showEmailAuthDialog(
                context: context,
                auth: auth,
                sync: sync,
                createAccount: true,
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create Email Account'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showResetPasswordDialog(context: context, auth: auth),
              child: const Text('Forgot password?'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _signInAndSync(
                context: context,
                auth: auth,
                sync: sync,
                useGoogle: true,
              ),
              icon: const Icon(Icons.g_mobiledata_rounded),
              label: const Text('Sign in with Google & backup local data'),
            ),
            if (supportsAppleSignIn) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _signInAndSync(
                  context: context,
                  auth: auth,
                  sync: sync,
                  useGoogle: false,
                ),
                icon: const Icon(Icons.apple_rounded),
                label: const Text('Sign in with Apple & backup local data'),
              ),
            ],
          ],
          if (user != null)
            TextButton(
              onPressed: () => _confirmDelete(context, auth),
              child: const Text('Delete Account'),
            ),
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
        // Typed boxes (e.g. Box<EventModel>) throw when accessed as Box<dynamic>
        // in some Hive 2.x versions — catch and skip gracefully.
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

      // Upload existing guest-mode local data to cloud immediately.
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

  Future<void> _showResetPasswordDialog({
    required BuildContext context,
    required AuthService auth,
  }) async {
    final TextEditingController emailController = TextEditingController();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (submit != true) {
      emailController.dispose();
      return;
    }

    final String email = emailController.text.trim();
    emailController.dispose();
    if (email.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter an email address.')),
      );
      return;
    }

    try {
      await auth.sendPasswordResetEmail(email);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Reset failed: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Reset failed: $e')),
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
      // Account deletion also signs out, let GoRouter handle navigation
      // Don't use Navigator.pop() after async state change
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
