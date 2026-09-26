import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../cubit/request_type_builder_cubit.dart';

/// Step 4: roles allowed to submit this request type.
class RequestAccessStep extends StatelessWidget {
  const RequestAccessStep({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RequestTypeBuilderCubit, RequestTypeBuilderState>(
        builder: (context, state) {
          final cubit = context.read<RequestTypeBuilderCubit>();
          final roles = {...state.roles, ...state.initiatorRoles}.toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('دسترسی ثبت درخواست',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('نقش‌هایی که می‌توانند این درخواست را ثبت کنند:',
                style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
            const SizedBox(height: 12),
            if (roles.isEmpty)
              Column(children: [
                const Text('فهرست نقش‌ها دریافت نشد.',
                    style: TextStyle(color: AsoudColors.muted)),
                TextButton(
                    onPressed: cubit.loadRoles,
                    child: const Text('تلاش دوباره')),
              ])
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final role in roles)
                  FilterChip(
                    label: Text(role, style: const TextStyle(fontSize: 11)),
                    selected: state.initiatorRoles.contains(role),
                    onSelected: (selected) => cubit.setInitiatorRoles(selected
                        ? [...state.initiatorRoles, role]
                        : state.initiatorRoles
                            .where((item) => item != role)
                            .toList()),
                  ),
              ]),
          ]);
        },
      );
}
