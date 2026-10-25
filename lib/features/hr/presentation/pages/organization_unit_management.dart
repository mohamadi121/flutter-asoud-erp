part of 'organization_page.dart';

class _OrganizationUnitManagement extends StatelessWidget {
  const _OrganizationUnitManagement({required this.unit, required this.units,
    required this.canManage, this.initialDelete = false});
  final Map<String, dynamic> unit;
  final List<Map<String, dynamic>> units;
  final bool canManage;
  final bool initialDelete;

  @override
  Widget build(BuildContext context) => _OrgSheetTheme(child: Scaffold(
    backgroundColor: _orgCanvas,
    appBar: const _OrganizationReferenceHeader(title: 'مدیریت ساختار سازمانی', form: true),
    body: _OrganizationFocus(
      units: units, canManage: canManage, initialUnit: '${unit['name']}',
      initialAction: initialDelete ? _OrgEdit.deleteUnit : null,
    ),
  ));
}
