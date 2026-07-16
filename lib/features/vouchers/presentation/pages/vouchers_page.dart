import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../data/repositories/frappe_vouchers_repository.dart';
import '../../domain/entities/accounting_voucher.dart';
import '../cubit/vouchers_cubit.dart';
import 'voucher_form_page.dart';

class VouchersPage extends StatefulWidget {
  const VouchersPage({super.key});
  @override
  State<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends State<VouchersPage> {
  final _company = TextEditingController();
  late final FrappeVouchersRepository _repository;
  late final VouchersCubit _cubit;

  @override
  void initState() {
    super.initState();
    _repository = FrappeVouchersRepository(FrappeClient());
    _cubit = VouchersCubit(_repository);
  }

  @override
  void dispose() {
    _company.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _cubit,
        child: Scaffold(
          appBar: AppBar(title: const Text('اسناد حسابداری')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _company.text.trim().isEmpty ? null : () => _openForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('سند جدید'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                controller: _company,
                decoration: InputDecoration(
                  labelText: 'نام شرکت در ERPNext',
                  suffixIcon: IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _cubit.load(_company.text.trim())),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (value) => _cubit.load(value.trim()),
              ),
              const SizedBox(height: 16),
              Expanded(child: BlocBuilder<VouchersCubit, VouchersState>(builder: (context, state) {
                if (state.status == VouchersStatus.loading) return const Center(child: CircularProgressIndicator());
                if (state.status == VouchersStatus.failure) return Center(child: Text(state.message ?? 'خطا در دریافت اسناد'));
                if (state.items.isEmpty) return const Center(child: Text('نام شرکت را وارد و اسناد را دریافت کنید.'));
                return ListView.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final item = state.items[index];
                    return Card(child: ListTile(
                      leading: CircleAvatar(child: Icon(_statusIcon(item.status))),
                      title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${item.id}\nبدهکار: ${item.totalDebit.toStringAsFixed(0)}  |  بستانکار: ${item.totalCredit.toStringAsFixed(0)}'),
                      isThreeLine: true,
                      trailing: Text(_statusTitle(item.status)),
                      onTap: switch (item.status) {
                        VoucherStatus.draft || VoucherStatus.rejected => () => _openForm(item),
                        VoucherStatus.pendingApproval => () => _showApprovalActions(item),
                        VoucherStatus.approved => null,
                      },
                    ));
                  },
                );
              })),
            ]),
          ),
        ),
      );

  Future<void> _openForm([AccountingVoucher? voucher]) async {
    final value = voucher ?? AccountingVoucher(
      company: _company.text.trim(),
      postingDate: DateTime.now(),
      description: '',
      lines: const [VoucherLine(account: ''), VoucherLine(account: '')],
    );
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VoucherFormPage(repository: _repository, voucher: value)));
    if (mounted) await _cubit.load(_company.text.trim());
  }

  Future<void> _showApprovalActions(AccountingVoucher voucher) async {
    await showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(voucher.description, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('بدهکار و بستانکار: ${voucher.totalDebit.toStringAsFixed(0)}'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () { Navigator.pop(sheetContext); _cubit.approve(voucher.id); }, icon: const Icon(Icons.check_rounded), label: const Text('تأیید و ثبت قطعی در ERPNext')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () { Navigator.pop(sheetContext); _reject(voucher.id); }, icon: const Icon(Icons.close_rounded), label: const Text('رد سند')),
      ]),
    )));
  }

  Future<void> _reject(String id) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('دلیل رد سند'),
      content: TextField(controller: controller, minLines: 2, maxLines: 4, decoration: const InputDecoration(hintText: 'دلیل رد را بنویسید')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('ثبت رد')),
      ],
    ));
    controller.dispose();
    if (reason != null && reason.length >= 3) await _cubit.reject(id, reason);
  }

  static IconData _statusIcon(VoucherStatus value) => switch (value) {
        VoucherStatus.draft => Icons.edit_note_rounded,
        VoucherStatus.pendingApproval => Icons.hourglass_top_rounded,
        VoucherStatus.approved => Icons.verified_rounded,
        VoucherStatus.rejected => Icons.cancel_rounded,
      };
  static String _statusTitle(VoucherStatus value) => switch (value) {
        VoucherStatus.draft => 'پیش‌نویس',
        VoucherStatus.pendingApproval => 'در انتظار تأیید',
        VoucherStatus.approved => 'تأییدشده',
        VoucherStatus.rejected => 'ردشده',
      };
}
