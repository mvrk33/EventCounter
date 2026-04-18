import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth_service.dart';
import '../../../core/pin_security_service.dart';
import '../../../core/sync_service.dart';
import '../../events/providers/events_provider.dart';
import '../../events/services/export_service.dart';
import 'account_screen.dart';

typedef ShareFilesCallback = Future<void> Function(List<XFile> files);

final StateProvider<ThemeMode> themeModeProvider =
    StateProvider<ThemeMode>((Ref ref) {
  return ThemeMode.system;
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    this.exportService,
    this.shareFiles,
    super.key,
  });

  final ExportService? exportService;
  final ShareFilesCallback? shareFiles;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final ExportService _exportService;
  late final ShareFilesCallback _shareFiles;
  int _developerTapCount = 0;
  Timer? _developerTapReset;

  static final Uri _githubUri = Uri.parse('https://github.com/mvrk33');

  @override
  void initState() {
    super.initState();
    _exportService = widget.exportService ?? const ExportService();
    _shareFiles = widget.shareFiles ?? Share.shareXFiles;
  }

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
    final scheme = Theme.of(context).colorScheme;
    final user = authState.value;
    final bool isSignedIn = user != null;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                          ),
                          Text(
                            'Preferences & account management',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.settings_outlined, color: scheme.primary, size: 24),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // ── Profile card ───────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.primary.withValues(alpha: 0.1),
                            scheme.primary.withValues(alpha: 0.02),
                          ],
                        ),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                                ),
                                child: CircleAvatar(
                                  radius: 30,
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
                                            fontSize: user?.displayName?.isNotEmpty == true ? 24 : 26,
                                            fontWeight: FontWeight.bold,
                                            color: scheme.onPrimaryContainer,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      user?.displayName ?? 'Guest User',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: scheme.onSurface,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isSignedIn ? user.email ?? 'Signed in' : 'Local only — tap to sign in',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: scheme.onSurface.withValues(alpha: 0.5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 16, color: scheme.onSurface.withValues(alpha: 0.3)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    const _SectionHeader(label: 'CLOUD SYNC'),
                    const SizedBox(height: 12),
                    _SettingsGroup(
                      children: <Widget>[
                        _SettingsRow(
                          icon: Icons.sync_rounded,
                          iconColor: const Color(0xFF43A047),
                          title: 'Cloud Synchronization',
                          subtitle: syncService.lastSyncedAt != null
                              ? 'Last: ${_formatDate(syncService.lastSyncedAt!)}'
                              : 'Keep your data backed up and in sync',
                          trailing: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: !isSignedIn
                                ? null
                                : () async {
                                    await syncService.synchronize(messenger: ScaffoldMessenger.of(context));
                                  },
                            child: const Text('Sync Now'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
    
                    const _SectionHeader(label: 'APPEARANCE'),
                    const SizedBox(height: 12),
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
                                child: Text(
                                  'Theme Mode',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              SegmentedButton<ThemeMode>(
                                selected: <ThemeMode>{mode},
                                onSelectionChanged: (Set<ThemeMode> value) {
                                  ref.read(themeModeProvider.notifier).state = value.first;
                                },
                                segments: const <ButtonSegment<ThemeMode>>[
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.light,
                                    icon: Icon(Icons.light_mode_rounded, size: 16),
                                  ),
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.system,
                                    icon: Icon(Icons.brightness_auto_rounded, size: 16),
                                  ),
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.dark,
                                    icon: Icon(Icons.dark_mode_rounded, size: 16),
                                  ),
                                ],
                                showSelectedIcon: false,
                                style: SegmentedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
    
                    const _SectionHeader(label: 'DATA MANAGEMENT'),
                    const SizedBox(height: 12),
                    _SettingsGroup(
                      children: <Widget>[
                        _SettingsRow(
                          icon: Icons.upload_file_rounded,
                          iconColor: const Color(0xFF1E88E5),
                          title: 'Export as JSON',
                          subtitle: '${events.length} events found',
                          trailing: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: events.isEmpty
                                ? null
                                : () async {
                                    final file = await _exportService.exportEventsJson(
                                      events,
                                      security: pinSecurity,
                                    );
                                    if (!mounted) return;
                                    _showExportOptions(context, file);
                                  },
                            child: const Text('Export'),
                          ),
                        ),
                        _SettingsDivider(),
                        _SettingsRow(
                          icon: Icons.table_chart_rounded,
                          iconColor: const Color(0xFF00897B),
                          title: 'Export as CSV',
                          subtitle: 'For spreadsheets',
                          trailing: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: events.isEmpty
                                ? null
                                : () async {
                                    final file = await _exportService.exportEventsCsv(events);
                                    if (!mounted) return;
                                    _showExportOptions(context, file);
                                  },
                            child: const Text('Export'),
                          ),
                        ),
                        _SettingsDivider(),
                        _SettingsRow(
                          icon: Icons.download_rounded,
                          iconColor: const Color(0xFFE53935),
                          title: 'Import backup',
                          subtitle: 'JSON or CSV files',
                          trailing: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
                              final imported = await _exportService.importEventsJsonFromPicker(
                                security: pinSecurity,
                              );
                              if (imported.isEmpty) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'No backup selected or unsupported format.')),
                                );
                                return;
                              }
                              await ref.read(eventsProvider.notifier).importEvents(imported);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text('Imported ${imported.length} events.')),
                              );
                            },
                            child: const Text('Import'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
    
                    const _SectionHeader(label: 'SECURITY'),
                    const SizedBox(height: 12),
                    _SettingsGroup(
                      children: <Widget>[
                        _SettingsRow(
                          icon: Icons.lock_rounded,
                          iconColor: const Color(0xFF5E35B1),
                          title: 'Data Encryption',
                          subtitle: 'AES-256 always active',
                          trailing: Icon(Icons.verified_user_rounded,
                              color: Colors.green.withValues(alpha: 0.8), size: 20),
                        ),
                        _SettingsDivider(),
                        _SettingsRow(
                          icon: Icons.fingerprint_rounded,
                          iconColor: const Color(0xFF1565C0),
                          title: 'Biometric Lock',
                          subtitle: 'Protect access to your logs',
                          trailing: Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: pinSecurity.isAppLockEnabled,
                              onChanged: (bool value) => _setAppLock(value),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
    
                    const _SectionHeader(label: 'ABOUT'),
                    const SizedBox(height: 12),
                    _SettingsGroup(
                      children: <Widget>[
                        _SettingsRow(
                          icon: Icons.info_outline_rounded,
                          iconColor: scheme.primary,
                          title: 'Version',
                          subtitle: 'DayMark v1.1.0-gold',
                        ),
                        _SettingsDivider(),
                        InkWell(
                          onTap: _openGithub,
                          child: _SettingsRow(
                            icon: Icons.code_rounded,
                            iconColor: const Color(0xFF37474F),
                            title: 'Open Source',
                            subtitle: 'View on GitHub',
                            trailing: Icon(Icons.arrow_outward_rounded,
                                size: 14, color: scheme.onSurface.withValues(alpha: 0.3)),
                          ),
                        ),
                        _SettingsDivider(),
                        InkWell(
                          onTap: _handleDeveloperTap,
                          onLongPress: _openGithub,
                          child: _SettingsRow(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: Colors.amber,
                            title: 'Developer',
                            subtitle: 'Venkata Rajesh Murala',
                            trailing: Icon(Icons.favorite_rounded,
                                size: 14, color: Colors.red.withValues(alpha: 0.4)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _setAppLock(bool enabled) async {
    final PinSecurityService pinSecurity = ref.read(pinSecurityServiceProvider);
    final LocalAuthentication localAuth = LocalAuthentication();

    if (enabled) {
      // Verify device supports auth before enabling.
      final bool canAuth = await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();
      if (!canAuth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Your device does not support biometric/PIN authentication.')),
          );
        }
        return;
      }
      // Confirm identity once before enabling.
      final bool confirmed = await localAuth.authenticate(
        localizedReason: 'Confirm your identity to enable app lock',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!confirmed) return;
    }

    await pinSecurity.setAppLockEnabled(enabled);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(enabled ? 'App lock enabled.' : 'App lock disabled.')),
      );
    }
  }

  Future<void> _showExportOptions(BuildContext context, File file) async {
    if (!mounted) return;
    final filename = file.path.split('/').last;
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Export: $filename',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              subtitle: const Text('Send via email, messaging, etc.'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _shareFiles(<XFile>[XFile(file.path)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_rounded),
              title: const Text('Save to device'),
              subtitle: const Text('Choose where to save this backup file'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _saveToDevice(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy file path'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () {
                Navigator.of(ctx).pop();
                _copyToClipboard(file.path);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToDevice(File sourceFile) async {
    try {
      final String filename = sourceFile.path.split('/').last;
      final Uint8List bytes = await sourceFile.readAsBytes();

      if (Platform.isAndroid || Platform.isIOS) {
        final String? saved = await FilePicker.platform.saveFile(
          dialogTitle: 'Save backup file',
          fileName: filename,
          bytes: bytes,
        );
        if (saved == null || saved.isEmpty) {
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved backup: $filename')),
          );
        }
        return;
      }

      final String? destinationPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup file',
        fileName: filename,
      );

      if (destinationPath == null || destinationPath.isEmpty) {
        return;
      }

      final File destinationFile = File(destinationPath);
      await destinationFile.parent.create(recursive: true);
      await destinationFile.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved backup to: $destinationPath')),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ${e.message ?? e.code}')),
        );
      }
    } on FileSystemException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Save failed (storage access): ${e.message}. Please pick another location.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('File path copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
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

// End of file
