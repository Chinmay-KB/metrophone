// THESIS: Metrophone is a spatial Start screen, not an Android app grid with a Metro skin.
// OWN-WORLD: black field, Selawik, #3e65ff tile planes, square geometry, no decorative chrome.
// STORY: glance at live tiles, swipe once to the alphabetized catalog, hold to edit, tap to launch.
// FIRST VIEWPORT: the four-column Start grid begins at y=56; setup controls appear only when required.
// FORM: measured Windows Phone 8.1 shell, the brief-pinned reference direction (wp81-launcher).
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:wp_pivot_flutter/wp_components.dart';

import '../controller/launcher_controller.dart';
import '../models/installed_app.dart';
import '../models/notification_snapshot.dart';
import '../models/pinned_tile.dart';
import 'launcher_icon.dart';
import 'launcher_tile_layout.dart';
import 'start_role_icon.dart';

const _accent = Color(0xff3e65ff);
const _referenceWidth = 480.0;
const _appListRowHeight = 74.0;
const _appListContentLeft = 86.0;
const _appListFirstSlotTop = 51.0;
const _alphabetLetters = <String>[
  '#',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
  '◎',
];

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({
    super.key,
    required this.controller,
    required this.disposeController,
  });

  final LauncherController controller;
  final bool disposeController;

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen>
    with WidgetsBindingObserver {
  final _readyKey = GlobalKey<_ReadyLauncherState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.controller.state == LauncherLoadState.ready) {
      unawaited(_refreshAfterResume());
    }
  }

  Future<void> _refreshAfterResume() async {
    try {
      await Future.wait([
        widget.controller.refreshCapabilities(),
        widget.controller.refreshCatalog(),
        widget.controller.refreshNotifications(),
      ]);
      _readyKey.currentState?.playEntry();
    } catch (error) {
      debugPrint('Metrophone resume refresh failed: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.disposeController) widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      // Launcher policy: load state routing. Presentation is DS-owned.
      return switch (widget.controller.state) {
        LauncherLoadState.idle ||
        LauncherLoadState.loading => const WpLoadingSurface(),
        LauncherLoadState.failed => WpFailureSurface(
          headline: 'Metrophone could not start',
          detail:
              widget.controller.error ??
              'The launcher returned an unknown error.',
          onRetry: widget.controller.initialize,
        ),
        LauncherLoadState.ready => _ReadyLauncher(
          key: _readyKey,
          controller: widget.controller,
        ),
      };
    },
  );
}

class _ReadyLauncher extends StatefulWidget {
  const _ReadyLauncher({super.key, required this.controller});

  final LauncherController controller;

  @override
  State<_ReadyLauncher> createState() => _ReadyLauncherState();
}

class _ReadyLauncherState extends State<_ReadyLauncher>
    with SingleTickerProviderStateMixin {
  late final PageController _surfaceController;
  late final AnimationController _sceneController;
  final _appsKey = GlobalKey<_AppsSurfaceState>();
  var _sceneDirection = WpSceneTransitionDirection.enter;
  String? _editingPackage;
  var _surface = 0;

  @override
  void initState() {
    super.initState();
    _surfaceController = PageController();
    _sceneController = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _surfaceController.dispose();
    _sceneController.dispose();
    super.dispose();
  }

  void playEntry() {
    if (!mounted) return;
    setState(() => _sceneDirection = WpSceneTransitionDirection.enter);
    _sceneController.value = 0;
    unawaited(
      _sceneController.animateTo(
        1,
        duration: _motionDuration(const Duration(milliseconds: 320)),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Duration _motionDuration(Duration duration) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false
      ? Duration.zero
      : duration;

  Future<void> _launchApp(InstalledApp app) async {
    if (_sceneController.isAnimating) return;
    setState(() {
      _editingPackage = null;
      _sceneDirection = WpSceneTransitionDirection.exit;
    });
    _sceneController.value = 0;
    await _sceneController.animateTo(
      1,
      duration: _motionDuration(const Duration(milliseconds: 280)),
      curve: Curves.easeInCubic,
    );
    final launched = await widget.controller.launchApp(app);
    if (!launched && mounted) playEntry();
  }

  void _openApps() {
    _editingPackage = null;
    unawaited(
      _surfaceController.animateToPage(
        1,
        duration: _motionDuration(const Duration(milliseconds: 240)),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _handleBack() {
    if (_appsKey.currentState?.handleBack() ?? false) return;
    if (_surface == 1) {
      unawaited(
        _surfaceController.animateToPage(
          0,
          duration: _motionDuration(const Duration(milliseconds: 240)),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _handleBack();
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: WpSplitSurfaceView(
        controller: _surfaceController,
        onSurfaceChanged: (surface) {
          setState(() {
            _surface = surface;
            _editingPackage = null;
          });
        },
        first: _StartSurface(
          controller: widget.controller,
          sceneAnimation: _sceneController,
          sceneDirection: _sceneDirection,
          editingPackage: _editingPackage,
          onEditingChanged: (packageName) {
            if (packageName != null) {
              // Edit mode is a resting Start state. Never carry a launch or
              // resume perspective pose into a long-press transition.
              _sceneController.stop();
              _sceneController.value = 1;
              _sceneDirection = WpSceneTransitionDirection.enter;
            }
            setState(() => _editingPackage = packageName);
          },
          onLaunch: _launchApp,
          onOpenApps: _openApps,
        ),
        second: _AppsSurface(
          key: _appsKey,
          controller: widget.controller,
          sceneAnimation: _sceneController,
          sceneDirection: _sceneDirection,
          onLaunch: _launchApp,
        ),
      ),
    ),
  );
}

class _StartSurface extends StatefulWidget {
  const _StartSurface({
    required this.controller,
    required this.sceneAnimation,
    required this.sceneDirection,
    required this.editingPackage,
    required this.onEditingChanged,
    required this.onLaunch,
    required this.onOpenApps,
  });

  final LauncherController controller;
  final Animation<double> sceneAnimation;
  final WpSceneTransitionDirection sceneDirection;
  final String? editingPackage;
  final ValueChanged<String?> onEditingChanged;
  final Future<void> Function(InstalledApp app) onLaunch;
  final VoidCallback onOpenApps;

  @override
  State<_StartSurface> createState() => _StartSurfaceState();
}

class _StartSurfaceState extends State<_StartSurface> {
  @override
  Widget build(BuildContext context) {
    final slots = packLauncherTiles(widget.controller.tiles);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Launcher policy: capability gating + Android consent entry points.
    // Presentation (2-unit top rule, 48x48 square actions, 24-unit offsets)
    // is DS-owned via WpSetupPanel.
    final capabilities = widget.controller.capabilities;

    final surface = ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => widget.onEditingChanged(null),
        child: Stack(
          key: const ValueKey('launcher-ready'),
          children: [
            if (slots.isEmpty)
              // Launcher policy: empty detection + navigation. Presentation
              // (44-unit icon, 21-unit message, semantics) is DS-owned.
              WpEmptyStart(onOpen: widget.onOpenApps)
            else
              Positioned.fill(
                top: 56 * (MediaQuery.sizeOf(context).width / _referenceWidth),
                child: ListView(
                  key: const ValueKey('start-tile-scroll'),
                  padding: EdgeInsets.only(bottom: 32 + bottomInset),
                  children: [
                    _AnimatedStartTileGrid(
                      controller: widget.controller,
                      sceneAnimation: widget.sceneAnimation,
                      sceneDirection: widget.sceneDirection,
                      editingPackage: widget.editingPackage,
                      onEditingChanged: widget.onEditingChanged,
                      onLaunch: widget.onLaunch,
                    ),
                  ],
                ),
              ),
            WpSetupPanel(
              actions: [
                if (!capabilities.isDefaultLauncher)
                  WpSetupAction(
                    label: 'set as home',
                    onPressed: widget.controller.requestDefaultLauncher,
                  ),
                if (!capabilities.hasNotificationAccess)
                  WpSetupAction(
                    label: 'enable live tiles',
                    onPressed:
                        widget.controller.openNotificationAccessSettings,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    // Native shell return (WP8.1 dialer -> Start capture) swings the whole
    // Start surface back as one rigid page around the right edge: no
    // per-tile stagger or fade on entry. Exit keeps the measured stagger.
    if (widget.sceneDirection == WpSceneTransitionDirection.enter) {
      return WpStaggeredSceneTransition(
        key: const ValueKey('start-scene-page-entry'),
        animation: widget.sceneAnimation,
        direction: WpSceneTransitionDirection.enter,
        order: 0,
        maxOrder: 0,
        alignment: Alignment.centerRight,
        fade: false,
        child: surface,
      );
    }
    return surface;
  }

  static double _exitOrder(LauncherTileSlot slot) =>
      math.min(8.0, 4 - slot.column - slot.columnSpan + slot.row * 0.5);
}

class _AnimatedStartTileGrid extends StatefulWidget {
  // Phase 2 evaluation (WpEditableStartGrid): NOT adopted.
  // Risk to drag-reorder (0.25 overlap activation, preview/commit via
  // reorderTileTo, 220ms reflow, 180/160ms edit scale/opacity, ambient wiggle),
  // scene-transition wrapping (exit/entry order capped at 8 via
  // WpStaggeredSceneTransition), tile Semantics/launch/unpin/resize, and grid
  // height (launcher excludes 56-unit field top because it sits in a ListView
  // below that offset; DS referenceHeight includes it). Existing
  // edit_interactions tests pin 'start-tile-stack'/'tile-position-*'/
  // 'tile-edit-*' keys (DS uses 'editable-start-tile-stack'). Leave
  // launcher-owned until a byte-identical reorder migration is proven.
  const _AnimatedStartTileGrid({
    required this.controller,
    required this.sceneAnimation,
    required this.sceneDirection,
    required this.editingPackage,
    required this.onEditingChanged,
    required this.onLaunch,
  });

  final LauncherController controller;
  final Animation<double> sceneAnimation;
  final WpSceneTransitionDirection sceneDirection;
  final String? editingPackage;
  final ValueChanged<String?> onEditingChanged;
  final Future<void> Function(InstalledApp app) onLaunch;

  @override
  State<_AnimatedStartTileGrid> createState() => _AnimatedStartTileGridState();
}

class _AnimatedStartTileGridState extends State<_AnimatedStartTileGrid>
    with SingleTickerProviderStateMixin {
  // A quarter of a small 99px tile is enough physical overlap to communicate
  // intent while rejecting accidental 1--2px pointer tremor (and is twice the
  // measured 12px Start gutter).
  static const _activationOverlapFraction = 0.25;
  List<PinnedTile>? _previewTiles;
  String? _draggingPackage;
  Offset _dragDelta = Offset.zero;
  Offset? _dragStart;
  double _reflowProgress = 0;
  bool _previewCanCommit = false;
  bool _motionReduced = false;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionReduced = MediaQuery.disableAnimationsOf(context);
    _syncAmbientMotion();
  }

  @override
  void didUpdateWidget(covariant _AnimatedStartTileGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAmbientMotion();
    if (widget.editingPackage == null && oldWidget.editingPackage != null) {
      _draggingPackage = null;
      _dragStart = null;
      _dragDelta = Offset.zero;
      _previewTiles = null;
      _reflowProgress = 0;
      _previewCanCommit = false;
    }
  }

  void _syncAmbientMotion() {
    if (widget.editingPackage != null && !_motionReduced) {
      if (!_ambientController.isAnimating) _ambientController.repeat();
    } else {
      _ambientController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  void _startDrag(String packageName, PointerDownEvent event) {
    if (widget.editingPackage != packageName) return;
    setState(() {
      _draggingPackage = packageName;
      _dragStart = event.position;
      _dragDelta = Offset.zero;
      _previewTiles = null;
      _reflowProgress = 0;
      _previewCanCommit = false;
    });
  }

  void _updateDrag(String packageName, PointerMoveEvent event, double scale) {
    if (_draggingPackage != packageName || _dragStart == null) return;
    final delta = (event.position - _dragStart!) / scale;
    final original = widget.controller.tiles;
    final originSlots = packLauncherTiles(original);
    final origin = originSlots.firstWhere(
      (slot) => slot.tile.packageName == packageName,
    );
    final movingRect = _slotRect(origin).shift(delta);
    final candidates = originSlots.where(
      (slot) => slot.tile.packageName != packageName,
    );
    LauncherTileSlot? target;
    var largestOverlap = 0.0;
    var largestOverlapFraction = 0.0;
    for (final slot in candidates) {
      final candidateRect = _slotRect(slot);
      final overlap = movingRect.intersect(candidateRect);
      final overlapArea =
          (math.max(0, overlap.width) * math.max(0, overlap.height)).toDouble();
      final comparisonArea = math.min(
        movingRect.width * movingRect.height,
        candidateRect.width * candidateRect.height,
      );
      if (overlapArea > largestOverlap) {
        largestOverlap = overlapArea;
        largestOverlapFraction = comparisonArea == 0
            ? 0
            : overlapArea / comparisonArea;
        target = slot;
      }
    }
    final preview = [...original];
    final oldIndex = preview.indexWhere(
      (tile) => tile.packageName == packageName,
    );
    if (target != null && largestOverlap > 0 && oldIndex >= 0) {
      final moving = preview.removeAt(oldIndex);
      preview.insert(target.index.clamp(0, preview.length), moving);
    }
    setState(() {
      _dragDelta = delta;
      _previewTiles = target == null || largestOverlap == 0 ? null : preview;
      _reflowProgress = (largestOverlapFraction / _activationOverlapFraction)
          .clamp(0.0, 1.0);
      _previewCanCommit = largestOverlapFraction >= _activationOverlapFraction;
    });
  }

  Rect _slotRect(LauncherTileSlot slot) {
    final width = slot.columnSpan * 99 + (slot.columnSpan - 1) * 12.0;
    final height = slot.rowSpan * 99 + (slot.rowSpan - 1) * 12.0;
    return Rect.fromLTWH(slot.column * 111.0, slot.row * 111.0, width, height);
  }

  void _endDrag(String packageName) {
    if (_draggingPackage != packageName) return;
    final preview = _previewTiles;
    final shouldCommit = _previewCanCommit;
    final oldIndex = widget.controller.tiles.indexWhere(
      (tile) => tile.packageName == packageName,
    );
    final newIndex = shouldCommit
        ? preview?.indexWhere((tile) => tile.packageName == packageName) ??
              oldIndex
        : oldIndex;
    setState(() {
      _draggingPackage = null;
      _dragStart = null;
      _dragDelta = Offset.zero;
      _previewCanCommit = false;
      if (shouldCommit) {
        _reflowProgress = 1;
      } else {
        _previewTiles = null;
        _reflowProgress = 0;
      }
    });
    if (oldIndex >= 0 && newIndex >= 0 && oldIndex != newIndex) {
      unawaited(
        widget.controller.reorderTileTo(oldIndex, newIndex).whenComplete(() {
          if (!mounted) return;
          setState(() {
            _previewTiles = null;
            _reflowProgress = 0;
          });
        }),
      );
    } else if (shouldCommit) {
      setState(() {
        _previewTiles = null;
        _reflowProgress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final referenceScale = MediaQuery.sizeOf(context).width / _referenceWidth;
    final tiles = _previewTiles ?? widget.controller.tiles;
    final slots = packLauncherTiles(tiles);
    final originalSlots = packLauncherTiles(widget.controller.tiles);
    final previewLastRow = slots.fold<int>(
      0,
      (value, slot) => math.max(value, slot.row + slot.rowSpan),
    );
    final originalLastRow = originalSlots.fold<int>(
      0,
      (value, slot) => math.max(value, slot.row + slot.rowSpan),
    );
    final lastRow = math.max(previewLastRow, originalLastRow);
    final maxExitOrder = slots.fold<double>(
      0,
      (value, slot) => math.max(value, _StartSurfaceState._exitOrder(slot)),
    );
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox(
      height: (lastRow * 111 - 12 + 32) * referenceScale,
      child: Stack(
        key: const ValueKey('start-tile-stack'),
        clipBehavior: Clip.none,
        children: [
          for (final slot in slots.where(
            (slot) => slot.tile.packageName != _draggingPackage,
          ))
            _buildSlot(
              context,
              slot,
              originalSlots,
              referenceScale,
              reducedMotion,
              maxExitOrder,
            ),
          for (final slot in slots.where(
            (slot) => slot.tile.packageName == _draggingPackage,
          ))
            _buildSlot(
              context,
              slot,
              originalSlots,
              referenceScale,
              reducedMotion,
              maxExitOrder,
            ),
        ],
      ),
    );
  }

  Widget _buildSlot(
    BuildContext context,
    LauncherTileSlot slot,
    List<LauncherTileSlot> originalSlots,
    double scale,
    bool reducedMotion,
    double maxExitOrder,
  ) {
    final packageName = slot.tile.packageName;
    final dragging = packageName == _draggingPackage;
    final origin = originalSlots.firstWhere(
      (item) => item.tile.packageName == packageName,
    );
    final positioned = dragging ? origin : slot;
    final isSelected = widget.editingPackage == packageName;
    final inEdit = widget.editingPackage != null;
    final width =
        (positioned.columnSpan * 99 + (positioned.columnSpan - 1) * 12) * scale;
    final height =
        (positioned.rowSpan * 99 + (positioned.rowSpan - 1) * 12) * scale;
    final column = dragging
        ? origin.column.toDouble()
        : _lerp(
            origin.column.toDouble(),
            slot.column.toDouble(),
            _reflowProgress,
          );
    final row = dragging
        ? origin.row.toDouble()
        : _lerp(origin.row.toDouble(), slot.row.toDouble(), _reflowProgress);
    Widget sceneChild = _LauncherTile(
      controller: widget.controller,
      slot: slot,
      editMode: inEdit,
      editing: isSelected,
      onEditingChanged: widget.onEditingChanged,
      onLaunch: widget.onLaunch,
    );
    // Page-level entry wraps the whole surface (see _StartSurfaceState.build),
    // so tiles skip their staggered exit treatment while entering.
    if (widget.sceneDirection != WpSceneTransitionDirection.enter) {
      sceneChild = WpStaggeredSceneTransition(
        animation: widget.sceneAnimation,
        direction: WpSceneTransitionDirection.exit,
        order: _StartSurfaceState._exitOrder(slot),
        maxOrder: maxExitOrder,
        alignment: Alignment.centerLeft,
        child: sceneChild,
      );
    }
    Widget tile = Listener(
      onPointerDown: (event) => _startDrag(packageName, event),
      onPointerMove: (event) => _updateDrag(packageName, event, scale),
      onPointerUp: (_) => _endDrag(packageName),
      onPointerCancel: (_) => _endDrag(packageName),
      child: AnimatedScale(
        key: ValueKey('tile-edit-scale-$packageName'),
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: inEdit ? (isSelected ? 1.06 : 0.92) : 1,
        child: AnimatedOpacity(
          key: ValueKey('tile-edit-opacity-$packageName'),
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          opacity: inEdit && !isSelected ? 0.72 : 1,
          child: sceneChild,
        ),
      ),
    );
    if (inEdit && !isSelected && !reducedMotion) {
      final phase = _ambientPhase(packageName);
      tile = AnimatedBuilder(
        key: ValueKey('tile-edit-wiggle-$packageName'),
        animation: _ambientController,
        child: tile,
        builder: (context, child) {
          final time = _ambientController.value * math.pi * 2;
          final offset = Offset(
            math.sin(time + phase) * 1.4 * scale,
            math.sin(time * 0.79 + phase * 1.7) * 1.1 * scale,
          );
          final angle = math.sin(time * 1.13 + phase * 0.6) * 0.0035;
          return Transform.translate(
            key: ValueKey('tile-edit-wiggle-offset-$packageName'),
            offset: offset,
            child: Transform.rotate(angle: angle, child: child),
          );
        },
      );
    }
    return AnimatedPositioned(
      key: ValueKey('tile-position-$packageName'),
      duration: reducedMotion || _draggingPackage != null
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left:
          (24 + column * 111) * scale + (dragging ? _dragDelta.dx * scale : 0),
      top: row * 111 * scale + (dragging ? _dragDelta.dy * scale : 0),
      width: width,
      height: height,
      child: tile,
    );
  }

  static double _lerp(double start, double end, double progress) =>
      start + (end - start) * progress;

  static double _ambientPhase(String packageName) {
    var seed = 0;
    for (final codeUnit in packageName.codeUnits) {
      seed = (seed * 31 + codeUnit) & 0x7fffffff;
    }
    return (seed % 360) / 360 * math.pi * 2;
  }
}

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({
    required this.controller,
    required this.slot,
    required this.editMode,
    required this.editing,
    required this.onEditingChanged,
    required this.onLaunch,
  });

  final LauncherController controller;
  final LauncherTileSlot slot;
  final bool editMode;
  final bool editing;
  final ValueChanged<String?> onEditingChanged;
  final Future<void> Function(InstalledApp app) onLaunch;

  @override
  Widget build(BuildContext context) {
    final tile = slot.tile;
    final app = controller.appForPackage(tile.packageName);
    if (app == null) return const SizedBox.shrink();
    final live = tile.liveEnabled
        ? controller.liveContentFor(tile.packageName)
        : null;
    void handleTap() {
      if (editMode) {
        onEditingChanged(null);
      } else {
        unawaited(onLaunch(app));
      }
    }

    void handleLongPress() => onEditingChanged(tile.packageName);

    return Semantics(
      key: ValueKey('tile-${tile.packageName}'),
      container: true,
      button: true,
      enabled: true,
      label: app.label,
      onTap: handleTap,
      onLongPress: handleLongPress,
      // The selected tile's edit buttons remain separate semantic nodes.
      excludeSemantics: !editing,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: handleTap,
        onLongPress: handleLongPress,
        child: WpTile(
          label: tile.size == TileSize.small ? null : app.label,
          semanticLabel: app.label,
          color: _tileColorFor(app),
          editing: editing,
          // Start owns tap/hold recognition. Leaving these null keeps the
          // package's touch-position tilt out of edit entry, which is flat in
          // the native Start recordings.
          onUnpin: editing
              ? () {
                  onEditingChanged(null);
                  unawaited(controller.unpinApp(tile.packageName));
                }
              : null,
          onResize: editing
              ? () {
                  onEditingChanged(null);
                  unawaited(controller.cycleTileSize(tile.packageName));
                }
              : null,
          child: _TileBody(
            controller: controller,
            app: app,
            tile: tile,
            live: live,
          ),
        ),
      ),
    );
  }

  Color _tileColorFor(InstalledApp app) {
    final identity = '${app.label} ${app.packageName}'.toLowerCase();
    if (identity.contains('music') || identity.contains('game')) {
      return const Color(0xff107c10);
    }
    if (identity.contains('office')) return const Color(0xffeb3c00);
    if (identity.contains('note')) return const Color(0xff80397b);
    if (identity.contains('people') || identity.contains('contact')) {
      return const Color(0xff9dafff);
    }
    return _accent;
  }
}

class _TileBody extends StatelessWidget {
  const _TileBody({
    required this.controller,
    required this.app,
    required this.tile,
    required this.live,
  });

  final LauncherController controller;
  final InstalledApp app;
  final PinnedTile tile;
  final LiveTileContent? live;

  @override
  Widget build(BuildContext context) {
    // Launcher policy: icon size + role selection + wide-only live rule.
    // Presentation (18/18/18/34 padding, 18-unit gap, 19/16/25-unit type,
    // count>1 rule, centering) is DS-owned via WpLiveTileContent.
    final iconSize = switch (tile.size) {
      TileSize.small => 42.0,
      TileSize.medium => 64.0,
      TileSize.wide => 64.0,
    };
    final role = startRoleFor(packageName: app.packageName, label: app.label);
    final icon = role == null
        ? LauncherIcon(
            controller: controller,
            packageName: app.packageName,
            size: iconSize,
          )
        : StartRoleIcon(packageName: role);
    final wideLive = tile.size == TileSize.wide ? live : null;
    return WpLiveTileContent(
      icon: icon,
      title: wideLive?.title,
      body: wideLive?.text,
      count: wideLive?.notificationCount ?? 0,
    );
  }
}

class _AppsSurface extends StatefulWidget {
  const _AppsSurface({
    super.key,
    required this.controller,
    required this.sceneAnimation,
    required this.sceneDirection,
    required this.onLaunch,
  });

  final LauncherController controller;
  final Animation<double> sceneAnimation;
  final WpSceneTransitionDirection sceneDirection;
  final Future<void> Function(InstalledApp app) onLaunch;

  @override
  State<_AppsSurface> createState() => _AppsSurfaceState();
}

class _AppsSurfaceState extends State<_AppsSurface>
    with SingleTickerProviderStateMixin {
  // Phase 2 evaluation (WpAlphabetOverlay): NOT adopted.
  // Risk to 440/340ms envelope (app fade 0-18% easeIn with -12 slide, plane
  // fade 20-60% easeOutCubic, input ignored while closing or <35%), plus
  // byte-identical return frames via _holdingAppListForSelection +
  // ScrollController replacement + post-frame jump (WpSplitSurfaceView offset
  // restoration). Launcher owns sections/enabledLetters/scroll mapping/Back
  // precedence; migrating now risks selection/back-dismissal regressions
  // covered by the alphabet-picker return-frame tests. Leave launcher-owned.
  late ScrollController _scrollController;
  final _searchController = TextEditingController();
  late final AnimationController _alphabetController;
  Timer? _noticeTimer;
  bool _showAlphabet = false;
  bool _alphabetClosing = false;
  bool _holdingAppListForSelection = false;
  bool _searching = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _alphabetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
      reverseDuration: const Duration(milliseconds: 340),
    );
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _alphabetController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<InstalledApp> get _visibleApps {
    final query = _searchController.text.trim().toLowerCase();
    final apps = widget.controller.apps.where((app) {
      if (query.isEmpty) return true;
      return app.label.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();
    apps.sort(
      (left, right) =>
          left.label.toLowerCase().compareTo(right.label.toLowerCase()),
    );
    return apps;
  }

  String _sectionFor(InstalledApp app) {
    final label = app.label.trim().toLowerCase();
    if (label.isEmpty) return '#';
    final first = label[0];
    return RegExp('[a-z]').hasMatch(first) ? first : '#';
  }

  List<_AppListEntry> _entries() {
    final entries = <_AppListEntry>[];
    if (_searching) entries.add(const _AppListEntry.search());
    String? previousSection;
    for (final app in _visibleApps) {
      final section = _sectionFor(app);
      if (section != previousSection) {
        entries.add(_AppListEntry.header(section));
        previousSection = section;
      }
      entries.add(_AppListEntry.app(app));
    }
    return entries;
  }

  Set<String> get _enabledLetters => {
    for (final app in widget.controller.apps) _sectionFor(app),
  };

  bool handleBack() {
    if (_showAlphabet) {
      unawaited(_dismissAlphabet());
      return true;
    }
    if (_searching) {
      setState(() {
        _searching = false;
        _searchController.clear();
      });
      return true;
    }
    return false;
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchController.clear();
    });
  }

  void _openAlphabet() {
    setState(() {
      _searching = false;
      _searchController.clear();
      _showAlphabet = true;
      _alphabetClosing = false;
      _holdingAppListForSelection = false;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _alphabetController.value = 1;
    } else {
      _alphabetController.forward(from: 0);
    }
  }

  Future<void> _dismissAlphabet() async {
    if (!_showAlphabet || _alphabetClosing) return;
    setState(() => _alphabetClosing = true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _alphabetController.value = 0;
    } else {
      await _alphabetController.reverse();
    }
    if (!mounted) return;
    setState(() {
      _showAlphabet = false;
      _alphabetClosing = false;
    });
  }

  Future<void> _jumpTo(String letter) async {
    if (_alphabetClosing) return;
    // Hold the catalog black through reverse and the dismissal rebuild. The
    // selected destination is then applied before this held surface can be
    // revealed, so the prior section never becomes a visible return frame.
    setState(() => _holdingAppListForSelection = true);
    final destinationOffset = _replaceScrollForLetter(letter);
    await _dismissAlphabet();
    if (!mounted) return;
    if (destinationOffset == null) {
      // A dynamically removed section cannot be selected through the grid,
      // but do not strand the catalog behind its selection clearance if the
      // app catalog changes between the tap and the dismissal.
      setState(() => _holdingAppListForSelection = false);
      return;
    }
    // WpSplitSurfaceView may restore the offset it owned before dismissal.
    // Correct the fresh controller while the catalog is still black, then
    // reveal only the selected section in the following build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(destinationOffset);
      }
      setState(() => _holdingAppListForSelection = false);
    });
  }

  double? _replaceScrollForLetter(String letter) {
    final entries = _entries();
    final index = entries.indexWhere(
      (entry) =>
          entry.kind == _AppListEntryKind.header && entry.letter == letter,
    );
    if (index < 0) return null;
    final scale = MediaQuery.sizeOf(context).width / _referenceWidth;
    final destinationOffset = index * _appListRowHeight * scale;
    final previousController = _scrollController;
    setState(() {
      _scrollController = ScrollController(
        initialScrollOffset: destinationOffset,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previousController.dispose();
    });
    return destinationOffset;
  }

  Widget _buildAppListTransition(Widget child) {
    if (!_showAlphabet) return child;
    final progress = _alphabetController.value;
    // The native picker clears the catalog before the letter plane arrives,
    // and lets the list return only after that plane has gone. Keeping this
    // envelope symmetric also makes selection/back dismissal a clean
    // reversal instead of exposing two independently moving letter surfaces.
    final appOpacity =
        (1 -
                Curves.easeIn.transform(
                  (progress / .18).clamp(0.0, 1.0).toDouble(),
                ))
            .clamp(0.0, 1.0)
            .toDouble();
    return Opacity(
      opacity: appOpacity,
      child: Transform.translate(
        offset: Offset(-12 * (1 - appOpacity), 0),
        child: child,
      ),
    );
  }

  void _togglePinned(InstalledApp app) {
    final pinned = widget.controller.isPinned(app.packageName);
    if (pinned) {
      unawaited(widget.controller.unpinApp(app.packageName));
      _showNotice('unpinned ${app.label}');
    } else {
      unawaited(widget.controller.pinApp(app.packageName));
      _showNotice('pinned ${app.label} to Start');
    }
  }

  void _showNotice(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    final maxOrder = math.min(8.0, math.max(0, entries.length - 1) * 0.35);
    final scale = MediaQuery.sizeOf(context).width / _referenceWidth;
    final appListSurface = Stack(
      children: [
        WpAppListView(
          key: const ValueKey('app-list'),
          controller: _scrollController,
          referenceBottomPadding:
              24 + MediaQuery.paddingOf(context).bottom / scale,
          leadingAction: WpCircularAffordance(
            // Launcher policy: search open/close state + toggle. Presentation
            // (44-unit circle, 2-unit ring, 28-unit WpSearchGlyph) is DS-owned.
            key: const ValueKey('app-search-action'),
            searching: _searching,
            onPressed: _toggleSearch,
          ),
          children: [
            // Page-level entry wraps the whole list (see below), so rows
            // skip their staggered exit treatment while entering.
            for (var index = 0; index < entries.length; index++)
              if (widget.sceneDirection == WpSceneTransitionDirection.enter)
                _buildEntry(entries[index])
              else
                WpStaggeredSceneTransition(
                  animation: widget.sceneAnimation,
                  direction: WpSceneTransitionDirection.exit,
                  order: math.min(8.0, index * 0.35),
                  maxOrder: maxOrder,
                  // Measured WP8.1 pivot is the right edge (see pivot test).
                  alignment: Alignment.centerRight,
                  child: _buildEntry(entries[index]),
                ),
          ],
        ),
        if (_searching)
          Positioned(
            // Launcher policy: search slot insets (content column, first slot).
            // Presentation (74-unit row, 62-unit inner, 25-unit text,
            // rest/focused underlines, cursor, semantics) is DS-owned.
            // Filtering/sorting/sections/Back stay in launcher.
            left: _appListContentLeft * scale,
            top: _appListFirstSlotTop * scale,
            right: 24 * scale,
            height: _appListRowHeight * scale,
            child: WpSearchField(
              controller: _searchController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
        // Launcher policy: pin/unpin messages + 1600ms hold timer stay here.
        // Presentation (19-unit live-region notice, 120ms fade, 24-unit
        // offsets) is DS-owned via WpTransientNotice.
        WpTransientNotice(text: _notice),
      ],
    );
    // Native shell return swings the whole app list back as one rigid page
    // around the right edge with no stagger or fade. Exit keeps per-row order.
    final sceneSurface =
        widget.sceneDirection == WpSceneTransitionDirection.enter
        ? WpStaggeredSceneTransition(
            key: const ValueKey('apps-scene-page-entry'),
            animation: widget.sceneAnimation,
            direction: WpSceneTransitionDirection.enter,
            order: 0,
            maxOrder: 0,
            alignment: Alignment.centerRight,
            fade: false,
            child: appListSurface,
          )
        : appListSurface;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: _showAlphabet || _holdingAppListForSelection,
              child: AnimatedBuilder(
                animation: _alphabetController,
                child: sceneSurface,
                builder: (context, child) {
                  if (_holdingAppListForSelection) {
                    return Opacity(opacity: 0, child: child);
                  }
                  return _buildAppListTransition(child!);
                },
              ),
            ),
            if (_showAlphabet)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top,
                  ),
                  child: AnimatedBuilder(
                    animation: _alphabetController,
                    builder: (context, child) {
                      final progress = _alphabetController.value;
                      // Fade the plane as one measured surface.  The grid
                      // component owns tile geometry, so moving only its
                      // child labels would shear labels across fixed cells.
                      final gridOpacity = Curves.easeOutCubic.transform(
                        ((progress - .20) / .40).clamp(0.0, 1.0).toDouble(),
                      );
                      return Opacity(
                        opacity: gridOpacity,
                        child: IgnorePointer(
                          ignoring: _alphabetClosing || progress < .35,
                          child: WpAlphabetGrid(
                            letters: _alphabetLetters,
                            enabledLetters: _enabledLetters,
                            onSelected: (letter) => unawaited(_jumpTo(letter)),
                            onCancel: () => unawaited(_dismissAlphabet()),
                            cellBuilder: (context, letter, enabled) =>
                                _buildAlphabetCell(context, letter, enabled),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(_AppListEntry entry) {
    return switch (entry.kind) {
      _AppListEntryKind.search => const SizedBox.expand(),
      _AppListEntryKind.header => WpAppListHeader(
        letter: entry.letter!,
        semanticLabel: '${entry.letter} apps. Open alphabet jump list',
        onTap: _openAlphabet,
      ),
      _AppListEntryKind.app => _AppRow(
        key: ValueKey('app-${entry.app!.packageName}'),
        controller: widget.controller,
        app: entry.app!,
        pinned: widget.controller.isPinned(entry.app!.packageName),
        onTap: () => widget.onLaunch(entry.app!),
        onLongPress: () => _togglePinned(entry.app!),
      ),
    };
  }

  Widget _buildAlphabetCell(BuildContext context, String letter, bool enabled) {
    final scale = MediaQuery.sizeOf(context).width / _referenceWidth;
    final theme = WpPhoneTheme.of(context);
    final child = letter == '◎'
        ? Icon(Icons.language, color: theme.foregroundColor, size: 38 * scale)
        : Text(
            letter,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: theme.foregroundColor,
              fontFamily: theme.fontFamily,
              fontSize: 50 * scale,
              fontWeight: FontWeight.w300,
              height: 1,
            ),
          );
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 12 * scale, bottom: 4 * scale),
        child: child,
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    super.key,
    required this.controller,
    required this.app,
    required this.pinned,
    required this.onTap,
    required this.onLongPress,
  });

  final LauncherController controller;
  final InstalledApp app;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final pinAction = CustomSemanticsAction(
      label: pinned ? 'Unpin ${app.label}' : 'Pin ${app.label} to Start',
    );
    return Semantics(
      customSemanticsActions: {pinAction: onLongPress},
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: onLongPress,
        child: WpAppListRow(
          icon: _appIcon(app),
          label: app.label,
          semanticLabel: pinned ? '${app.label}, pinned' : app.label,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _appIcon(InstalledApp app) {
    final role = startRoleFor(packageName: app.packageName, label: app.label);
    return role == null
        ? LauncherIcon(
            controller: controller,
            packageName: app.packageName,
            size: 42,
          )
        : StartRoleIcon(packageName: role);
  }
}

enum _AppListEntryKind { search, header, app }

class _AppListEntry {
  const _AppListEntry.search()
    : kind = _AppListEntryKind.search,
      letter = null,
      app = null;

  const _AppListEntry.header(this.letter)
    : kind = _AppListEntryKind.header,
      app = null;

  const _AppListEntry.app(this.app)
    : kind = _AppListEntryKind.app,
      letter = null;

  final _AppListEntryKind kind;
  final String? letter;
  final InstalledApp? app;
}
