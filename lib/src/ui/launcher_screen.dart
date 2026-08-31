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

const _accent = Color(0xff3e65ff);
const _referenceWidth = 480.0;
const _appListRowHeight = 74.0;
const _appListContentLeft = 86.0;
const _appListFirstSlotTop = 51.0;
const _appListIconSize = 62.0;
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
      return switch (widget.controller.state) {
        LauncherLoadState.idle ||
        LauncherLoadState.loading => const _LoadingSurface(),
        LauncherLoadState.failed => _FailureSurface(
          error: widget.controller.error,
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

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: SizedBox(
        width: 160,
        child: LinearProgressIndicator(
          minHeight: 3,
          color: _accent,
          backgroundColor: Color(0xff202020),
        ),
      ),
    ),
  );
}

class _FailureSurface extends StatelessWidget {
  const _FailureSurface({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Metrophone could not start',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 14),
            Text(
              error ?? 'The launcher returned an unknown error.',
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 28),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _accent,
                minimumSize: const Size(96, 48),
                shape: const RoundedRectangleBorder(),
              ),
              child: const Text('retry'),
            ),
          ],
        ),
      ),
    ),
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

    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => widget.onEditingChanged(null),
        child: Stack(
          key: const ValueKey('launcher-ready'),
          children: [
            if (slots.isEmpty)
              _EmptyStartSurface(onOpenApps: widget.onOpenApps)
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
            _SetupPanel(controller: widget.controller),
          ],
        ),
      ),
    );
  }

  static double _exitOrder(LauncherTileSlot slot) =>
      math.min(8.0, 4 - slot.column - slot.columnSpan + slot.row * 0.5);

  static double _entryOrder(LauncherTileSlot slot) =>
      math.min(8.0, slot.column + slot.columnSpan - 1 + slot.row * 0.5);
}

class _AnimatedStartTileGrid extends StatefulWidget {
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
    final maxEntryOrder = slots.fold<double>(
      0,
      (value, slot) => math.max(value, _StartSurfaceState._entryOrder(slot)),
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
              maxEntryOrder,
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
              maxEntryOrder,
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
    double maxEntryOrder,
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
          child: WpStaggeredSceneTransition(
            animation: widget.sceneAnimation,
            direction: widget.sceneDirection,
            order: _StartSurfaceState._exitOrder(slot),
            maxOrder: maxExitOrder,
            entryOrder: _StartSurfaceState._entryOrder(slot),
            maxEntryOrder: maxEntryOrder,
            alignment: Alignment.centerLeft,
            child: _LauncherTile(
              controller: widget.controller,
              slot: slot,
              editMode: inEdit,
              editing: isSelected,
              onEditingChanged: widget.onEditingChanged,
              onLaunch: widget.onLaunch,
            ),
          ),
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

class _EmptyStartSurface extends StatelessWidget {
  const _EmptyStartSurface({required this.onOpenApps});

  final VoidCallback onOpenApps;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      button: true,
      label: 'Open apps to pin your first tile',
      child: InkWell(
        key: const ValueKey('open-apps-empty'),
        onTap: onOpenApps,
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward, size: 44, color: Colors.white),
              SizedBox(height: 16),
              Text(
                'swipe to apps\nthen hold an app to pin it',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w300,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
    final iconSize = switch (tile.size) {
      TileSize.small => 42.0,
      TileSize.medium => 64.0,
      TileSize.wide => 64.0,
    };
    final icon = LauncherIcon(
      controller: controller,
      packageName: app.packageName,
      size: iconSize,
    );
    if (tile.size != TileSize.wide || live == null) {
      return Center(child: icon);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (live!.title != null)
                  Text(
                    live!.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 19),
                  ),
                if (live!.text != null)
                  Text(
                    live!.text!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, height: 1.12),
                  ),
              ],
            ),
          ),
          if (live!.notificationCount > 1)
            Text(
              '${live!.notificationCount}',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w300),
            ),
        ],
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({required this.controller});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) {
    final capabilities = controller.capabilities;
    if (capabilities.isDefaultLauncher && capabilities.hasNotificationAccess) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 24,
      right: 24,
      bottom: 24 + MediaQuery.paddingOf(context).bottom,
      child: ColoredBox(
        color: Colors.black,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white, width: 2)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (!capabilities.isDefaultLauncher)
                  TextButton(
                    key: const ValueKey('request-home-role'),
                    onPressed: controller.requestDefaultLauncher,
                    style: _setupButtonStyle,
                    child: const Text('set as home'),
                  ),
                if (!capabilities.hasNotificationAccess)
                  TextButton(
                    key: const ValueKey('request-notification-access'),
                    onPressed: controller.openNotificationAccessSettings,
                    style: _setupButtonStyle,
                    child: const Text('enable live tiles'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static final _setupButtonStyle = TextButton.styleFrom(
    foregroundColor: Colors.white,
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    shape: const RoundedRectangleBorder(),
    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
  );
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

class _AppsSurfaceState extends State<_AppsSurface> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _noticeTimer;
  bool _showAlphabet = false;
  bool _searching = false;
  String? _notice;

  @override
  void dispose() {
    _noticeTimer?.cancel();
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
      setState(() => _showAlphabet = false);
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
    });
  }

  void _jumpTo(String letter) {
    setState(() => _showAlphabet = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final entries = _entries();
      final index = entries.indexWhere(
        (entry) =>
            entry.kind == _AppListEntryKind.header && entry.letter == letter,
      );
      if (index < 0) return;
      final scale = MediaQuery.sizeOf(context).width / _referenceWidth;
      unawaited(
        _scrollController.animateTo(
          index * _appListRowHeight * scale,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
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
    if (_showAlphabet) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: ColoredBox(
          color: Colors.black,
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: WpAlphabetGrid(
              letters: _alphabetLetters,
              enabledLetters: _enabledLetters,
              onSelected: _jumpTo,
              onCancel: () => setState(() => _showAlphabet = false),
              cellBuilder: _buildAlphabetCell,
            ),
          ),
        ),
      );
    }

    final entries = _entries();
    final maxOrder = math.min(8.0, math.max(0, entries.length - 1) * 0.35);
    final scale = MediaQuery.sizeOf(context).width / _referenceWidth;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          WpAppListView(
            key: const ValueKey('app-list'),
            controller: _scrollController,
            referenceBottomPadding:
                24 + MediaQuery.paddingOf(context).bottom / scale,
            leadingAction: _AppListLeadingAction(
              searching: _searching,
              onPressed: _toggleSearch,
            ),
            children: [
              for (var index = 0; index < entries.length; index++)
                WpStaggeredSceneTransition(
                  animation: widget.sceneAnimation,
                  direction: widget.sceneDirection,
                  order: math.min(8.0, index * 0.35),
                  maxOrder: maxOrder,
                  entryOrder: math.max(0, maxOrder - index * 0.35),
                  maxEntryOrder: maxOrder,
                  child: _buildEntry(entries[index]),
                ),
            ],
          ),
          if (_searching)
            Positioned(
              left: _appListContentLeft * scale,
              top: _appListFirstSlotTop * scale,
              right: 24 * scale,
              height: _appListRowHeight * scale,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: _appListIconSize * scale,
                  child: TextField(
                    key: const ValueKey('app-search-field'),
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 25 * scale, color: Colors.white),
                    cursorColor: _accent,
                    decoration: const InputDecoration(
                      hintText: 'search',
                      hintStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: _accent, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
            child: IgnorePointer(
              ignoring: _notice == null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _notice == null ? 0 : 1,
                child: ColoredBox(
                  color: Colors.black,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _notice ?? '',
                      style: const TextStyle(fontSize: 19, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
          icon: LauncherIcon(
            controller: controller,
            packageName: app.packageName,
            size: 42,
          ),
          label: app.label,
          semanticLabel: pinned ? '${app.label}, pinned' : app.label,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _AppListLeadingAction extends StatelessWidget {
  const _AppListLeadingAction({
    required this.searching,
    required this.onPressed,
  });

  final bool searching;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: searching ? 'Close app search' : 'Search apps',
    child: Material(
      color: Colors.transparent,
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white, width: 2),
      ),
      child: InkWell(
        key: const ValueKey('app-search-action'),
        onTap: onPressed,
        excludeFromSemantics: true,
        customBorder: const CircleBorder(),
        child: Icon(
          searching ? Icons.close : Icons.search,
          size: 28,
          color: Colors.white,
        ),
      ),
    ),
  );
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
