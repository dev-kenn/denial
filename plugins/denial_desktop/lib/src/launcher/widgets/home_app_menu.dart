import 'package:flutter/material.dart';

import 'package:denial_flutter_sdk/effects.dart';
import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:denial_flutter_sdk/theme.dart' show ShellColorScheme;
import 'package:denial_flutter_sdk/tokens.dart';

/// One row of [HomeAppMenu].
@immutable
class HomeAppMenuEntry {
  const HomeAppMenuEntry({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
    this.confirmation,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Drawn in the error color: the row removes or ends something.
  final bool destructive;

  /// When set, choosing the row first asks this question, and only a yes runs
  /// [onSelected].
  final String? confirmation;
}

/// What a long press on a home app offers: the app's own desktop actions and
/// the shell's Terminate and Uninstall. A tap outside it, or any chosen row,
/// closes it.
class HomeAppMenu extends StatefulWidget {
  const HomeAppMenu({
    super.key,
    required this.title,
    required this.entries,
    required this.onDismiss,
  });

  final String title;
  final List<HomeAppMenuEntry> entries;
  final VoidCallback onDismiss;

  @override
  State<HomeAppMenu> createState() => _HomeAppMenuState();
}

class _HomeAppMenuState extends State<HomeAppMenu> {
  HomeAppMenuEntry? _confirming;

  void _choose(HomeAppMenuEntry entry) {
    if (entry.confirmation != null) {
      setState(() => _confirming = entry);
      return;
    }
    widget.onDismiss();
    entry.onSelected();
  }

  void _confirm(HomeAppMenuEntry entry) {
    widget.onDismiss();
    entry.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final colors = context.shellColors;
    final radius = BorderRadius.circular(28);
    final confirming = _confirming;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      child: ColoredBox(
        color: ShellMediaColors.darkness.withValues(alpha: 0.38),
        child: Center(
          child: GestureDetector(
            // Taps on the panel stay on it.
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ShellBackdropBlur(
                  separateChild: true,
                  blur: theme.effectivePanelOpacity < 1.0,
                  borderRadius: radius,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.panelColor(colors.panelBackground),
                      borderRadius: radius,
                      border: Border.all(color: colors.hairline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: confirming == null
                            ? _entryRows(colors)
                            : _confirmationRows(context, colors, confirming),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _entryRows(ShellColorScheme colors) => <Widget>[
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ShellText.cardTitle.copyWith(color: colors.textSecondary),
      ),
    ),
    for (final entry in widget.entries)
      _MenuRow(entry: entry, colors: colors, onTap: () => _choose(entry)),
  ];

  List<Widget> _confirmationRows(
    BuildContext context,
    ShellColorScheme colors,
    HomeAppMenuEntry entry,
  ) {
    final accent = ShellTheme.of(context).accentPalette;
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Text(
          entry.confirmation!,
          style: ShellText.cardTitle.copyWith(color: colors.textPrimary),
        ),
      ),
      _MenuRow(
        entry: HomeAppMenuEntry(
          label: entry.label,
          icon: entry.icon,
          onSelected: entry.onSelected,
          destructive: true,
        ),
        colors: colors,
        onTap: () => _confirm(entry),
      ),
      _MenuRow(
        entry: HomeAppMenuEntry(
          label: context.l10n.actionCancel,
          icon: Icons.close_rounded,
          onSelected: widget.onDismiss,
        ),
        colors: colors,
        accent: accent.primary,
        onTap: widget.onDismiss,
      ),
    ];
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.entry,
    required this.colors,
    required this.onTap,
    this.accent,
  });

  final HomeAppMenuEntry entry;
  final ShellColorScheme colors;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = entry.destructive
        ? Theme.of(context).colorScheme.error
        : (accent ?? colors.textPrimary);
    return Semantics(
      button: true,
      label: entry.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(entry.icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShellText.cardTitle.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
