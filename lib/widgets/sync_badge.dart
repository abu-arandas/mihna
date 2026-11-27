import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../config/breakpoints.dart';
import '../config/theme.dart';
import '../controllers/logbook_controller.dart';
import 'motion.dart';

/// The app bar's word on whether the server has everything: saved, waiting (with how many), offline, or turned
/// down. Tapped, it syncs now; with anything turned down, it says what and why.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final logbook = Get.find<LogbookController>();
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final waiting = logbook.pendingCount.value;
      final refused = logbook.rejected.length;
      final (IconData icon, String label, Color color, int count) = switch ((refused > 0, logbook.syncing.value, logbook.offline.value, waiting > 0)) {
        (true, _, _, _) => (Icons.error_outline, '@count not saved'.trParams({'count': '$refused'}), scheme.error, refused),
        (_, true, _, _) => (Icons.sync, 'Syncing'.tr, scheme.primary, 0),
        (_, _, true, true) => (Icons.cloud_off, '@count waiting for signal'.trParams({'count': '$waiting'}), scheme.onSurfaceVariant, waiting),
        (_, _, true, false) => (Icons.cloud_off, 'Offline'.tr, scheme.onSurfaceVariant, 0),
        (_, _, _, true) => (Icons.cloud_upload_outlined, '@count waiting'.trParams({'count': '$waiting'}), scheme.onSurfaceVariant, waiting),
        _ => (Icons.cloud_done_outlined, 'All saved'.tr, scheme.primary, 0),
      };
      void onTap() => refused > 0 ? unawaited(_showRejected(context, logbook)) : unawaited(logbook.sync());
      final glyph = AnimatedSwitcher(
        duration: reduceMotion(context) ? Duration.zero : AppTheme.fast,
        child: Icon(icon, key: ValueKey(icon), size: 20, color: color),
      );
      // On a phone the app bar has room for the icon and its number only; the words go to the tooltip and screen
      // readers.
      if (context.isMobile) {
        return Semantics(
          liveRegion: true,
          label: label,
          child: IconButton(
            key: const Key('sync-badge'),
            tooltip: '$label · ${'Sync now'.tr}',
            onPressed: onTap,
            icon: Badge(isLabelVisible: count > 0, label: Text('$count'), backgroundColor: color, child: glyph),
          ),
        );
      }
      return Semantics(
        liveRegion: true,
        child: Tooltip(
          message: 'Sync now'.tr,
          child: PressScale(
            child: TextButton.icon(
              key: const Key('sync-badge'),
              onPressed: onTap,
              icon: glyph,
              label: Text(
                label,
                style: TextStyle(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _showRejected(BuildContext context, LogbookController logbook) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The server did not accept these changes'.tr, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final r in logbook.rejected) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.error_outline), title: Text(r.reason.tr)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  unawaited(logbook.dismissRejected());
                  Navigator.of(context).pop();
                },
                child: Text('Got it'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
