import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../data/repositories/frappe_parties_repository.dart';
import '../../domain/entities/floating_detail.dart';
import '../../domain/repositories/parties_repository.dart';
import '../cubit/floating_details_cubit.dart';
import 'floating_detail_form_page.dart';

class FloatingDetailsPage extends StatelessWidget {
  const FloatingDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FrappePartiesRepository(FrappeClient());
    return BlocProvider(
      create: (_) => FloatingDetailsCubit(repository)..load(),
      child: _FloatingDetailsView(repository: repository),
    );
  }
}

class _FloatingDetailsView extends StatelessWidget {
  const _FloatingDetailsView({required this.repository});
  final PartiesRepository repository;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FloatingDetailsCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('تفصیلی‌های شناور')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.of(context).push<FloatingDetail>(
            MaterialPageRoute(builder: (_) => FloatingDetailFormPage(repository: repository)),
          );
          if (saved != null && context.mounted) context.read<FloatingDetailsCubit>().load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('تفصیلی جدید'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'جست‌وجوی کد یا عنوان'),
            onSubmitted: (value) => context.read<FloatingDetailsCubit>().load(search: value),
          ),
          const SizedBox(height: 14),
          if (state.status == FloatingDetailsStatus.loading)
            const Center(child: CircularProgressIndicator())
          else if (state.status == FloatingDetailsStatus.failure)
            _Failure(message: state.message, onRetry: context.read<FloatingDetailsCubit>().load)
          else if (state.items.isEmpty)
            const Center(child: Text('تفصیلی ثبت نشده است.'))
          else
            ...state.items.map(
              (item) => Card(
                elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(child: Text(item.code.length > 2 ? item.code.substring(0, 2) : item.code)),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${item.code} • ${_typeTitle(item.type)}'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _typeTitle(String value) => switch (value) {
        'Customer' => 'مشتری',
        'Supplier' => 'تأمین‌کننده',
        'Employee' => 'پرسنل',
        'Bank' => 'بانک',
        'Cash' => 'صندوق',
        'Cost Center' => 'مرکز هزینه',
        'Project' => 'پروژه',
        _ => 'سایر',
      };
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40),
          Text(message ?? 'دریافت اطلاعات انجام نشد.', textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
        ],
      );
}
