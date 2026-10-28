import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/personnel_introduction_letter_repository.dart';

class PersonnelIntroductionLetterPreviewPage extends StatefulWidget {
  const PersonnelIntroductionLetterPreviewPage({
    required this.letterName,
    required this.company,
    super.key,
  });

  final String letterName;
  final String company;

  @override
  State<PersonnelIntroductionLetterPreviewPage> createState() =>
      _PersonnelIntroductionLetterPreviewPageState();
}

class _PersonnelIntroductionLetterPreviewPageState
    extends State<PersonnelIntroductionLetterPreviewPage> {
  late final PersonnelIntroductionLetterRepository _repository =
      RepositoryProvider.of<PersonnelIntroductionLetterRepository>(context, listen: false);

  bool _loading = true;
  String? _error;
  bool _finalizing = false;
  bool _printing = false;
  late final String _finalizeRequestKey =
      'finalize-${widget.letterName}-${DateTime.now().microsecondsSinceEpoch}';
  PersonnelIntroductionLetterDetail? _letter;

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
      final item = await _repository.getLetter(name: widget.letterName);
      if (!mounted) return;
      setState(() {
        _letter = item;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'بارگذاری معرفی‌نامه ناموفق بود.';
      });
    }
  }

  Future<void> _finalize() async {
    final letter = _letter;
    if (letter == null || letter.status != 'Draft' || _finalizing) return;

    setState(() => _finalizing = true);
    try {
      final updated = await _repository.finalizeLetter(
        name: letter.name,
        revision: letter.revision,
        requestKey: _finalizeRequestKey,
      );
      if (!mounted) return;
      setState(() {
        _letter = updated;
        _finalizing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updated.isFinal
            ? 'معرفی‌نامه با موفقیت صادر و نهایی گردید.'
            : 'معرفی‌نامه برای بررسی به گردش کار ارسال شد.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _finalizing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'نهایی‌سازی معرفی‌نامه با خطا مواجه شد.',
          ),
        ),
      );
    }
  }

  Future<void> _printLetter() async {
    final letter = _letter;
    if (letter == null || _printing) return;
    if (letter.printHtml.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خروجی چاپ معرفی‌نامه از سرور دریافت نشده است.')),
      );
      return;
    }
    setState(() => _printing = true);
    try {
      // ignore: deprecated_member_use
      final bytes = await Printing.convertHtml(html: letter.printHtml, format: PdfPageFormat.a4);
      await Printing.layoutPdf(onLayout: (_) async => bytes, format: PdfPageFormat.a4);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('چاپ معرفی‌نامه در این دستگاه انجام نشد. دوباره تلاش کنید.')),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Widget _buildPaperContent(PersonnelIntroductionLetterDetail letter) {
    final cleanText = letter.renderedHtml
        .replaceAll(RegExp(r'<article[^>]*>'), '')
        .replaceAll(RegExp(r'</article>'), '')
        .replaceAll(RegExp(r'<section[^>]*>'), '')
        .replaceAll(RegExp(r'</section>'), '\n\n')
        .replaceAll(RegExp(r'<h3[^>]*>'), '■ ')
        .replaceAll(RegExp(r'</h3>'), '\n')
        .replaceAll(RegExp(r'<p[^>]*>'), '')
        .replaceAll(RegExp(r'</p>'), '')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6DFE9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF5FC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.corporate_fare, color: Color(0xFF2379BE), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سربرگ سازمان',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF243F60),
                      ),
                    ),
                    Text(
                      'از تنظیمات مشترک چاپ ASOUD ERP',
                      style: TextStyle(fontSize: 10, color: Color(0xFF748398)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFB8C6D3)),
          const Text(
            'معرفی‌نامه پرسنل',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF243F60),
            ),
          ),
          if (!letter.isFinal) ...[
            const SizedBox(height: 6),
            const Text(
              'پیش‌نویس ـ فاقد اعتبار نهایی',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9EACBC),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'شماره: ${letter.number.isNotEmpty ? letter.number : "—"}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF62768C)),
              ),
              Text(
                'تاریخ: ${letter.issueDate.isNotEmpty ? letter.issueDate : "—"}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF62768C)),
              ),
            ],
          ),
          if (letter.validityDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'اعتبار تا: ${letter.validityDate}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF62768C)),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            cleanText.isNotEmpty ? cleanText : 'متن معرفی‌نامه در حال بارگذاری است...',
            style: const TextStyle(
              fontSize: 12,
              height: 1.9,
              color: Color(0xFF37475A),
            ),
          ),
          const SizedBox(height: 36),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'نام و امضای مقام مجاز',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF243F60)),
              ),
              Text(
                'مهر شرکت',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF243F60)),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Divider(height: 20, thickness: 1, color: Color(0xFFB8C6D3)),
          const Text(
            'پابرگ و اطلاعات شرکت از تنظیمات مشترک چاپ ASOUD ERP',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: Color(0xFF748398)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AsoudHeader(
          title: 'پیش‌نمایش معرفی‌نامه',
          subtitle: 'نسخهٔ قابل چاپ سند پرسنلی',
          action: _letter != null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _letter!.isFinal ? AsoudColors.successSurface : const Color(0xFFEDF0F4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _letter!.statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _letter!.isFinal ? AsoudColors.success : const Color(0xFF62768C),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(
                    failure: _error!,
                    onRetry: _load,
                  )
                : _letter == null
                    ? const EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'معرفی‌نامه یافت نشد',
                        description: 'سندی با این شناسه در سامانه ثبت نشده است.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPaperContent(_letter!),
                              const SizedBox(height: 20),
                              if (_letter!.status == 'Draft') ...[
                                ElevatedButton.icon(
                                  icon: _finalizing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.verified_outlined, size: 18),
                                  label: Text(_finalizing ? 'در حال صدور...' : 'صدور نهایی معرفی‌نامه'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AsoudColors.primary,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _finalizing ? null : _finalize,
                                ),
                                const SizedBox(height: 10),
                              ],
                              OutlinedButton.icon(
                                icon: const Icon(Icons.print_outlined, size: 18),
                                label: const Text('چاپ / ذخیره سند'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AsoudColors.primary,
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _printing ? null : _printLetter,
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('بازگشت'),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
      ),
    );
  }
}
