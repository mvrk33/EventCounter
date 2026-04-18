import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  bool _loadingPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when user comes back from app settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStatus();
    }
  }

  Future<void> _refreshPermissionStatus() async {
    final PermissionStatus status = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _permissionStatus = status;
        _loadingPermission = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = ref.read(notificationServiceProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Alerts',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your reminders & permissions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: <Widget>[
                    // ── Permissions group ───────────────────────────────────
                    _NotifGroup(
                      children: <Widget>[
                        _NotifRow(
                          icon: Icons.notifications_active_rounded,
                          iconColor: const Color(0xFF5E6AD2),
                          title: 'Notification permission',
                          subtitle: _permissionStatus.isGranted
                              ? 'Notifications are enabled ✓'
                              : _permissionStatus.isPermanentlyDenied
                                  ? 'Permanently denied – open Settings to enable'
                                  : 'Allow Daymark to send reminders',
                          trailing: _loadingPermission
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : _permissionStatus.isGranted
                                  ? Icon(Icons.check_circle_rounded,
                                      color: Colors.green.shade600)
                                  : FilledButton(
                                      onPressed: () async {
                                        if (_permissionStatus.isPermanentlyDenied) {
                                          await openAppSettings();
                                        } else {
                                          await notificationService
                                              .requestPermissions();
                                        }
                                        await _refreshPermissionStatus();
                                      },
                                      style: FilledButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        _permissionStatus.isPermanentlyDenied
                                            ? 'Settings'
                                            : 'Allow',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ── Live event notifications ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'LIVE EVENT ALERTS',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                    ),
                    _NotifGroup(
                      children: <Widget>[
                        _NotifRow(
                          icon: Icons.wb_sunny_rounded,
                          iconColor: Colors.amber,
                          title: 'Daily morning summary',
                          subtitle: 'Get a notification at 8 AM with today\'s events',
                          trailing: OutlinedButton(
                            onPressed: _permissionStatus.isGranted
                                ? () async {
                                    await notificationService
                                        .scheduleTodayEventsNotification();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Morning summary scheduled for 8 AM ✓'),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ── Habit reminders group ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'HABIT REMINDERS',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                    ),
                    _NotifGroup(
                      children: <Widget>[
                        _NotifRow(
                          icon: Icons.alarm_rounded,
                          iconColor: Colors.orange,
                          title: 'Daily habit reminder',
                          subtitle: 'Reminder at ${_time.format(context)}',
                          trailing: OutlinedButton(
                            onPressed: _permissionStatus.isGranted
                                ? () async {
                                    final TimeOfDay? selected = await showTimePicker(
                                      context: context,
                                      initialTime: _time,
                                    );
                                    if (selected == null) return;
                                    setState(() => _time = selected);
                                    await notificationService
                                        .scheduleDailyHabitReminder(
                                      hour: selected.hour,
                                      minute: selected.minute,
                                    );
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ── Info box ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: scheme.primary.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(Icons.info_outline_rounded,
                              color: scheme.primary, size: 20),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Event reminders are also configured individually when you create or edit an event.',
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _NotifGroup extends StatelessWidget {
  const _NotifGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.5),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
