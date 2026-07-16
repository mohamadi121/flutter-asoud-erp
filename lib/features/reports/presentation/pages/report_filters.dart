import 'package:flutter/material.dart';

class ReportFilters extends StatefulWidget {
  const ReportFilters({required this.requireAccount, required this.onSubmit, this.allowParty = false, super.key});
  final bool requireAccount;
  final bool allowParty;
  final void Function(String company, DateTime fromDate, DateTime toDate, String account, String partyType, String party) onSubmit;
  @override
  State<ReportFilters> createState() => _ReportFiltersState();
}

class _ReportFiltersState extends State<ReportFilters> {
  final _company = TextEditingController();
  final _account = TextEditingController();
  final _party = TextEditingController();
  DateTime _fromDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _toDate = DateTime.now();
  String _partyType = '';

  @override
  void dispose() {
    _company.dispose();
    _account.dispose();
    _party.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _company, decoration: const InputDecoration(labelText: 'شرکت در ERPNext *'), onChanged: (_) => setState(() {})),
          TextField(controller: _account, decoration: InputDecoration(labelText: widget.requireAccount ? 'حساب *' : 'حساب (اختیاری)'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DateButton(title: 'از تاریخ', value: _fromDate, onPick: (value) => setState(() => _fromDate = value))),
            const SizedBox(width: 8),
            Expanded(child: _DateButton(title: 'تا تاریخ', value: _toDate, onPick: (value) => setState(() => _toDate = value))),
          ]),
          if (widget.allowParty) ...[
            DropdownButtonFormField<String>(
              initialValue: _partyType,
              decoration: const InputDecoration(labelText: 'نوع طرف حساب'),
              items: const [
                DropdownMenuItem(value: '', child: Text('همه')),
                DropdownMenuItem(value: 'Customer', child: Text('مشتری')),
                DropdownMenuItem(value: 'Supplier', child: Text('تأمین‌کننده')),
                DropdownMenuItem(value: 'Employee', child: Text('پرسنل')),
              ],
              onChanged: (value) => setState(() => _partyType = value ?? ''),
            ),
            TextField(controller: _party, decoration: const InputDecoration(labelText: 'شناسه طرف حساب')),
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _canSubmit ? () => widget.onSubmit(_company.text.trim(), _fromDate, _toDate, _account.text.trim(), _partyType, _party.text.trim()) : null,
            icon: const Icon(Icons.filter_alt_rounded),
            label: const Text('نمایش گزارش'),
          )),
        ]),
      ));

  bool get _canSubmit => _company.text.trim().isNotEmpty && (!widget.requireAccount || _account.text.trim().isNotEmpty) && !_fromDate.isAfter(_toDate);
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.title, required this.value, required this.onPick});
  final String title;
  final DateTime value;
  final ValueChanged<DateTime> onPick;
  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: () async {
          final selected = await showDatePicker(context: context, initialDate: value, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (selected != null) onPick(selected);
        },
        child: Text('$title: ${value.toIso8601String().split('T').first}'),
      );
}
