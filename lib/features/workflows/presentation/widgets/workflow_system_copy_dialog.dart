import 'package:flutter/material.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/utils/failure_message.dart';
import '../../data/workflow_template_repository.dart';
import '../../domain/entities/workflow_definition.dart';

/// Asks for a copy title, then creates an independent draft from a system
/// workflow. Returns the created draft, or null when the user cancels.
class WorkflowSystemCopyDialog extends StatefulWidget {
  const WorkflowSystemCopyDialog(
      {required this.source, required this.client, super.key});
  final WorkflowDefinition source;
  final FrappeApiClient client;

  @override
  State<WorkflowSystemCopyDialog> createState() =>
      _WorkflowSystemCopyDialogState();
}

class _WorkflowSystemCopyDialogState extends State<WorkflowSystemCopyDialog> {
  late final title = TextEditingController(text: '${widget.source.title} - کپی');
  bool busy = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (busy) return;
    final name = title.text.trim();
    if (name.length < 3) {
      setState(() => error = 'عنوان کپی باید دست‌کم سه نویسه باشد.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final created = await WorkflowTemplateRepository(widget.client).copyFromWorkflow(
          company: widget.source.company ?? '',
          source: widget.source,
          title: name,
          description: widget.source.description ?? '',
          icon: widget.source.iconKey ?? 'hub',
          color: widget.source.colorHex ?? '#315CF5');
      if (mounted) Navigator.pop(context, created);
    } catch (failure) {
      if (mounted) setState(() => error = failureDetail(failure));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
          canPop: !busy,
          child: AlertDialog(
              title: const Text('ایجاد کپی مستقل'),
              content: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'الگوی سیستمی بدون تغییر می‌ماند؛ نسخهٔ کپی ابتدا پیش‌نویس است و تا فعال‌سازی صریح روی درخواست‌ها اعمال نمی‌شود.'),
                    const SizedBox(height: 16),
                    TextField(
                        controller: title,
                        enabled: !busy,
                        maxLength: 140,
                        hintLocales: const [Locale('fa')],
                        decoration: const InputDecoration(
                            labelText: 'عنوان کپی *')),
                    if (error != null)
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ]))),
              actions: [
                TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('انصراف')),
                FilledButton(
                    onPressed: busy ? null : _create,
                    child: Text(busy ? 'در حال ایجاد…' : 'ایجاد کپی'))
              ])));
}
