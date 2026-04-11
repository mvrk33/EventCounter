import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth_service.dart';
import '../../../core/sync_service.dart';

class RestoreDataScreen extends ConsumerStatefulWidget {
  const RestoreDataScreen({super.key});

  @override
  ConsumerState<RestoreDataScreen> createState() => _RestoreDataScreenState();
}

class _RestoreDataScreenState extends ConsumerState<RestoreDataScreen> {
  bool _isRestoring = false;
  late final Future<CloudBackupSummary> _backupSummaryFuture;

  @override
  void initState() {
    super.initState();
    _backupSummaryFuture = ref.read(syncServiceProvider).getCloudBackupSummary();
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
              FutureBuilder<CloudBackupSummary>(
                future: _backupSummaryFuture,
                builder: (BuildContext context, AsyncSnapshot<CloudBackupSummary> snapshot) {
                  final bool loading = snapshot.connectionState == ConnectionState.waiting;
                  final CloudBackupSummary summary = snapshot.data ??
                      const CloudBackupSummary(eventsCount: 0, habitsCount: 0);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: loading
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    summary.hasBackup
                                        ? '☁️ Cloud backup found'
                                        : '☁️ No cloud backup found',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${summary.eventsCount} events • ${summary.habitsCount} habits',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  if (!summary.hasBackup) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      'No backup data exists in cloud for this account yet.',
                                      style: Theme.of(context).textTheme.labelSmall,
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
                                final ScaffoldMessengerState messenger =
                                    ScaffoldMessenger.of(context);
                                setState(() {
                                  _isRestoring = true;
                                });
                                try {
                                  await sync.setAutoRestoreEnabled(true);
                                  if (!context.mounted) {
                                    return;
                                  }
                                  await sync.restoreAll(
                                    messenger: messenger,
                                  );
                                  if (context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isRestoring = false;
                                    });
                                  }
                                }
                              },
                        icon: _isRestoring
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
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
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final ScaffoldMessengerState messenger =
                      ScaffoldMessenger.of(context);
                  await sync.setAutoRestoreEnabled(false);
                  await sync.startFreshLocalData(
                    messenger: messenger,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(false);
                  }
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
