import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wp_pivot_flutter/wp_pivot_flutter.dart';

import '../controller/launcher_controller.dart';
import '../models/installed_app.dart';
import '../models/pinned_tile.dart';
import 'launcher_icon.dart';

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
        LauncherLoadState.idle || LauncherLoadState.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        LauncherLoadState.failed => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Metrophone could not start.'),
                  const SizedBox(height: 12),
                  Text(widget.controller.error ?? 'Unknown error'),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: widget.controller.initialize,
                    child: const Text('retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        LauncherLoadState.ready => _ReadyLauncher(
          controller: widget.controller,
        ),
      };
    },
  );
}

class _ReadyLauncher extends StatelessWidget {
  const _ReadyLauncher({required this.controller});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) => WpPivotView(
    title: 'METROPHONE',
    tabTitles: const ['start', 'apps'],
    children: [
      _StartSurface(controller: controller),
      _AppsSurface(controller: controller),
    ],
  );
}

class _StartSurface extends StatelessWidget {
  const _StartSurface({required this.controller});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: const ValueKey('launcher-ready'),
    slivers: [
      SliverToBoxAdapter(child: _SetupPanel(controller: controller)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            '${controller.apps.length} apps • '
            '${controller.activeNotificationCount} live notifications',
            key: const ValueKey('launcher-diagnostics'),
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      ),
      if (controller.tiles.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No tiles pinned yet. Open apps and use the pin button.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
          sliver: SliverList.builder(
            itemCount: controller.tiles.length,
            itemBuilder: (context, index) {
              final tile = controller.tiles[index];
              final app = controller.appForPackage(tile.packageName);
              return app == null
                  ? const SizedBox.shrink()
                  : _BasicTile(controller: controller, app: app, tile: tile);
            },
          ),
        ),
    ],
  );
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({required this.controller});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) {
    final capabilities = controller.capabilities;
    if (capabilities.isDefaultLauncher && capabilities.hasNotificationAccess) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (!capabilities.isDefaultLauncher)
            OutlinedButton(
              key: const ValueKey('request-home-role'),
              onPressed: controller.requestDefaultLauncher,
              child: const Text('set as home'),
            ),
          if (!capabilities.hasNotificationAccess)
            OutlinedButton(
              key: const ValueKey('request-notification-access'),
              onPressed: controller.openNotificationAccessSettings,
              child: const Text('enable live tiles'),
            ),
        ],
      ),
    );
  }
}

class _BasicTile extends StatelessWidget {
  const _BasicTile({
    required this.controller,
    required this.app,
    required this.tile,
  });

  final LauncherController controller;
  final InstalledApp app;
  final PinnedTile tile;

  @override
  Widget build(BuildContext context) {
    final live = tile.liveEnabled
        ? controller.liveContentFor(tile.packageName)
        : null;
    final height = switch (tile.size) {
      TileSize.small => 72.0,
      TileSize.medium => 116.0,
      TileSize.wide => 148.0,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xff3e65ff),
        child: InkWell(
          key: ValueKey('tile-${tile.packageName}'),
          onTap: () => controller.launchApp(app),
          onLongPress: () => controller.cycleTileSize(tile.packageName),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  LauncherIcon(
                    controller: controller,
                    packageName: app.packageName,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(app.label),
                        if (live != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            live.text ?? live.title ?? 'notification',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (live != null)
                    Text(
                      '${live.notificationCount}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  IconButton(
                    tooltip: 'Unpin ${app.label}',
                    onPressed: () => controller.unpinApp(app.packageName),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppsSurface extends StatelessWidget {
  const _AppsSurface({required this.controller});

  final LauncherController controller;

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const ValueKey('app-list'),
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
    itemCount: controller.apps.length,
    itemBuilder: (context, index) {
      final app = controller.apps[index];
      final pinned = controller.isPinned(app.packageName);
      return ListTile(
        key: ValueKey('app-${app.packageName}'),
        leading: LauncherIcon(
          controller: controller,
          packageName: app.packageName,
          size: 42,
        ),
        title: Text(app.label),
        subtitle: Text(
          app.packageName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white38),
        ),
        onTap: () => controller.launchApp(app),
        trailing: IconButton(
          tooltip: pinned ? 'Unpin ${app.label}' : 'Pin ${app.label}',
          onPressed: () => pinned
              ? controller.unpinApp(app.packageName)
              : controller.pinApp(app.packageName),
          icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
        ),
      );
    },
  );
}
