part of 'roles_page.dart';

/// Per-role summary sheet: shows the role's metadata and only the actions the
/// current user may take. Opened by tapping a role row.
Future<void> _showRoleSummary(
  BuildContext context,
  ManagedRole role, {
  required bool canManage,
}) {
  final cubit = context.read<RoleCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: cubit,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: _RoleSummarySheet(role: role, canManage: canManage),
      ),
    ),
  );
}

class _RoleSummarySheet extends StatelessWidget {
  const _RoleSummarySheet({required this.role, required this.canManage});
  final ManagedRole role;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    // The sheet re-reads the role from the cubit so a rename or a save in
    // another screen is reflected without reopening it.
    final code = role.code;
    final fallback = role;
    return BlocBuilder<RoleCubit, RoleState>(builder: (context, state) {
        final role = state.catalog.roles
                .where((r) => r.code == code)
                .firstOrNull ??
            fallback;
        final catalog = state.catalog;
        final categoryTitle = catalog.categories
                .where((c) => c.code == role.category)
                .map((c) => c.title)
                .firstOrNull ??
            '';
        final baseSummary = role.baseRoles.isEmpty
            ? switch (role.completion) {
                'complete' => 'دسترسی‌های اختصاصی نقش',
                'incomplete' => 'بدون مجوز',
                _ => 'بدون نقش پایه',
              }
            : role.baseRoles.map((name) {
                final match =
                    catalog.baseRoles.where((b) => b.name == name).firstOrNull;
                return (match != null && match.title.isNotEmpty)
                    ? match.title
                    : persianRoleLabel(name);
              }).join('، ');
        final canEdit = canManage && !role.system;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            key: const Key('role_summary_sheet'),
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: ListView(
              // Sizing to the content keeps the sheet compact; it still
              // scrolls when the content exceeds the 80% cap.
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        persianRoleLabel(
                            role.title.isNotEmpty ? role.title : role.code),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (role.system)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AsoudColors.purple.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('نقش سیستمی',
                            style: TextStyle(
                                fontSize: 11, color: AsoudColors.purple)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  role.description.isNotEmpty ? role.description : 'بدون توضیح',
                  style: const TextStyle(
                      fontSize: 13, color: AsoudColors.muted, height: 1.5),
                ),
                const SizedBox(height: 16),
                _summaryRow(
                    'دسته', categoryTitle.isEmpty ? 'بدون دسته' : categoryTitle),
                _statusRow(role),
                if (role.needsCompletion && canEdit) ...[
                  const SizedBox(height: 4),
                  const Text('این نقش هنوز مجوزی ندارد.',
                      style: TextStyle(
                          fontSize: 12, color: AsoudColors.warning)),
                  const SizedBox(height: 8),
                  _summaryAction(
                    icon: Icons.key_outlined,
                    label: 'تکمیل مجوزها',
                    // The role-wide editor, not the per-user list. The editor
                    // does not go through cubit.save, so reload it here.
                    onTap: () async {
                      await _roleRoute<void>(
                          context,
                          _AccessWizard(
                              role: role,
                              repository: UserAccessRepository(
                                  context.read<RoleCubit>().repository.client),
                              shared: true));
                      if (context.mounted) context.read<RoleCubit>().load();
                    },
                  ),
                ],
                _summaryRow('کاربران', formatCount(role.assignedUsers, 'کاربر')),
                _summaryRow('مجوزها', baseSummary),
                const SizedBox(height: 20),
                _summaryAction(
                  icon: Icons.visibility_outlined,
                  label: 'جزئیات و دسترسی‌ها',
                  onTap: () => _roleRoute<void>(
                      context,
                      _RolePermissions(role: role, canManage: canManage)),
                ),
                _summaryAction(
                  icon: Icons.people_outline,
                  label: 'کاربران اختصاص‌یافته',
                  onTap: () => _roleRoute<void>(
                      context,
                      UserAccessPage(
                          role: role,
                          repository: UserAccessRepository(
                              context.read<RoleCubit>().repository.client))),
                ),
                if (canEdit)
                  _summaryAction(
                    icon: Icons.edit_outlined,
                    label: 'ویرایش مشخصات',
                    onTap: () => _roleRoute<bool>(context, _RoleForm(role: role)),
                  ),
              ],
            ),
          ),
        );
      });
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: AsoudColors.muted)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  /// «وضعیت» row: the enabled state plus the completion badge when present.
  Widget _statusRow(ManagedRole role) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 72,
              child: Text('وضعیت',
                  style: TextStyle(fontSize: 13, color: AsoudColors.muted)),
            ),
            Text(role.enabled ? 'فعال' : 'غیرفعال',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            if (role.completion != null) ...[
              const SizedBox(width: 8),
              _roleStatusLabel(role),
            ],
          ],
        ),
      );

  Widget _summaryAction(
          {required IconData icon,
          required String label,
          required VoidCallback onTap}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: AsoudColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  border: Border.all(color: AsoudColors.border),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(icon, size: 20, color: AsoudColors.primary),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_left,
                    size: 20, color: AsoudColors.muted),
              ]),
            ),
          ),
        ),
      );
}
