import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../workflows/domain/entities/workflow_definition.dart';
import '../../../workflows/domain/repositories/workflow_repository.dart';
import '../cubit/request_type_builder_cubit.dart';
import '../widgets/request_access_step.dart';
import '../widgets/request_form_step.dart';
import '../widgets/request_info_step.dart';
import '../widgets/request_workflow_step.dart';

/// Four-step builder: general info, request form, workflow and access.
class RequestTypeBuilderPage extends StatelessWidget {
  const RequestTypeBuilderPage({this.company, this.existing, super.key});
  final String? company;
  final WorkflowDefinition? existing;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => RequestTypeBuilderCubit(
            repository: context.read<WorkflowRepository>(),
            company: company,
            existing: existing)
          ..load(),
        child: const _BuilderView(),
      );
}

class _BuilderView extends StatefulWidget {
  const _BuilderView();
  @override
  State<_BuilderView> createState() => _BuilderViewState();
}

class _BuilderViewState extends State<_BuilderView> {
  final infoForm = GlobalKey<FormState>();

  void _primary(RequestTypeBuilderCubit cubit, int step) {
    switch (step) {
      case 0:
        if (infoForm.currentState?.validate() ?? false) cubit.saveInfo();
      case 1:
        cubit.saveForm();
      case 2:
        cubit.continueToAccess();
      default:
        cubit.saveAccess();
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<RequestTypeBuilderCubit, RequestTypeBuilderState>(
        listenWhen: (previous, current) =>
            (current.message != null && previous.message != current.message) ||
            (!previous.completed && current.completed),
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
          }
          if (state.completed) Navigator.of(context).pop(true);
        },
        builder: (context, state) {
          final cubit = context.read<RequestTypeBuilderCubit>();
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AsoudHeader(
                  title: state.isEditing
                      ? 'ویرایش نوع درخواست'
                      : 'ایجاد نوع درخواست جدید'),
              body: Column(children: [
                RequestStepIndicator(step: state.step),
                Expanded(
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : switch (state.step) {
                          0 => RequestInfoStep(formKey: infoForm),
                          1 => const RequestFormStep(),
                          2 => const RequestWorkflowStep(),
                          _ => const RequestAccessStep(),
                        },
                ),
              ]),
              bottomNavigationBar: AsoudBottomActions(
                primaryLabel: state.saving
                    ? 'در حال ذخیره...'
                    : state.step == 3
                        ? 'ذخیره و پایان'
                        : 'ادامه',
                onPrimary: state.saving || state.loading
                    ? null
                    : () => _primary(cubit, state.step),
                secondaryLabel: state.step > 0 ? 'بازگشت' : null,
                onSecondary: state.saving ? null : cubit.back,
              ),
            ),
          );
        },
      );
    }

class RequestStepIndicator extends StatelessWidget {
  const RequestStepIndicator({required this.step, super.key});
  final int step;

  static const labels = ['اطلاعات کلی', 'فرم درخواست', 'گردش کار', 'دسترسی'];

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
        child: Row(children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: _StepDot(
                  index: index,
                  step: step,
                  label: labels[index],
                  last: index == labels.length - 1),
            ),
        ]),
      );
}

class _StepDot extends StatelessWidget {
  const _StepDot(
      {required this.index,
      required this.step,
      required this.label,
      required this.last});
  final int index, step;
  final String label;
  final bool last;

  Widget _line(bool visible, bool reached) => Expanded(
        child: Container(
          height: 2,
          color: !visible
              ? Colors.transparent
              : reached
                  ? AsoudColors.primary
                  : AsoudColors.border,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final done = index < step, current = index == step;
    final color = done || current ? AsoudColors.primary : AsoudColors.muted;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _line(index > 0, index <= step),
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: current ? AsoudColors.primary : AsoudColors.surface,
            border: Border.all(
                color:
                    done || current ? AsoudColors.primary : AsoudColors.border,
                width: 1.5),
          ),
          child: done
              ? const Icon(Icons.check_rounded,
                  size: 16, color: AsoudColors.primary)
              : Text('۱۲۳۴'[index],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: current ? Colors.white : AsoudColors.muted)),
        ),
        _line(!last, index < step),
      ]),
      const SizedBox(height: 4),
      Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: current ? FontWeight.w800 : FontWeight.w500)),
    ]);
  }
}
