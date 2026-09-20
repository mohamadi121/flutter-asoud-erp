import 'package:flutter/material.dart';
import '../../../../core/widgets/asoud_form.dart';

class PersonnelRolesPage extends StatefulWidget {
  const PersonnelRolesPage(
      {this.initialValue = const {},
      this.employeeName = '',
      this.employeeCode = '',
      this.mobile = '',
      this.onConfirm,
      this.initialStep = 1,
      super.key});
  final Set<String> initialValue;
  final String employeeName, employeeCode, mobile;
  final Future<void> Function(Set<String>, Map<String, List<String>>)?
      onConfirm;
  final int initialStep;
  @override
  State<PersonnelRolesPage> createState() => _PersonnelRolesPageState();
}

class _PersonnelRolesPageState extends State<PersonnelRolesPage> {
  static const roles = {
    'employee': 'کارمند',
    'office_manager': 'مدیر حسابداری',
    'accountant': 'حسابدار',
    'salesperson': 'فروشنده',
    'marketer': 'بازاریاب',
    'cashier': 'صندوق‌دار',
    'petty_cash_custodian': 'تنخواه‌گردان'
  };
  static const legacy = {
    'مدیر': 'office_manager',
    'حسابدار': 'accountant',
    'فروشنده': 'salesperson',
    'بازاریاب': 'marketer',
    'صندوق': 'cashier',
    'تنخواه‌گردان': 'petty_cash_custodian'
  };
  late final selected = widget.initialValue
      .map((value) => legacy[value] ?? value)
      .where(roles.containsKey)
      .toSet();
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  Future<void> save() async {
    if (saving) return;
    if (selected.isEmpty) {
      setState(() => error = 'حداقل یک نقش انتخاب کنید.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onConfirm?.call({...selected}, {});
      if (mounted) Navigator.pop(context, selected);
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'ذخیره دسترسی انجام نشد؛ مجوز و اتصال را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AsoudFormPage(
          title: 'نقش و دسترسی',
          subtitle: widget.employeeName,
          formKey: formKey,
          saving: saving,
          error: error,
          onSave: save,
          children: [
            AsoudFormSection(title: 'نقش‌های استاندارد', children: [
              for (final role in roles.entries)
                CheckboxListTile(
                    title: Text(role.value),
                    value: selected.contains(role.key),
                    onChanged: saving
                        ? null
                        : (value) => setState(() {
                              value == true
                                  ? selected.add(role.key)
                                  : selected.remove(role.key);
                            }))
            ]),
            const AsoudFormSection(title: 'مجوزهای پیشرفته', children: [
              Text(
                  'مجوزهای جزئی هنوز قابل تنظیم نیستند. دسترسی با نقش‌های استاندارد اعمال می‌شود؛ مدیر فقط مجاز به واگذاری نقش‌های مورد تأیید سرور است.')
            ]),
          ]);
}
