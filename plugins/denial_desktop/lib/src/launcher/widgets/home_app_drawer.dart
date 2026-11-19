import 'package:flutter/gestures.dart' show VelocityTracker;
import 'package:flutter/material.dart';

import 'package:denial_flutter_sdk/applications.dart';
import 'package:denial_flutter_sdk/effects.dart';
import 'package:denial_flutter_sdk/input.dart';
import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:denial_flutter_sdk/tokens.dart';

import '../../widgets/edge_panel_layer.dart';
import '../home_grid_geometry.dart';
import 'home_app_tile.dart';
import 'home_tiles.dart';

/// Every app on home, folders opened, by name, in a full-screen glass sheet
/// that rises from the bottom as [openness] goes from 0 to 1. Pulled down
/// from the top of its list, it follows the finger up and down until the
/// finger lifts, and [onDrag] and [onDragEnd] report it.
class HomeAppDrawer extends StatefulWidget {
  const HomeAppDrawer({
    super.key,
    required this.openness,
    required this.apps,
    required this.columns,
    required this.onLaunch,
    required this.onHold,
    this.onOpened,
    this.onClosed,
    required this.onDrag,
    required this.onDragEnd,
  });

  final Animation<double> openness;
  final Iterable<HomeGridItem> apps;
  final int columns;

  /// Opens an app from its icon, in global coordinates.
  final void Function(HomeGridItem app, Rect iconRect) onLaunch;

  /// A long press on an app.
  final ValueChanged<HomeGridItem> onHold;

  /// The drawer has come fully open, or fully shut.
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  /// Downward travel, in logical pixels.
  final ValueChanged<double> onDrag;

  /// The release's downward velocity, in logical pixels per second.
  final ValueChanged<double> onDragEnd;

  @override
  State<HomeAppDrawer> createState() => _HomeAppDrawerState();
}

class _HomeAppDrawerState extends State<HomeAppDrawer> {
  final _scroll = ScrollController();

  /// The finger that moves the list, or the sheet once it pulls.
  int? _pointer;

  /// The list was at its top and the finger moved down: the finger holds
  /// the sheet, and the list stays still, until it lifts.
  bool _pulling = false;
  late VelocityTracker _velocity;

  late final _physics = _SheetPullPhysics(pulling: () => _pulling);

  /// What the search field holds; the list shows the apps whose names have it.
  final _query = TextEditingController();
  final _searchFocus = FocusNode();

  /// The drawer is on screen: while it is, the search field takes the keys.
  bool _shown = false;

  /// The drawer is all the way open, and the search field has the focus.
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_queryChanged);
    widget.openness.addListener(_opennessChanged);
  }

  @override
  void didUpdateWidget(HomeAppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openness != widget.openness) {
      oldWidget.openness.removeListener(_opennessChanged);
      widget.openness.addListener(_opennessChanged);
    }
  }

  void _queryChanged() => setState(() {});

  /// Closed, the drawer forgets the search and lets go of the keyboard.
  void _opennessChanged() {
    final value = widget.openness.value;
    final shown = value != 0;
    if (shown != _shown) setState(() => _shown = shown);
    if (value >= 1 && !_open) {
      // Fully open: type to search, with the keyboard up.
      _open = true;
      _searchFocus.requestFocus();
      widget.onOpened?.call();
      return;
    }
    if (shown) return;
    if (_open) {
      _open = false;
      widget.onClosed?.call();
    }
    if (_query.text.isNotEmpty) _query.clear();
    if (_searchFocus.hasFocus) _searchFocus.unfocus();
  }

  @override
  void dispose() {
    widget.openness.removeListener(_opennessChanged);
    _query.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _velocity.addPosition(event.timeStamp, event.position);
    if (!_pulling &&
        event.delta.dy > 0 &&
        _scroll.hasClients &&
        _scroll.position.pixels <= _scroll.position.minScrollExtent) {
      _pulling = true;
    }
    if (_pulling) widget.onDrag(event.delta.dy);
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (!_pulling) return;
    _pulling = false;
    widget.onDragEnd(
      event is PointerUpEvent ? _velocity.getVelocity().pixelsPerSecond.dy : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShellTheme.of(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final names = {
      for (final app in widget.apps)
        app: HomeAppTile.nameOf(context, app).toLowerCase(),
    };
    final query = _query.text.trim().toLowerCase();
    final apps =
        names.keys
            .where((app) => query.isEmpty || names[app]!.contains(query))
            .toList()
          ..sort((a, b) => names[a]!.compareTo(names[b]!));
    return AnimatedBuilder(
      animation: widget.openness,
      builder: (context, sheet) {
        final openness = widget.openness.value;
        // No fade: glass under an opacity layer has nothing to blur. Closed,
        // it paints nothing, yet a finger that pulled it down holds it.
        return Offstage(
          offstage: openness == 0,
          child: FractionalTranslation(
            translation: Offset(0, 1 - openness),
            child: sheet,
          ),
        );
      },
      child: Semantics(
        container: true,
        label: context.l10n.homeDrawerSemantics,
        child: ShellBackdropBlur(
          separateChild: true,
          blur: theme.effectivePanelOpacity < 1.0,
          borderRadius: BorderRadius.zero,
          // Dark like the wallpaper under home: the labels are white.
          child: ColoredBox(
            color: ShellMediaColors.darkness.withValues(alpha: 0.55),
            child: Stack(
              children: [
                Listener(
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: GridView.builder(
                    controller: _scroll,
                    physics: _physics,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      padding.top + 72,
                      20,
                      padding.bottom + 72 + 64,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.columns,
                      mainAxisExtent: HomeGridLayout.minTileHeight,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: HomeGridLayout.gridGap,
                    ),
                    itemCount: apps.length,
                    itemBuilder: (context, index) => _DrawerTile(
                      key: ValueKey(apps[index].id),
                      app: apps[index],
                      onLaunch: widget.onLaunch,
                      onHold: widget.onHold,
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: padding.bottom + 16,
                  // The keyboard is a panel over the screen, so the field
                  // rides above it, and its bounds ride with it.
                  child: KeyboardRide(
                    clearance: padding.bottom + 16,
                    child: ShellInputRegion(
                      debugLabel: 'App drawer search',
                      active: _shown,
                      keyboardPolicy: ShellKeyboardPolicy.capture,
                      child: _SearchField(
                        controller: _query,
                        focusNode: _searchFocus,
                        hint: context.l10n.homeDrawerSearchHint,
                      ),
                    ),
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

/// The list's scrolling, held still while the finger pulls the sheet. A
/// list shorter than the screen still takes the drag.
class _SheetPullPhysics extends ClampingScrollPhysics {
  const _SheetPullPhysics({required this.pulling, super.parent});

  final bool Function() pulling;

  @override
  _SheetPullPhysics applyTo(ScrollPhysics? ancestor) =>
      _SheetPullPhysics(pulling: pulling, parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      pulling() ? 0 : super.applyPhysicsToUserOffset(position, offset);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => pulling() ? null : super.createBallisticSimulation(position, velocity);
}

/// The search field at the bottom of the drawer.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Colors.white, fontSize: 17),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    super.key,
    required this.app,
    required this.onLaunch,
    required this.onHold,
  });

  final HomeGridItem app;
  final void Function(HomeGridItem app, Rect iconRect) onLaunch;
  final ValueChanged<HomeGridItem> onHold;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => onHold(app),
      onTap: () {
        final box = context.findRenderObject();
        if (box is! RenderBox || !box.hasSize) return;
        final rect = MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        );
        onLaunch(app, HomeTileMetrics.iconRectIn(rect));
      },
      child: RepaintBoundary(child: HomeGridItemCard(item: app)),
    );
  }
}
