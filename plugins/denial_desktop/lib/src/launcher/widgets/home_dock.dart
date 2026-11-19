import 'package:flutter/widgets.dart';

import 'package:denial_flutter_sdk/applications.dart';

import '../home_grid_geometry.dart';
import '../home_interactions.dart';
import 'home_tiles.dart';

/// The dock: up to five apps along the bottom of home, over every page. Its
/// tiles keep their size while they fit the grid's columns and shrink to share
/// the row when there are more.
class HomeDock extends StatelessWidget {
  const HomeDock({super.key, required this.apps, required this.geometry});

  final List<HomeGridItem> apps;
  final HomeGridGeometry geometry;

  @override
  Widget build(BuildContext context) {
    final rects = geometry.dockRects(apps.length);
    final interactions = HomeInteractionScope.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var index = 0; index < apps.length; index++)
          Positioned.fromRect(
            key: ValueKey('dock-${apps[index].id}'),
            rect: rects[index],
            child: _DockTile(
              item: apps[index],
              tileSize: geometry.tileSize,
              interactions: interactions,
            ),
          ),
      ],
    );
  }
}

class _DockTile extends StatelessWidget {
  const _DockTile({
    required this.item,
    required this.tileSize,
    required this.interactions,
  });

  final HomeGridItem item;

  /// The size a grid tile has; the dock scales it down to its own.
  final Size tileSize;
  final HomeInteractions interactions;

  void _tap(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    interactions.launch(item, HomeTileMetrics.iconRectIn(rect));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(context),
      onLongPress: () => interactions.holdDockApp(item),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox.fromSize(
          size: tileSize,
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: interactions.hiddenItems,
            builder: (context, hidden, _) => RepaintBoundary(
              child: HomeGridItemCard(
                item: item,
                iconHidden: hidden.contains(item.id),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
