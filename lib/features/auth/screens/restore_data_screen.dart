import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth_service.dart';
import '../../../core/sync_service.dart';

class RestoreDataScreen extends ConsumerStatefulWidget {
  const RestoreDataScreen({super.key});

  @override
  ConsumerState<RestoreDataScreen> createState() => _RestoreDataScreenState();
}

class _RestoreDataScreenState extends ConsumerState<RestoreDataScreen> {
  bool _isRestoring = false;
  bool _decryptionFailed = false;
  late final Future<CloudBackupSummary> _backupSummaryFuture;

  @override
  void initState() {
    super.initState();
    _backupSummaryFuture = ref.read(syncServiceProvider).getCloudBackupSummary();
    // Check if user already completed restore screen - if so, skip to home
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final SyncService sync = ref.read(syncServiceProvider);
      final bool hasCompleted = await sync.hasCompletedRestoreScreen();

      if (hasCompleted && mounted) {
        // User already completed this screen, navigate to home
        if (context.mounted) {
          context.go('/home');
        }
      }
    });
  }

  void _finishFlow() {
    if (!mounted) return;
    // Mark restore screen as completed for this user (industry standard: show only once)
    final SyncService sync = ref.read(syncServiceProvider);
    sync.markRestoreScreenCompleted();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    final sync = ref.read(syncServiceProvider);
    final user = auth.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              CircleAvatar(
                radius: 48,
                backgroundImage: user?.photoURL != null && user!.photoURL!.isNotEmpty
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user?.photoURL == null || user!.photoURL!.isEmpty
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                user?.displayName ?? 'Welcome',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Decryption failure banner ──────────────────────────────
              if (_decryptionFailed) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              color: Colors.red.shade300, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cannot decrypt backup',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red.shade300,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your cloud backup was encrypted with a key that only existed on '
                        'the previous install. After reinstalling, that key is gone and '
                        'those events cannot be recovered from cloud.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade200,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Going forward, your new data will sync normally. '
                        'To protect future backups across reinstalls, export as CSV '
                        'or use "Export as JSON" (now saved as plain JSON).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade100.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _finishFlow,
                  child: const Text('Start fresh (data already gone)'),
                ),
              ] else ...[
                // ── Normal backup summary + restore ────────────────────
                FutureBuilder<CloudBackupSummary>(
                  future: _backupSummaryFuture,
                  builder: (BuildContext context,
                      AsyncSnapshot<CloudBackupSummary> snapshot) {
                    final bool loading =
                        snapshot.connectionState == ConnectionState.waiting;
                    final CloudBackupSummary summary = snapshot.data ??
                        const CloudBackupSummary(eventsCount: 0, habitsCount: 0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: loading
                              ? const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      summary.hasBackup
                                          ? '☁️ Cloud backup found'
                                          : '☁️ No cloud backup found',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${summary.eventsCount} events • ${summary.habitsCount} habits',
                                      style:
                                          Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    if (!summary.hasBackup) ...<Widget>[
                                      const SizedBox(height: 4),
                                      Text(
                                        'No backup data exists in cloud for this account yet.',
                                        style:
                                            Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _isRestoring || loading || !summary.hasBackup
                              ? null
                              : () async {
                                  setState(() => _isRestoring = true);
                                  try {
                                    await sync.setAutoRestoreEnabled(true);
                                    if (!context.mounted) return;
                                    final RestoreResult result =
                                        await sync.restoreAll(
                                      messenger:
                                          ScaffoldMessenger.of(context),
                                    );
                                    if (result.isDecryptionFailure) {
                                      if (mounted) {
                                        setState(
                                            () => _decryptionFailed = true);
                                      }
                                    } else {
                                      _finishFlow();
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isRestoring = false);
                                    }
                                  }
                                },
                          icon: _isRestoring
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_download_outlined),
                          label: Text(
                            _isRestoring
                                ? 'Restoring...'
                                : summary.hasBackup
                                    ? 'Restore backup'
                                    : 'No backup to restore',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              if (!_decryptionFailed)
                OutlinedButton(
                  onPressed: _isRestoring
                      ? null
                      : () async {
                          await sync.setAutoRestoreEnabled(false);
                          await sync.startFreshLocalData(
                            messenger: ScaffoldMessenger.of(context),
                          );
                          _finishFlow();
                        },
                  child: const Text('Start fresh'),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
