import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../config/theme.dart';
import 'motion.dart';

/// What a list shows when it has nothing in it: the icon pops in, then the words settle under it.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.title, this.message, super.key});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          PopIn(child: Icon(icon, size: 48, color: scheme.outline)),
          const SizedBox(height: 12),
          Appear(
            delay: AppTheme.stagger * 2,
            child: Text(title.tr, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Appear(
              delay: AppTheme.stagger * 3,
              child: Text(
                message!.tr,
                style: TextStyle(color: scheme.outline),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
