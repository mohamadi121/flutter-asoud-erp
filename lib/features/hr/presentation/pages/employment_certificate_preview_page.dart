import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/employment_certificate_repository.dart';

class EmploymentCertificatePreviewPage extends StatefulWidget {
  const EmploymentCertificatePreviewPage({
    required this.certificateName,
    required this.company,
    super.key,
  });

  final String certificateName;
  final String company;

  @override
  State<EmploymentCertificatePreviewPage> createState() => _EmploymentCertificatePreviewPageState();
}

class _EmploymentCertificatePreviewPageState extends State<EmploymentCertificatePreviewPage> {
  late final EmploymentCertificateRepository _repository =
      RepositoryProvider.of<EmploymentCertificateRepository>(context, listen: false);

  bool _loading = true;
  String? _error;
  bool _finalizing = false;
  EmploymentCertificateDetail? _certificate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cert = await _repository.getCertificate(name: widget.certificateName);
      if (!mounted) return;
      setState(() {
        _certificate = cert;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failureMessage(e);
      });
    }
  }

  Future<void> _finalize() async {
    final cert = _certificate;
    if (cert == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نهایی‌سازی گواهی'),
        content: const Text('آیا از صدور نهایی و شماره‌گذاری رسمی این گواهی اطمینان دارید؟ پس از نهایی‌سازی، اطلاعات سند غیرقابل تغییر خواهد بود.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AsoudColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تأیید و نهایی‌سازی'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _finalizing = true);

    try {
      final reqKey = 'finalize-${widget.company}-${cert.name}-${DateTime.now().millisecondsSinceEpoch}';
      final updated = await _repository.finalizeCertificate(
        name: cert.name,
        revision: cert.revision,
        requestKey: reqKey,
      );

      if (!mounted) return;
      setState(() {
        _finalizing = false;
        _certificate = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('گواهی با موفقیت نهایی شد و شماره رسمی دریافت کرد.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _finalizing = false);
      final msg = failureMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _printCertificate() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('دستور چاپ ارسال شد.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: const AsoudHeader(title: 'پیش‌نمایش گواهی اشتغال', subtitle: 'اسناد پرسنلی'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: const AsoudHeader(title: 'پیش‌نمایش گواهی اشتغال', subtitle: 'اسناد پرسنلی'),
        body: ErrorState(failure: _error!, onRetry: _load),
      );
    }

    final cert = _certificate!;
    final isFinal = cert.isFinal;

    return Scaffold(
      appBar: const AsoudHeader(title: 'پیش‌نمایش گواهی اشتغال', subtitle: 'اسناد پرسنلی'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Notice banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFinal ? const Color(0xFFEBF7F2) : const Color(0xFFF0F6FC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isFinal ? const Color(0xFFC3E7D5) : const Color(0xFFDBE9F5)),
              ),
              child: Row(
                children: [
                  Icon(
                    isFinal ? Icons.check_circle_outline : Icons.info_outline,
                    size: 18,
                    color: isFinal ? AsoudColors.success : AsoudColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFinal
                          ? 'این سند نهایی شده و دارای شماره رسمی است.'
                          : 'این سند در وضعیت پیش‌نویس است و با نشان «فاقد اعتبار نهایی» چاپ می‌شود.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isFinal ? AsoudColors.success : const Color(0xFF426886),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // A4 Paper Mock
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD6DFE9)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Letterhead
                  Row(
                    children: [
                      const Icon(Icons.business, color: Color(0xFF243F60), size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cert.company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF243F60))),
                            const Text('سربرگ رسمی سازمان', style: TextStyle(fontSize: 10, color: AsoudColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFB8C6D3), height: 24),

                  // Title
                  const Center(
                    child: Text(
                      'گواهی اشتغال به کار',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF243F60)),
                    ),
                  ),
                  const SizedBox(height: 4),

                  if (!isFinal) ...[
                    const Center(
                      child: Text(
                        'پیش‌نویس ـ فاقد اعتبار نهایی',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9EACBC)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Meta row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('شماره: ${isFinal ? toPersianDigits(cert.number) : '—'}', style: const TextStyle(fontSize: 10, color: Color(0xFF62768C))),
                      Text('تاریخ: ${isFinal && cert.issueDate.isNotEmpty ? toPersianDigits(cert.issueDate) : '—'}', style: const TextStyle(fontSize: 10, color: Color(0xFF62768C))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content blocks
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('به: ${cert.addresseeName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        const Text('موضوع: گواهی اشتغال به کار', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text(
                          'بدین‌وسیله گواهی می‌شود که خانم/آقای ${cert.employeeName} با شماره پرسنلی ${toPersianDigits(cert.employeeNumber)} در شرکت ${cert.company} مشغول به خدمت می‌باشند.',
                          style: const TextStyle(fontSize: 11, height: 2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'این گواهی بنا به درخواست نامبرده جهت ${cert.purpose} صادر گردیده و فاقد هرگونه ارزش و تعهد دیگری است.',
                          style: const TextStyle(fontSize: 11, height: 2),
                        ),
                        if (cert.hasSalary && cert.salaryRows.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('اقلام حقوق و دستمزد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          const SizedBox(height: 6),
                          Table(
                            border: TableBorder.all(color: const Color(0xFFD6DFE9)),
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(color: Color(0xFFF0F3F7)),
                                children: const [
                                  Padding(padding: EdgeInsets.all(6), child: Text('عنوان قلم', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('دوره', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('مبلغ (ریال)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              for (final row in cert.salaryRows) ...[
                                TableRow(
                                  children: [
                                    Padding(padding: const EdgeInsets.all(6), child: Text(row['title']?.toString() ?? '—', style: const TextStyle(fontSize: 10))),
                                    Padding(padding: const EdgeInsets.all(6), child: Text(row['period']?.toString() ?? 'ماهانه', style: const TextStyle(fontSize: 10))),
                                    Padding(padding: const EdgeInsets.all(6), child: Text(row['amount'] != null ? '${toPersianDigits('${row['amount']}')} ریال' : 'اطلاعات موجود نیست', style: const TextStyle(fontSize: 10))),
                                  ],
                                ),
                              ],
                              TableRow(
                                decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                children: [
                                  const Padding(padding: EdgeInsets.all(6), child: Text('جمع اقلام ماهانه', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                  const Padding(padding: EdgeInsets.all(6), child: Text('—', style: TextStyle(fontSize: 10))),
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Builder(
                                      builder: (context) {
                                        final monthly = cert.salaryRows.where((r) => r['period']?.toString() == 'ماهانه' || r['period']?.toString() == 'monthly').toList();
                                        int sum = 0;
                                        bool valid = monthly.isNotEmpty;
                                        for (final r in monthly) {
                                          final amt = r['amount'];
                                          final parsed = amt is num ? amt.toInt() : int.tryParse('$amt'.replaceAll(RegExp(r'[^0-9]'), ''));
                                          if (parsed == null) {
                                            valid = false;
                                            break;
                                          }
                                          sum += parsed;
                                        }
                                        return Text(
                                          valid ? '${toPersianDigits('$sum')} ریال' : 'ناقص',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: valid ? AsoudColors.primary : const Color(0xFFB45309),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  // Signatures
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('نام و امضای مقام مجاز', style: TextStyle(fontSize: 10, color: Color(0xFF62768C))),
                      Text('مهر شرکت', style: TextStyle(fontSize: 10, color: Color(0xFF62768C))),
                    ],
                  ),
                  const Divider(color: Color(0xFFB8C6D3), height: 32),
                  const Center(
                    child: Text(
                      'پابرگ و نشانی شرکت از تنظیمات سازمان',
                      style: TextStyle(fontSize: 9, color: Color(0xFF748398)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            ElevatedButton.icon(
              icon: const Icon(Icons.print, size: 18),
              label: const Text('چاپ گواهی'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AsoudColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _printCertificate,
            ),
            if (!isFinal) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: _finalizing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.verified, size: 18),
                label: const Text('ارسال و نهایی‌سازی گواهی'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AsoudColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _finalizing ? null : _finalize,
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('بازگشت'),
            ),
          ],
        ),
      ),
    );
  }
}
