import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/workflow_definition.dart';
import '../cubit/workflow_designer_cubit.dart';

class WorkflowEndSettingsPage extends StatefulWidget {
  const WorkflowEndSettingsPage({required this.stage, super.key});
  final WorkflowStage stage;

  @override
  State<WorkflowEndSettingsPage> createState() =>
      _WorkflowEndSettingsPageState();
}

class _WorkflowEndSettingsPageState extends State<WorkflowEndSettingsPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController message;
  late String outcome;
  bool saving = false;
  static const outcomes = {
    'Completed': 'تکمیل موفق',
    'Rejected': 'رد نهایی',
    'Cancelled': 'لغو فرایند',
    'Stopped': 'توقف فرایند (بدون موفقیت)',
  };

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.stage.title);
    message = TextEditingController(
        text: widget.stage.config['result_label']?.toString() ?? '');
    final saved = widget.stage.config['outcome']?.toString();
    outcome = outcomes.containsKey(saved) ? saved! : 'Completed';
  }

  @override
  void dispose() {
    title.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) {
      return;
    }
    setState(() => saving = true);
    final saved = await context.read<WorkflowDesignerCubit>().saveStage(
      widget.stage,
      {
        ...widget.stage.config,
        'title': title.text.trim(),
        'outcome': outcome,
        'result_label': message.text.trim(),
      },
    );
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ذخیره انجام نشد؛ دوباره تلاش کنید.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const AsoudHeader(
            title: 'پایان عملیات',
            subtitle: 'نتیجه نهایی گردش کار را مشخص کنید',
          ),
          body: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (context.watch<WorkflowDesignerCubit>().state.offlinePreview)
                  const AsoudOfflinePreviewBanner(),
                Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: ListTile(
                    leading: const AsoudIconBox(
                      icon: Icons.stop_circle_outlined,
                      color: AsoudColors.primary,
                    ),
                    title: const Text('پایان گردش کار'),
                    subtitle:
                        const Text('این مرحله مسیر جاری فرایند را می‌بندد.'),
                  ),
                ),
                TextFormField(
                  controller: title,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'عنوان مرحله *'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'عنوان مرحله را وارد کنید.'
                      : null,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: outcome,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'نتیجه نهایی *'),
                  items: outcomes.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => outcome = value);
                          }
                        },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: message,
                  enabled: !saving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'پیام نتیجه (اختیاری)',
                    hintText: 'توضیح کوتاه درباره پایان فرایند',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'پایان موفق به‌تنهایی سند ایجاد یا ثبت قطعی نمی‌کند. '
                  'برای ایجاد سند، اقدام مربوط به آن را پیش از پایان قرار دهید؛ '
                  'ثبت قطعی تابع مجوزها و قواعد ماژول سند است.',
                  style: TextStyle(color: AsoudColors.muted, height: 1.7),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: AsoudBottomActions(
              primaryLabel: saving ? 'در حال ذخیره…' : 'ذخیره تنظیمات پایان',
              onPrimary: saving ? null : save,
              secondaryLabel: 'انصراف',
              onSecondary: saving ? null : () => Navigator.maybePop(context),
            ),
          ),
        ),
      );
}
