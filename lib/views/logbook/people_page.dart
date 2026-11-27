import 'dart:async';

import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/breakpoints.dart';
import '../../config/theme.dart';
import '../../controllers/workshop_controller.dart';
import '../../models/membership.dart';
import '../../models/role.dart';
import '../../widgets/motion.dart';

/// The admin's page: who is in the workshop and their role, adding someone by the email of their account, and
/// taking someone out.
class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  var _role = Role.trainee;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final added = await Get.find<WorkshopController>().addMember(_email.text, _role, _name.text);
    if (added) {
      _email.clear();
      _name.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workshops = Get.find<WorkshopController>();
    final theme = Theme.of(context);
    final me = workshops.current.value?.userId;
    return RefreshIndicator(
      onRefresh: workshops.loadMembers,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          GridContainer(
            child: GridRow(
              children: [
                GridCol(child: Text('Add someone'.tr, style: theme.textTheme.titleLarge)),
                GridCol(
                  child: Text(
                    'They create an account first, with the same email. Then add them here.'.tr,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                GridCol(
                  md: 5,
                  child: TextField(
                    key: const Key('member-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'Email'.tr),
                  ),
                ),
                GridCol(
                  md: 4,
                  child: TextField(
                    key: const Key('member-name'),
                    controller: _name,
                    decoration: InputDecoration(labelText: 'Name'.tr),
                  ),
                ),
                GridCol(
                  md: 3,
                  child: DropdownButtonFormField<Role>(
                    initialValue: _role,
                    decoration: InputDecoration(labelText: 'Role'.tr),
                    items: [for (final r in Role.values) DropdownMenuItem(value: r, child: Text(_roleName(r)))],
                    onChanged: (r) => setState(() => _role = r ?? Role.trainee),
                  ),
                ),
                GridCol(
                  child: Obx(() {
                    final error = workshops.error.value;
                    final notice = workshops.notice.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (error != null) Text(error.tr, style: TextStyle(color: theme.colorScheme.error)),
                        if (notice != null) Text(notice.tr, style: TextStyle(color: theme.colorScheme.primary)),
                        const SizedBox(height: 8),
                        PressScale(
                          child: FilledButton.icon(
                            key: const Key('add-member'),
                            onPressed: workshops.busy.value ? null : () => unawaited(_add()),
                            icon: const Icon(Icons.person_add_alt),
                            label: Text('Add to the workshop'.tr),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          GridContainer(child: Text('In this workshop'.tr, style: theme.textTheme.titleLarge)),
          const SizedBox(height: 4),
          Obx(
            () => Column(
              children: [
                for (final m in workshops.members)
                  GridContainer(
                    child: ListTile(
                      shape: AppTheme.shape(14),
                      leading: CircleAvatar(child: Text(m.displayName.characters.first)),
                      title: Text(m.displayName),
                      subtitle: Text(_roleName(m.role)),
                      trailing: m.userId == me
                          ? null
                          : IconButton(
                              tooltip: 'Remove from the workshop'.tr,
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () => unawaited(_confirmRemove(context, m)),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, Membership m) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove @name?'.trParams({'name': m.displayName})),
        content: Text('Their skill records in this workshop are deleted too.'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Keep'.tr)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Remove'.tr)),
        ],
      ),
    );
    if (yes ?? false) await Get.find<WorkshopController>().removeMember(m);
  }
}

String _roleName(Role r) => switch (r) {
  Role.trainee => 'Trainee'.tr,
  Role.supervisor => 'Supervisor'.tr,
  Role.admin => 'Admin'.tr,
};
