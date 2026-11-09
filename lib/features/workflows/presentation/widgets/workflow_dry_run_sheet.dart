import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/persian_server_values.dart';
import '../../data/workflow_check_repository.dart';
import '../../domain/entities/workflow_definition.dart';
import 'workflow_graph_canvas.dart';

/// Persian label for a simulation action code (same codes the backend
/// `ACTION_LABELS` uses).
String dryRunActionLabel(String action) => switch (action) {
      'Approve' => 'تأیید',
      'Reject' => 'رد',
      'Return' => 'بازگشت برای اصلاح',
      'Complete' => 'انجام',
      'Success' => 'موفق',
      'Error' => 'خطا',
      'True' => 'درست',
      'False' => 'نادرست',
      _ => action,
    };

/// Bottom sheet that walks the stored workflow step by step with the
/// server-side simulation; nothing is written on the server.
class WorkflowDryRunSheet extends StatefulWidget {
  const WorkflowDryRunSheet({
    required this.definition,
    required this.design,
    required this.client,
    super.key,
  });

  final String definition;
  final WorkflowDesign design;
  final FrappeApiClient client;

  @override
  State<WorkflowDryRunSheet> createState() => _WorkflowDryRunSheetState();
}

class _WorkflowDryRunSheetState extends State<WorkflowDryRunSheet> {
  late final _repository = WorkflowCheckRepository(widget.client);
  final _decisions = <Map<String, String>>[];
  Map<String, dynamic>? _result;
  Object? _failure;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    setState(() => _failure = null);
    try {
      _result = await _repository.simulate(widget.definition, _decisions);
    } catch (error) {
      _failure = error;
    }
    if (mounted) setState(() {});
    _running = false;
  }

  void _choose(String action) {
    final waiting = _result?['waiting_stage'];
    if (waiting is! String || waiting.isEmpty) return;
    _decisions.add({'stage': waiting, 'action': action});
    _run();
  }

  void _restart() {
    _decisions.clear();
    _run();
  }

  String? get _activeStage {
    final result = _result;
    if (result == null) return null;
    final waiting = result['waiting_stage'];
    if (waiting is String && waiting.isNotEmpty) return waiting;
    final steps = result['steps'] as List;
    if (steps.isEmpty) return null;
    final last = steps.last;
    return last is Map ? last['stage']?.toString() : null;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final steps = result == null
        ? const <Map<String, dynamic>>[]
        : (result['steps'] as List)
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
    final status = result?['status']?.toString();
    final waiting = result?['waiting_stage'];
    final allowed = result == null
        ? const <String>[]
        : (result['allowed_actions'] as List)
              .map((value) => value.toString())
              .toList();
    final outcome = result?['outcome']?.toString();
    final errors = result == null
        ? const <String>[]
        : (result['errors'] as List).map((value) => value.toString()).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          const Text('اجرای آزمایشی فرایند',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
              'این فقط یک شبیه‌سازی است؛ هیچ درخواست، وظیفه یا اعلانی ایجاد نمی‌شود.',
              style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: WorkflowGraphCanvas(
              design: widget.design,
              highlightStage: _activeStage,
              onOpenStage: (_) {},
              onMoveStage: (_, __, ___) {},
              onMoveEnd: () {},
              onInsertOnTransition: (_) {},
              onCreateTransition: (_) {},
            ),
          ),
          const Divider(height: 20),
          if (_failure != null)
            _Failure(message: failureDetail(_failure), onRetry: _run)
          else if (result == null)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else ...[
            if (steps.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('هنوز مرحله‌ای طی نشده است.',
                    style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
              )
            else
              for (final step in steps) _StepTile(step: step),
            if (status == 'needs_decision' &&
                waiting is String &&
                waiting.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 6),
                child: Text('تصمیم این مرحله را انتخاب کنید',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allowed
                    .map((action) => FilledButton(
                          onPressed: _running ? null : () => _choose(action),
                          child: Text(dryRunActionLabel(action)),
                        ))
                    .toList(growable: false),
              ),
            ],
            if (status == 'finished' && outcome != null)
              _OutcomeBanner(
                  text: 'نتیجهٔ فرایند: ${persianWorkflowStatus(outcome)}'),
            if (status == 'error') ...[
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 4),
                child: Text('خطاها',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              for (final error in errors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(error,
                      style: const TextStyle(
                          fontSize: 11, color: AsoudColors.danger)),
                ),
            ],
            if (_decisions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: _running ? null : _restart,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('اجرای دوباره'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});
  final Map<String, dynamic> step;
  @override
  Widget build(BuildContext context) {
    final action = step['action']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AsoudColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.play_circle_outline_rounded,
            size: 18, color: AsoudColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
              '${step['title']?.toString() ?? ''}${action == null ? '' : ' — ${dryRunActionLabel(action)}'}',
              style: const TextStyle(fontSize: 11)),
        ),
      ]),
    );
  }
}

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AsoudColors.success.withValues(alpha: .07),
          border: Border.all(color: AsoudColors.success.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.flag_rounded,
              color: AsoudColors.success, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 11, color: AsoudColors.success))),
        ]),
      );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش دوباره'),
            ),
          ]),
        ),
      );
}
