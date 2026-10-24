import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../data/receipt_confirmation_repository.dart';

/// The two answers to «تأیید دریافت» of an issued piece of equipment: confirm
/// receiving it, or report not receiving it with a reason. Pops `true` when the
/// server accepted the answer so the cartable reloads.
class ReceiptConfirmationBar extends StatefulWidget {
  const ReceiptConfirmationBar({required this.task, super.key});
  final String task;

  @override
  State<ReceiptConfirmationBar> createState() => _ReceiptConfirmationBarState();
}

class _ReceiptConfirmationBarState extends State<ReceiptConfirmationBar> {
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _hasReason => _reason.text.trim().isNotEmpty;

  Future<void> _answer(bool received) async {
    if (_busy) return;
    final repository = context.read<ReceiptConfirmationRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      if (received) {
        await repository.confirm(widget.task);
      } else {
        await repository.reject(widget.task, _reason.text.trim());
      }
      if (navigator.mounted) navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirm = SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: _busy ? null : () => _answer(true),
        child: const Text('تأیید دریافت'),
      ),
    );
    final reject = SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: AsoudColors.danger,
            foregroundColor: Colors.white),
        onPressed: _busy || !_hasReason ? null : () => _answer(false),
        child: const Text('عدم دریافت با ذکر علت',
            textAlign: TextAlign.center),
      ),
    );
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _reason,
          enabled: !_busy,
          minLines: 1,
          maxLines: 3,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'علت عدم دریافت',
            helperText: 'فقط برای «عدم دریافت» نوشتن علت الزامی است.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 360
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: double.infinity, child: confirm),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: reject),
                ])
              : Row(children: [
                  Expanded(child: confirm),
                  const SizedBox(width: 8),
                  Expanded(child: reject),
                ]),
        ),
      ]),
    );
  }
}

/// The server's Persian sentence for a refused answer (417), otherwise the
/// shared failure text for the kind of failure.
String _message(Object error) {
  if (error is ApiException &&
      error.kind == ApiFailureKind.validation &&
      RegExp(r'[؀-ۿ]').hasMatch(error.message)) {
    return error.message;
  }
  return failureMessage(error);
}
