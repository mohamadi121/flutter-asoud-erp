import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/presentation/pages/workflow_designer_page.dart';
import '../cubit/request_type_builder_cubit.dart';

/// Step 3: summary of the stages; the designer edits them.
class RequestWorkflowStep extends StatelessWidget {
  const RequestWorkflowStep({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RequestTypeBuilderCubit, RequestTypeBuilderState>(
        builder: (context, state) {
          final cubit = context.read<RequestTypeBuilderCubit>();
          final design = state.design;
          final stages = [...?design?.stages]
            ..sort((a, b) => a.sequence.compareTo(b.sequence));
          final workflow = design?.workflow ?? state.definition;
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('گردش کار درخواست',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
                'مرحله «تکمیل فرم درخواست» بلافاصله پس از شروع قرار دارد. '
                'مراحل تأیید، شرط و پایان را در طراح گردش کار اضافه کنید.',
                style: TextStyle(
                    fontSize: 11, height: 1.6, color: AsoudColors.muted)),
            const SizedBox(height: 12),
            for (var index = 0; index < stages.length; index++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: AsoudIconBox(
                      icon: _stageIcon(stages[index].type),
                      color: stages[index].configurationComplete
                          ? AsoudColors.success
                          : AsoudColors.warning,
                      size: 34),
                  title: Text(stages[index].title,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      stages[index].configurationComplete
                          ? 'تنظیمات تکمیل شده'
                          : 'نیازمند تکمیل تنظیمات',
                      style: const TextStyle(fontSize: 10)),
                ),
              ),
            if (workflow != null && workflow.isLocked) ...[
              const SizedBox(height: 4),
              Text(
                  workflow.pendingReason ??
                      'برای فعال‌سازی، گردش کار را کامل کنید.',
                  style: const TextStyle(
                      fontSize: 11, color: AsoudColors.warning)),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46)),
              onPressed: workflow == null || state.saving
                  ? null
                  : () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) =>
                              WorkflowDesignerPage(definition: workflow.id)));
                      await cubit.refreshWorkflow();
                    },
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('طراحی گردش کار'),
            ),
          ]);
        },
      );
    }

IconData _stageIcon(WorkflowStageType type) => switch (type) {
      WorkflowStageType.start => Icons.play_arrow_rounded,
      WorkflowStageType.userTask => Icons.edit_note_rounded,
      WorkflowStageType.approval => Icons.fact_check_outlined,
      WorkflowStageType.condition => Icons.call_split_rounded,
      WorkflowStageType.systemAction => Icons.bolt_rounded,
      WorkflowStageType.wait => Icons.hourglass_empty_rounded,
      WorkflowStageType.end => Icons.flag_outlined,
    };