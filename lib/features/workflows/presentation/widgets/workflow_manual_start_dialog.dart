import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/utils/failure_message.dart';
import '../../data/repositories/workflow_start_execution_repository.dart';

/// The initiator enters a reason now; no designer-supplied fixed reason is used.
class WorkflowManualStartDialog extends StatefulWidget {
  const WorkflowManualStartDialog(
      {required this.definition, required this.client, super.key});
  final String definition;
  final FrappeApiClient client;
  @override
  State<WorkflowManualStartDialog> createState() =>
      _WorkflowManualStartDialogState();
}

class _WorkflowManualStartDialogState extends State<WorkflowManualStartDialog> {
  final subject = TextEditingController(), reason = TextEditingController();
  bool busy = false, unknown = false;
  String? error;
  @override
  void dispose() {
    subject.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> start() async {
    if (busy || unknown) return;
    if (subject.text.trim().length < 3 || reason.text.trim().isEmpty) {
      setState(() => error = 'عنوان حداقل سه نویسه و علت شروع را وارد کنید.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final instance = await WorkflowStartExecutionRepository(widget.client)
          .start(
              definition: widget.definition,
              subject: subject.text.trim(),
              reason: reason.text.trim());
      if (mounted) {
        Navigator.pop(context, instance);
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          unknown = failure is! ApiException ||
              const {
                ApiFailureKind.timeout,
                ApiFailureKind.network,
                ApiFailureKind.protocol,
                ApiFailureKind.server,
                ApiFailureKind.cancelled,
                ApiFailureKind.responseTooLarge
              }.contains(failure.kind);
          error = unknown
              ? 'نتیجهٔ شروع هنوز مشخص نیست؛ پیش از شروع دوباره، فهرست اجراها را بررسی کنید.'
              : failureDetail(failure);
        });
      }
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
              title: const Text('شروع دستی گردش کار'),
              content: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: subject,
                        enabled: !busy && !unknown,
                        maxLength: 140,
                        hintLocales: const [Locale('fa')],
                        decoration: const InputDecoration(
                            labelText: 'عنوان اجرای گردش کار *')),
                    const SizedBox(height: 16),
                    TextField(
                        controller: reason,
                        enabled: !busy && !unknown,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 1000,
                        hintLocales: const [Locale('fa')],
                        decoration: const InputDecoration(
                            labelText: 'علت شروع گردش کار *',
                            hintText: 'علت شروع دستی را وارد کنید…')),
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
                    onPressed: busy || unknown ? null : start,
                    child: Text(busy ? 'در حال شروع…' : 'شروع گردش کار'))
              ])));
}
