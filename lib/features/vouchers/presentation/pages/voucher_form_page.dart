import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/accounting_voucher.dart';
import '../../domain/repositories/vouchers_repository.dart';
import '../cubit/voucher_form_cubit.dart';

class VoucherFormPage extends StatefulWidget {
  const VoucherFormPage({required this.repository, required this.voucher, super.key});
  final VouchersRepository repository;
  final AccountingVoucher voucher;
  @override
  State<VoucherFormPage> createState() => _VoucherFormPageState();
}

class _VoucherFormPageState extends State<VoucherFormPage> {
  late final VoucherFormCubit _cubit;
  late final TextEditingController _description;
  late List<_LineControllers> _rows;

  @override
  void initState() {
    super.initState();
    _cubit = VoucherFormCubit(widget.repository, widget.voucher);
    _description = TextEditingController(text: widget.voucher.description);
    _rows = widget.voucher.lines.map(_LineControllers.fromLine).toList();
  }

  @override
  void dispose() {
    _cubit.close();
    _description.dispose();
    for (final row in _rows) row.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _cubit,
        child: BlocConsumer<VoucherFormCubit, VoucherFormState>(
          listener: (context, state) {
            if (state.status == VoucherFormStatus.success) Navigator.of(context).pop();
            if (state.status == VoucherFormStatus.failure) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message ?? 'ذخیره سند ناموفق بود')));
          },
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: Text(widget.voucher.id.isEmpty ? 'ایجاد سند حسابداری' : 'ویرایش سند حسابداری')),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                TextFormField(initialValue: state.voucher.company, enabled: false, decoration: const InputDecoration(labelText: 'شرکت')),
                TextField(controller: _description, decoration: const InputDecoration(labelText: 'شرح سند *'), onChanged: (_) => _sync()),
              ]))),
              const SizedBox(height: 12),
              ...List.generate(_rows.length, (index) => _lineCard(index)),
              OutlinedButton.icon(onPressed: _addRow, icon: const Icon(Icons.add_rounded), label: const Text('افزودن ردیف')),
              const SizedBox(height: 12),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                _totalRow('جمع بدهکار', state.voucher.totalDebit),
                _totalRow('جمع بستانکار', state.voucher.totalCredit),
                const Divider(),
                Row(children: [
                  Icon(state.voucher.isBalanced ? Icons.check_circle : Icons.error, color: state.voucher.isBalanced ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Text(state.voucher.isBalanced ? 'سند تراز است' : 'جمع بدهکار و بستانکار برابر نیست'),
                ]),
              ]))),
              const SizedBox(height: 20),
              FilledButton(onPressed: state.canSave ? () => _cubit.save() : null, child: const Text('ذخیره پیش‌نویس')),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: state.canSave ? () => _cubit.save(submit: true) : null, child: const Text('ذخیره و ارسال برای تأیید')),
            ]),
          ),
        ),
      );

  Widget _lineCard(int index) {
    final row = _rows[index];
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      Row(children: [Expanded(child: Text('ردیف ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800))), if (_rows.length > 2) IconButton(onPressed: () => _removeRow(index), icon: const Icon(Icons.delete_outline_rounded))]),
      TextField(controller: row.account, decoration: const InputDecoration(labelText: 'حساب معین/تفصیلی *'), onChanged: (_) => _sync()),
      TextField(controller: row.floatingDetail, decoration: const InputDecoration(labelText: 'تفصیلی شناور'), onChanged: (_) => _sync()),
      TextField(controller: row.description, decoration: const InputDecoration(labelText: 'شرح ردیف'), onChanged: (_) => _sync()),
      Row(children: [
        Expanded(child: TextField(controller: row.debit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'بدهکار'), onChanged: (_) => _sync())),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: row.credit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'بستانکار'), onChanged: (_) => _sync())),
      ]),
    ])));
  }

  Widget _totalRow(String title, double value) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title), Text(value.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800))]);
  double _number(String value) => double.tryParse(value.replaceAll(',', '')) ?? 0;
  void _sync() {
    _cubit.updateHeader(description: _description.text);
    _cubit.replaceLines(_rows.map((row) => VoucherLine(account: row.account.text.trim(), floatingDetail: row.floatingDetail.text.trim(), description: row.description.text.trim(), debit: _number(row.debit.text), credit: _number(row.credit.text))).toList());
  }
  void _addRow() => setState(() { _rows.add(_LineControllers.fromLine(const VoucherLine(account: ''))); _sync(); });
  void _removeRow(int index) => setState(() { _rows.removeAt(index).dispose(); _sync(); });
}

class _LineControllers {
  _LineControllers.fromLine(VoucherLine line)
      : account = TextEditingController(text: line.account),
        floatingDetail = TextEditingController(text: line.floatingDetail),
        description = TextEditingController(text: line.description),
        debit = TextEditingController(text: line.debit == 0 ? '' : line.debit.toStringAsFixed(0)),
        credit = TextEditingController(text: line.credit == 0 ? '' : line.credit.toStringAsFixed(0));
  final TextEditingController account;
  final TextEditingController floatingDetail;
  final TextEditingController description;
  final TextEditingController debit;
  final TextEditingController credit;
  void dispose() { account.dispose(); floatingDetail.dispose(); description.dispose(); debit.dispose(); credit.dispose(); }
}
