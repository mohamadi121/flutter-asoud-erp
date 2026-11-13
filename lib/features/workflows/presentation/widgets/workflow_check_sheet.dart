import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../data/workflow_check_repository.dart';
import '../../domain/entities/workflow_definition.dart';
import 'workflow_graph_canvas.dart';

/// Bottom sheet that runs the server-side validity check of a stored
/// workflow and shows the issues; tapping an issue highlights its stage on
/// the diagram.
class WorkflowCheckSheet extends StatefulWidget {
  const WorkflowCheckSheet({
    required this.definition,
    required this.design,
    required this.client,
    super.key,
  });

  final String definition;
  final WorkflowDesign design;
  final FrappeApiClient client;

  @override
  State<WorkflowCheckSheet> createState() => _WorkflowCheckSheetState();
}

class _WorkflowCheckSheetState extends State<WorkflowCheckSheet> {
  late final _repository = WorkflowCheckRepository(widget.client);
  Object? _failure;
  Map<String, dynamic>? _result;
  String? _highlight;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    setState(() {
      _failure = null;
      _result = null;
      _highlight = null;
    });
    try {
      _result = await _repository.validate(widget.definition);
    } catch (error) {
      _failure = error;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final issues = _result == null
        ? const <Map<String, dynamic>>[]
        : (_result!['issues'] as List)
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
    final errors =
        issues.where((issue) => issue['severity'] == 'error').toList();
    final warnings =
        issues.where((issue) => issue['severity'] != 'error').toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          const Text('بررسی اعتبار گردش کار',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
              'بررسی روی نسخهٔ ذخیره‌شدهٔ گردش‌کار انجام می‌شود و چیزی را تغییر نمی‌دهد.',
              style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
          const SizedBox(height: 10),
          SizedBox(
            height: 240,
            child: WorkflowGraphCanvas(
              design: widget.design,
              highlightStage: _highlight,
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
          else if (_result == null)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else
            _ResultList(
              ok: _result!['ok'] as bool,
              errors: errors,
              warnings: warnings,
              onIssue: (issue) {
                final stage = issue['stage'];
                setState(() => _highlight = stage is String ? stage : null);
              },
            ),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.ok,
    required this.errors,
    required this.warnings,
    required this.onIssue,
  });
  final bool ok;
  final List<Map<String, dynamic>> errors;
  final List<Map<String, dynamic>> warnings;
  final void Function(Map<String, dynamic>) onIssue;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ok)
            const _Banner(
              icon: Icons.check_circle_outline_rounded,
              color: AsoudColors.success,
              text: 'گردش‌کار معتبر است و برای اجرا آماده است.',
            )
          else
            const _Banner(
              icon: Icons.error_outline_rounded,
              color: AsoudColors.danger,
              text: 'گردش‌کار هنوز قابل اجرا نیست؛ موارد زیر را برطرف کنید.',
            ),
          if (errors.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 4),
              child: Text('خطاها',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          for (final issue in errors)
            _IssueTile(issue: issue, onIssue: onIssue),
          if (warnings.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 4),
              child: Text('هشدارها',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          for (final issue in warnings)
            _IssueTile(issue: issue, onIssue: onIssue),
        ],
      );
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue, required this.onIssue});
  final Map<String, dynamic> issue;
  final void Function(Map<String, dynamic>) onIssue;

  @override
  Widget build(BuildContext context) {
    final stage = issue['stage'];
    final tappable = stage is String && stage.isNotEmpty;
    return InkWell(
      onTap: tappable ? () => onIssue(issue) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(
            issue['severity'] == 'error'
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            size: 18,
            color: issue['severity'] == 'error'
                ? AsoudColors.danger
                : AsoudColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(issue['message']?.toString() ?? '',
                style: const TextStyle(fontSize: 11, height: 1.5)),
          ),
          if (tappable)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.touch_app_outlined,
                  size: 16, color: AsoudColors.muted),
            ),
        ]),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(
      {required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          border: Border.all(color: color.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 11, color: color))),
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
