import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';

import '../services/home_widget_service.dart';
import '../providers/events_provider.dart';

class WidgetConfigScreen extends ConsumerStatefulWidget {
  const WidgetConfigScreen({super.key});

  @override
  ConsumerState<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends ConsumerState<WidgetConfigScreen> {
  static const MethodChannel _widgetChannel =
      MethodChannel('event_counter/widget_actions');

  // Config state
  String _eventMode = 'nearest';
  bool _transparent = false;
  Color _bgColor = const Color(0xCC5E6AD2);
  Color _textColor = Colors.white;
  bool _showEmoji = true;
  bool _showTitle = true;
  String _countUnit = 'days';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      _eventMode =
          await HomeWidget.getWidgetData<String>(WidgetKeys.cfgEventMode) ??
              'nearest';
      _transparent =
          await HomeWidget.getWidgetData<bool>(WidgetKeys.cfgTransparent) ??
              false;
      _showEmoji =
          await HomeWidget.getWidgetData<bool>(WidgetKeys.cfgShowEmoji) ?? true;
      _showTitle =
          await HomeWidget.getWidgetData<bool>(WidgetKeys.cfgShowTitle) ?? true;
      _countUnit =
          await HomeWidget.getWidgetData<String>(WidgetKeys.cfgCountUnit) ??
              'days';
      final String bgHex =
          await HomeWidget.getWidgetData<String>(WidgetKeys.cfgBgColor) ??
              '#CC5E6AD2';
      final String txtHex =
          await HomeWidget.getWidgetData<String>(WidgetKeys.cfgTextColor) ??
              '#FFFFFFFF';
      _bgColor = _hexToColor(bgHex);
      _textColor = _hexToColor(txtHex);
    } catch (_) {/**/}
    if (mounted) setState(() => _loading = false);
  }

  Color _hexToColor(String hex) {
    try {
      final String clean = hex.replaceAll('#', '');
      return Color(
          int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16));
    } catch (_) {
      return const Color(0xFF5E6AD2);
    }
  }

  String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<void> _applyAndUpdate() async {
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.cfgEventMode, _eventMode);
    await HomeWidget.saveWidgetData<bool>(
        WidgetKeys.cfgTransparent, _transparent);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.cfgBgColor, _colorToHex(_bgColor));
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.cfgTextColor, _colorToHex(_textColor));
    await HomeWidget.saveWidgetData<bool>(WidgetKeys.cfgShowEmoji, _showEmoji);
    await HomeWidget.saveWidgetData<bool>(WidgetKeys.cfgShowTitle, _showTitle);
    await HomeWidget.saveWidgetData<String>(
        WidgetKeys.cfgCountUnit, _countUnit);

    // Re-push widget data with new config
    final events = ref.read(eventsProvider);
    await const EventHomeWidgetService().pushEvents(events);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Widget updated! Add it from your launcher.')),
      );
    }
  }

  Future<void> _pinWidget() async {
    try {
      final bool result =
          (await _widgetChannel.invokeMethod<bool>('pinWidget')) ?? false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Widget pin request sent. Choose where to place it on home screen.'
                : 'Your launcher does not support in-app widget pinning. Add it from home screen widgets list.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not pin widget directly. Add it from your launcher widgets list.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Settings'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _applyAndUpdate,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Apply'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          // ── Live preview ─────────────────────────────────────────────
          _buildPreview(scheme),
          const SizedBox(height: 24),

          // ── Event source ─────────────────────────────────────────────
          _GroupLabel(label: 'EVENT SOURCE'),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              children: <Widget>[
                _OptionTile(
                  icon: Icons.upcoming_rounded,
                  iconColor: scheme.primary,
                  title: 'Nearest upcoming event',
                  subtitle: 'Always shows the event closest to today',
                  selected: _eventMode == 'nearest',
                  onTap: () => setState(() => _eventMode = 'nearest'),
                ),
                _Divider(),
                _OptionTile(
                  icon: Icons.push_pin_rounded,
                  iconColor: Colors.amber.shade700,
                  title: 'Pinned event',
                  subtitle: 'Shows the event you have pinned',
                  selected: _eventMode == 'pinned',
                  onTap: () => setState(() => _eventMode = 'pinned'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Count unit ───────────────────────────────────────────────
          _GroupLabel(label: 'COUNT IN'),
          const SizedBox(height: 8),
          _Card(
            child: Row(
              children: <String>['days', 'months', 'years'].map((String u) {
                final bool sel = _countUnit == u;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: GestureDetector(
                      onTap: () => setState(() => _countUnit = u),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 170),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? scheme.primary : scheme.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          u[0].toUpperCase() + u.substring(1),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? Colors.white
                                : scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 20),

          // ── Display options ──────────────────────────────────────────
          _GroupLabel(label: 'DISPLAY'),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              children: <Widget>[
                _SwitchTile(
                  icon: Icons.emoji_emotions_outlined,
                  iconColor: Colors.orange,
                  title: 'Show emoji',
                  value: _showEmoji,
                  onChanged: (bool v) => setState(() => _showEmoji = v),
                ),
                _Divider(),
                _SwitchTile(
                  icon: Icons.title_rounded,
                  iconColor: scheme.primary,
                  title: 'Show event name',
                  value: _showTitle,
                  onChanged: (bool v) => setState(() => _showTitle = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Background ───────────────────────────────────────────────
          _GroupLabel(label: 'BACKGROUND'),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              children: <Widget>[
                _SwitchTile(
                  icon: Icons.blur_on_rounded,
                  iconColor: Colors.teal,
                  title: 'Transparent background',
                  subtitle: 'Widget blends into your wallpaper',
                  value: _transparent,
                  onChanged: (bool v) => setState(() => _transparent = v),
                ),
                if (!_transparent) ...<Widget>[
                  _Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: <Widget>[
                        _IconBox(
                            icon: Icons.palette_rounded, color: scheme.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Background colour'),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final Color picked =
                                await showColorPickerDialog(context, _bgColor);
                            setState(() => _bgColor = picked);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _bgColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: scheme.outlineVariant, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Text colour ──────────────────────────────────────────────
          _GroupLabel(label: 'TEXT COLOUR'),
          const SizedBox(height: 8),
          _Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: <Widget>[
                  _IconBox(
                      icon: Icons.format_color_text_rounded,
                      color: scheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Text & number colour')),
                  GestureDetector(
                    onTap: () async {
                      final Color picked =
                          await showColorPickerDialog(context, _textColor);
                      setState(() => _textColor = picked);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _textColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: scheme.outlineVariant, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _applyAndUpdate,
            icon: const Icon(Icons.widgets_rounded),
            label: const Text('Apply & Update Widget'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pinWidget,
            icon: const Icon(Icons.add_to_home_screen_rounded),
            label: const Text('Add widget to Home Screen'),
          ),
        ],
      ),
    );
  }

  // Live preview card
  Widget _buildPreview(ColorScheme scheme) {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: _transparent
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : _bgColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (_transparent ? Colors.black : _bgColor)
                  .withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_showEmoji)
              Text('🗓️',
                  style: TextStyle(
                      fontSize: 36,
                      color: _transparent ? scheme.onSurface : _textColor)),
            Text(
              '7',
              style: GoogleFonts.nunito(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: _transparent ? scheme.onSurface : _textColor,
                height: 1.1,
              ),
            ),
            Text(
              '$_countUnit left',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: (_transparent ? scheme.onSurface : _textColor)
                    .withValues(alpha: 0.75),
              ),
            ),
            if (_showTitle)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  'My Birthday',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: (_transparent ? scheme.onSurface : _textColor)
                        .withValues(alpha: 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 0),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 58,
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            _IconBox(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            )),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: scheme.primary, size: 20)
            else
              Icon(Icons.circle_outlined,
                  color: scheme.outlineVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          _IconBox(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null)
                  Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          )),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
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
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      );
}
