import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:asoud_erp/core/utils/failure_message.dart';

import 'package:asoud_erp/core/theme/asoud_colors.dart';
import 'package:asoud_erp/core/utils/jalali_date.dart';
import 'package:asoud_erp/core/widgets/asoud_ui.dart';
import 'package:asoud_erp/features/hr/domain/hr_contract_models.dart';
import '../../widgets/hr_document_print.dart';

class HrContractPrintPage extends StatelessWidget {
  const HrContractPrintPage({
    required this.contract,
    this.template,
    this.loadPayload,
    super.key,
  });

  final HrContractRecord contract;
  final HrContractTemplate? template;
  final Future<Map<String, dynamic>> Function()? loadPayload;

  @override
  Widget build(BuildContext context) {
    if (loadPayload != null) {
      return _ServerContractPrint(loadPayload: loadPayload!);
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
          title: 'پیش‌نمایش چاپ قرارداد',
          subtitle: contract.employeeName,
          action: IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('برای چاپ، ابتدا سند پرسنلی را ذخیره و خروجی چاپ سرور را دریافت کنید.')),
              );
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HrContractPrintLayout(
                contract: contract,
                template: template,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('برای چاپ، ابتدا سند پرسنلی را ذخیره و خروجی چاپ سرور را دریافت کنید.')),
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text('چاپ یا ذخیره PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بازگشت'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerContractPrint extends StatefulWidget {
  const _ServerContractPrint({required this.loadPayload});
  final Future<Map<String, dynamic>> Function() loadPayload;

  @override
  State<_ServerContractPrint> createState() => _ServerContractPrintState();
}

class _ServerContractPrintState extends State<_ServerContractPrint> {
  late Future<Map<String, dynamic>> payload = widget.loadPayload();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AsoudHeader(title: 'پیش‌نمایش چاپ قرارداد'),
    body: FutureBuilder<Map<String, dynamic>>(
      future: payload,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(failureMessage(snapshot.error!)),
            TextButton(onPressed: () => setState(() { payload = widget.loadPayload(); }), child: const Text('تلاش دوباره')),
          ]));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        return Column(children: [
          if (data['draft_banner'] != null) Text('${data['draft_banner']}'),
          Expanded(child: PdfPreview(
            initialPageFormat: PdfPageFormat.a4,
            canChangePageFormat: false,
            canChangeOrientation: false,
            // The server HTML owns the letterhead, footer and rendered snapshot.
            build: (format) => convertHrDocument(data['html']?.toString() ?? '', format: format),
          )),
        ]);
      },
    ),
  );
}

class HrContractPrintLayout extends StatelessWidget {
  const HrContractPrintLayout({
    required this.contract,
    this.template,
    super.key,
  });

  final HrContractRecord contract;
  final HrContractTemplate? template;

  static const _periodLabels = {
    'monthly': 'ماهانه',
    'annual': 'سالانه',
    'once': 'یک‌باره',
  };

  String _formatMoney(int? amount) {
    if (amount == null) return 'اطلاعات موجود نیست';
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return '${toPersianDigits(buffer.toString())} ریال';
  }

  @override
  Widget build(BuildContext context) {
    final clauses = contract.snapshotClauses.isNotEmpty
        ? contract.snapshotClauses
        : (template?.clauses ?? HrContractTemplate.defaultTemplate().clauses);

    final payrollRows = contract.snapshotPayrollRows.isNotEmpty
        ? contract.snapshotPayrollRows
        : (template?.payrollRows ??
            HrContractTemplate.defaultTemplate().payrollRows);

    final monthlyRows = payrollRows.where((r) => r.period == 'monthly').toList();
    final bool allMonthlyFilled = monthlyRows
        .every((r) => contract.salaries.containsKey(r.fieldRef) && contract.salaries[r.fieldRef] != null);

    final int monthlyTotal = monthlyRows.fold<int>(
      0,
      (sum, r) => sum + (contract.salaries[r.fieldRef] ?? 0),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.corporate_fare,
                          size: 18, color: AsoudColors.primary),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نام و سربرگ سازمان',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'از تنظیمات شرکت',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'شماره: ${contract.displayNumber}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                  ),
                  Text(
                    'تاریخ: ${contract.startDate}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1.5, color: Color(0xFFE2E8F0)),

          // Title & Draft Watermark
          Center(
            child: Text(
              'قرارداد کار',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          if (!contract.isFinal) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'پیش‌نویس ـ فاقد اعتبار نهایی',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Parties summary
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text('نام پرسنل: ${contract.employeeName}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('کد پرسنلی: ${contract.employeeCode}',
                    style: const TextStyle(fontSize: 12)),
                Text('نوع قرارداد: ${contract.kind}',
                    style: const TextStyle(fontSize: 12)),
                if (contract.endDate != null && contract.endDate!.isNotEmpty)
                  Text('تاریخ پایان: ${contract.endDate}',
                      style: const TextStyle(fontSize: 12)),
                Text('محل کار: ${contract.workplace}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Clauses
          for (int i = 0; i < clauses.length; i++) ...[
            const SizedBox(height: 10),
            Text(
              'ماده ${toPersianDigits('${i + 1}')} ـ ${clauses[i].title}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              clauses[i].body,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Color(0xFF334155),
              ),
            ),
            if (clauses[i].id == 4) ...[
              const SizedBox(height: 8),
              // Payroll table
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Container(
                      color: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: const Row(
                        children: [
                          SizedBox(
                              width: 36,
                              child: Text('ردیف',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold))),
                          Expanded(
                              child: Text('عنوان',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold))),
                          SizedBox(
                              width: 60,
                              child: Text('دوره',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold))),
                          Expanded(
                              child: Text('مبلغ (ریال)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.end)),
                        ],
                      ),
                    ),
                    for (int j = 0; j < payrollRows.length; j++) ...[
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                toPersianDigits('${j + 1}'),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                payrollRows[j].name,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                _periodLabels[payrollRows[j].period] ??
                                    payrollRows[j].period,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatMoney(
                                    contract.salaries[payrollRows[j].fieldRef]),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: contract.salaries[
                                              payrollRows[j].fieldRef] ==
                                          null
                                      ? Colors.red
                                      : const Color(0xFF0F172A),
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(
                        height: 1, thickness: 1.5, color: Color(0xFFCBD5E1)),
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'جمع اقلام ماهانه:',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              allMonthlyFilled
                                  ? _formatMoney(monthlyTotal)
                                  : 'ناقص',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: allMonthlyFilled
                                    ? AsoudColors.primary
                                    : Colors.orange,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          if (contract.notes != null && contract.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'شروط اختصاصی:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              contract.notes!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            ),
          ],

          const SizedBox(height: 36),
          // Signatures
          const Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 24,
            runSpacing: 16,
            children: [
              Text(
                'امضای کارفرما',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              Text(
                'امضای پرسنل',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Footer
          const Divider(height: 1, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'پابرگ سازمان: نشانی، تلفن و اطلاعات قانونی از تنظیمات شرکت',
                  style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'صفحه ۱ از ۱',
                style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
