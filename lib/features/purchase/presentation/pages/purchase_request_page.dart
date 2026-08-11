import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/purchase_request.dart';
import '../../domain/purchase_request_repository.dart';
import '../cubit/purchase_request_cubit.dart';

class PurchaseRequestPage extends StatelessWidget {
  const PurchaseRequestPage({required this.company, super.key});
  final String company;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PurchaseRequestCubit(
          context.read<PurchaseRequestRepository>(),
          company,
        )..load(),
        child: const _PurchaseRequestView(),
      );
}

class _PurchaseRequestView extends StatefulWidget {
  const _PurchaseRequestView();
  @override
  State<_PurchaseRequestView> createState() => _PurchaseRequestViewState();
}

class _PurchaseRequestViewState extends State<_PurchaseRequestView> {
  final subject = TextEditingController();
  DateTime scheduleDate = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<PurchaseRequestCubit, PurchaseRequestState>(
        listenWhen: (old, current) => old.message != current.message,
        listener: (context, state) {
          if (state.message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
          }
          if (state.status == PurchaseRequestStatus.success) {
            Navigator.pop(context, true);
          }
        },
        builder: (context, state) => Scaffold(
          appBar: const AsoudHeader(
            title: 'درخواست خرید',
            subtitle: 'ثبت سند و ارسال خودکار به گردش‌کار',
          ),
          body: state.status == PurchaseRequestStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  children: [
                    const _InfoNotice(),
                    const SizedBox(height: 14),
                    TextField(
                      controller: subject,
                      decoration:
                          const InputDecoration(labelText: 'عنوان درخواست *'),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      value: scheduleDate,
                      onChanged: (value) =>
                          setState(() => scheduleDate = value),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(
                        child: AsoudSectionTitle(title: 'اقلام موردنیاز'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _addLine(context, state.options),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('افزودن کالا'),
                      ),
                    ]),
                    if (state.lines.isEmpty)
                      const _EmptyLines()
                    else
                      for (var index = 0; index < state.lines.length; index++)
                        _LineCard(
                          line: state.lines[index],
                          onDelete: () => context
                              .read<PurchaseRequestCubit>()
                              .removeLine(index),
                        ),
                  ],
                ),
          bottomNavigationBar: AsoudBottomActions(
            primaryLabel: state.status == PurchaseRequestStatus.submitting
                ? 'در حال ثبت...'
                : 'ثبت و ارسال به گردش‌کار',
            onPrimary: state.status == PurchaseRequestStatus.submitting
                ? null
                : () => context
                    .read<PurchaseRequestCubit>()
                    .submit(subject.text, scheduleDate),
            secondaryLabel: 'انصراف',
            onSecondary: () => Navigator.pop(context),
          ),
        ),
      );

  Future<void> _addLine(
      BuildContext context, PurchaseRequestOptions options) async {
    final line = await showModalBottomSheet<PurchaseRequestLine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddLineSheet(options: options),
    );
    if (line != null && context.mounted) {
      context.read<PurchaseRequestCubit>().addLine(line);
    }
  }
}

class _AddLineSheet extends StatefulWidget {
  const _AddLineSheet({required this.options});
  final PurchaseRequestOptions options;
  @override
  State<_AddLineSheet> createState() => _AddLineSheetState();
}

class _AddLineSheetState extends State<_AddLineSheet> {
  final code = TextEditingController();
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  String uom = '', warehouse = '';

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 18, 16, 18 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const AsoudSectionTitle(title: 'افزودن قلم درخواست'),
              const SizedBox(height: 12),
              if (widget.options.items.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'کالا *'),
                  items: widget.options.items
                      .map((item) => DropdownMenuItem(
                            value: item.code,
                            child: Text('${item.name} (${item.code})',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(growable: false),
                  onChanged: (value) {
                    final item = widget.options.items
                        .firstWhere((item) => item.code == value);
                    code.text = item.code;
                    name.text = item.name;
                    setState(() => uom = item.uom);
                  },
                )
              else ...[
                TextField(
                  controller: code,
                  decoration: const InputDecoration(
                      labelText: 'کد کالا در ASOUD ERP *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'عنوان کالا'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: uom.isEmpty ? 'تعداد *' : 'تعداد ($uom) *'),
              ),
              if (widget.options.warehouses.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'انبار مقصد'),
                  items: widget.options.warehouses
                      .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis)))
                      .toList(growable: false),
                  onChanged: (value) => warehouse = value ?? '',
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(qty.text.trim());
                    if (code.text.trim().isEmpty ||
                        amount == null ||
                        amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('کالا و تعداد معتبر را وارد کنید.')));
                      return;
                    }
                    Navigator.pop(
                      context,
                      PurchaseRequestLine(
                        itemCode: code.text.trim(),
                        itemName: name.text.trim().isEmpty
                            ? code.text.trim()
                            : name.text.trim(),
                        qty: amount,
                        uom: uom,
                        warehouse: warehouse,
                      ),
                    );
                  },
                  child: const Text('افزودن به درخواست'),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onChanged});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final selected = await showDatePicker(
            context: context,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 730)),
            initialDate: value,
          );
          if (selected != null) onChanged(selected);
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'تاریخ نیاز *'),
          child: Text('${value.year}/${value.month}/${value.day}'),
        ),
      );
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.onDelete});
  final PurchaseRequestLine line;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: const AsoudIconBox(
              icon: Icons.inventory_2_outlined, color: AsoudColors.warning),
          title: Text(line.itemName,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              '${line.qty} ${line.uom}${line.warehouse.isEmpty ? '' : ' • ${line.warehouse}'}'),
          trailing: IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AsoudColors.danger),
          ),
        ),
      );
}

class _EmptyLines extends StatelessWidget {
  const _EmptyLines();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AsoudColors.border),
        ),
        child: const Text('هنوز کالایی به درخواست اضافه نشده است.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AsoudColors.muted)),
      );
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AsoudColors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: AsoudColors.primary),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'پس از ثبت، سند درخواست خرید ساخته و برای مسئول مرحله اول ارسال می‌شود.',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      );
}
