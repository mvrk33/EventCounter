import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth_service.dart';
import '../../../core/pin_security_service.dart';
import '../../../core/sync_service.dart';
import '../../events/providers/events_provider.dart';
import '../../events/services/export_service.dart';
import 'account_screen.dart';

final StateProvider<ThemeMode> themeModeProvider =
    StateProvider<ThemeMode>((Ref ref) {
  return ThemeMode.system;
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ExportService _exportService = const ExportService();
  int _developerTapCount = 0;
  Timer? _developerTapReset;

  static final Uri _githubUri = Uri.parse('https://github.com/mvrk33');

  @override
  void dispose() {
    _developerTapReset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final AsyncValue<User?> authState = ref.watch(authStateChangesProvider);
    final SyncService syncService = ref.read(syncServiceProvider);
    final events = ref.watch(eventsProvider);
    final PinSecurityService pinSecurity = ref.read(pinSecurityServiceProvider);
    final bool localEncryptionEnabled =
        pinSecurity.isLocalBackupEncryptionEnabled;
    final bool cloudEncryptionEnabled =
        pinSecurity.isCloudBackupEncryptionEnabled;
    final scheme = Theme.of(context).colorScheme;
    final user = authState.value;
    final bool isSignedIn = user != null;

    return CustomScrollView(
      slivers: <Widget>[
        // ── Header ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text('Settings ⚙️',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── Profile card ───────────────────────────────────────
                _SettingsGroup(
                  children: <Widget>[
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const AccountScreen()),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: scheme.primaryContainer,
                              backgroundImage: user?.photoURL != null &&
                                      user!.photoURL!.isNotEmpty
                                  ? NetworkImage(user.photoURL!)
                                  : null,
                              child: user?.photoURL == null ||
                                      user!.photoURL!.isEmpty
                                  ? Text(
                                      user?.displayName?.isNotEmpty == true
                                          ? user!.displayName![0].toUpperCase()
                                          : '👤',
                                      style: TextStyle(
                                        fontSize:
                                            user?.displayName?.isNotEmpty ==
                                                    true
                                                ? 22
                                                : 24,
                                        color: scheme.onPrimaryContainer,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    user?.displayName ?? 'Guest',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(
                                    isSignedIn
                                        ? user.email ?? 'Signed in'
                                        : 'Not signed in — data is local',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.68),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color:
                                    scheme.onSurface.withValues(alpha: 0.35)),
                          ],
                        ),
                      ),
                    ),
                    _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.sync_rounded,
                      iconColor: const Color(0xFF43A047),
                      title: 'Sync now',
                      subtitle: syncService.lastSyncedAt != null
                          ? 'Last: ${_formatDate(syncService.lastSyncedAt!)}'
                          : 'Never synced',
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          await syncService.syncAll(
                              messenger: ScaffoldMessenger.of(context));
                        },
                        child: const Text('Sync'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // ...existing code...
                _SectionHeader(label: 'APPEARANCE'),
                const SizedBox(height: 8),
                _SettingsGroup(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: <Widget>[
                          _IconBox(
                            icon: Icons.palette_rounded,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Theme',
                                style: Theme.of(context).textTheme.titleSmall),
                          ),
                          const SizedBox(width: 8),
                          SegmentedButton<ThemeMode>(
                            selected: <ThemeMode>{mode},
                            onSelectionChanged: (Set<ThemeMode> value) {
                              ref.read(themeModeProvider.notifier).state =
                                  value.first;
                            },
                            segments: const <ButtonSegment<ThemeMode>>[
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_rounded, size: 16),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto_rounded,
                                    size: 16),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_rounded, size: 16),
                              ),
                            ],
                            style: SegmentedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionHeader(label: 'DATA'),
                const SizedBox(height: 8),
                _SettingsGroup(
                  children: <Widget>[
                    _SettingsRow(
                      icon: Icons.upload_file_rounded,
                      iconColor: const Color(0xFF1E88E5),
                      title: 'Export as JSON',
                      subtitle: '${events.length} events',
                      trailing: OutlinedButton(
                        onPressed: events.isEmpty
                            ? null
                            : () async {
                                final file =
                                    await _exportService.exportEventsJson(
                                  events,
                                  security: pinSecurity,
                                );
                                await Share.shareXFiles(
                                    <XFile>[XFile(file.path)]);
                              },
                        child: const Text('Export'),
                      ),
                    ),
                    _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.table_chart_rounded,
                      iconColor: const Color(0xFF00897B),
                      title: 'Export as CSV',
                      subtitle: 'Spreadsheet-compatible',
                      trailing: OutlinedButton(
                        onPressed: events.isEmpty
                            ? null
                            : () async {
                                final file = await _exportService
                                    .exportEventsCsv(events);
                                await Share.shareXFiles(
                                    <XFile>[XFile(file.path)]);
                              },
                        child: const Text('Export'),
                      ),
                    ),
                    _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.download_rounded,
                      iconColor: const Color(0xFFE53935),
                      title: 'Import from JSON',
                      subtitle: 'Restore a backup file',
                      trailing: OutlinedButton(
                        onPressed: () async {
                          final imported = await _exportService
                              .importEventsJsonFromDefaultFile(
                            security: pinSecurity,
                          );
                          if (imported.isEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('No import file found.')),
                              );
                            }
                            return;
                          }
                          await ref
                              .read(eventsProvider.notifier)
                              .importEvents(imported);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Imported ${imported.length} events.')),
                            );
                          }
                        },
                        child: const Text('Import'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionHeader(label: 'SECURITY'),
                const SizedBox(height: 8),
                _SettingsGroup(
                  children: <Widget>[
                    _SettingsRow(
                      icon: Icons.lock_rounded,
                      iconColor: const Color(0xFF5E35B1),
                      title: 'Encrypt local backup file',
                      subtitle:
                          'Protects exported JSON backup in app documents',
                      trailing: Switch(
                        value: localEncryptionEnabled,
                        onChanged: (bool value) =>
                            _setLocalBackupEncryption(value),
                      ),
                    ),
                    _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.storage_rounded,
                      iconColor: const Color(0xFF00897B),
                      title: 'Encrypt cloud backup sync',
                      subtitle:
                          'Encrypts event/habit payloads before upload to cloud',
                      trailing: Switch(
                        value: cloudEncryptionEnabled,
                        onChanged: (bool value) =>
                            _setCloudBackupEncryption(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionHeader(label: 'ABOUT'),
                const SizedBox(height: 8),
                _SettingsGroup(
                  children: <Widget>[
                    _SettingsRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: scheme.primary,
                      title: 'Version',
                      subtitle: 'Event Counter v1.0.0',
                    ),
                    _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.balance_rounded,
                      iconColor: const Color(0xFF8E24AA),
                      title: 'License',
                      subtitle: 'MIT License',
                    ),
                    _SettingsDivider(),
                    InkWell(
                      onTap: _openGithub,
                      child: _SettingsRow(
                        icon: Icons.code_rounded,
                        iconColor: const Color(0xFF37474F),
                        title: 'Open source',
                        subtitle: 'View on GitHub',
                        trailing: Icon(Icons.open_in_new_rounded,
                            size: 16,
                            color: scheme.onSurface.withValues(alpha: 0.4)),
                      ),
                    ),
                    _SettingsDivider(),
                    InkWell(
                      onTap: _handleDeveloperTap,
                      onLongPress: _openGithub,
                      child: _SettingsRow(
                        icon: Icons.person_rounded,
                        iconColor: const Color(0xFF6D4C41),
                        title: 'Developer',
                        subtitle: 'venkata rajesh murala',
                        trailing: Icon(Icons.celebration_rounded,
                            size: 16,
                            color: scheme.onSurface.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openGithub() async {
    final bool launched = await launchUrl(
      _githubUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open GitHub link right now.')),
      );
    }
  }

  void _handleDeveloperTap() {
    _developerTapReset?.cancel();
    _developerTapReset = Timer(const Duration(seconds: 5), () {
      _developerTapCount = 0;
    });
    _developerTapCount += 1;

    if (_developerTapCount == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Easter egg: You found the hidden streak spark!')),
      );
      return;
    }
    if (_developerTapCount >= 6) {
      _developerTapCount = 0;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Secret unlocked'),
          content: const Text(
              'Event Counter dev mode says: Keep shipping tiny wins daily.'),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nice'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _setLocalBackupEncryption(bool enabled) async {
    final PinSecurityService pinSecurity = ref.read(pinSecurityServiceProvider);
    await pinSecurity.setLocalBackupEncryptionEnabled(enabled);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(enabled
                ? 'Local backup encryption enabled.'
                : 'Local backup encryption disabled.')),
      );
    }
  }

  Future<void> _setCloudBackupEncryption(bool enabled) async {
    final PinSecurityService pinSecurity = ref.read(pinSecurityServiceProvider);
    await pinSecurity.setCloudBackupEncryptionEnabled(enabled);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(enabled
                ? 'Cloud backup encryption enabled.'
                : 'Cloud backup encryption disabled.')),
      );
    }
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.30),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      indent: 56,
      endIndent: 0,
      height: 1,
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          _IconBox(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.68),
                        ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
