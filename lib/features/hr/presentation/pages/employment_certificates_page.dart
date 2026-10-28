import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/employment_certificate_repository.dart';
import 'employment_certificate_form_page.dart';
import 'employment_certificate_preview_page.dart';
import 'employment_certificate_template_builder_page.dart';

class EmploymentCertificatesPage extends StatefulWidget {
  const EmploymentCertificatesPage({
    required this.company,
    this.canManageTemplate = false,
    super.key,
  });
  final String company;
  final bool canManageTemplate;

  @override
  State<EmploymentCertificatesPage> createState() => _EmploymentCertificatesPageState();
}

class _EmploymentCertificatesPageState extends State<EmploymentCertificatesPage> {
  EmploymentCertificateRepository? _injectedRepository;
  EmploymentCertificateRepository get _repository {
    try {
      return RepositoryProvider.of<EmploymentCertificateRepository>(context, listen: false);
    } catch (_) {
      return _injectedRepository ??= EmploymentCertificateRepository(context.read<FrappeApiClient>());
    }
  }

  late Future<({List<EmploymentCertificate> items, int total})> _rows;
  String _status = '';
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _rows = _repository.list(
      company: widget.company,
      status: _status,
      query: _query,
    );
  }

  Color _statusColor(String group) => switch (group) {
        'نهایی' => AsoudColors.success,
        'در جریان' => AsoudColors.primary,
        'ردشده' => AsoudColors.danger,
        _ => AsoudColors.warning,
      };

  Color _statusBg(String group) => switch (group) {
        'نهایی' => AsoudColors.successSurface,
        'در جریان' => const Color(0xFFEFF6FF),
        'ردشده' => const Color(0xFFFEF2F2),
        _ => AsoudColors.warningSurface,
      };

  Widget _buildStatusCountBox(String label, int count, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              toPersianDigits('$count'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewForm([String certificateName = '']) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: _repository,
          child: EmploymentCertificateFormPage(
            company: widget.company,
            initialCertificateName: certificateName,
          ),
        ),
      ),
    );
    if (result == true) {
      setState(_reload);
    }
  }

  void _openPreview(String certificateName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: _repository,
          child: EmploymentCertificatePreviewPage(
            certificateName: certificateName,
            company: widget.company,
          ),
        ),
      ),
    );
  }

  void _openTemplateBuilder() {
    if (!widget.canManageTemplate) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: _repository,
          child: EmploymentCertificateTemplateBuilderPage(
            company: widget.company,
            canManageTemplate: widget.canManageTemplate,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AsoudHeader(title: 'گواهی‌های اشتغال به کار', subtitle: 'اسناد پرسنلی'),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Action header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('＋ گواهی جدید', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AsoudColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _openNewForm(),
                    ),
                  ),
                  if (widget.canManageTemplate) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('ویرایش قالب', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _openTemplateBuilder,
                    ),
                  ],
                ],
              ),
            ),

            // Search and status filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'نام، کد پرسنلی، شماره گواهی یا مخاطب...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _reload();
                                });
                              },
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _query = val.trim();
                        _reload();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'فیلتر وضعیت',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('همه گواهی‌ها')),
                      DropdownMenuItem(value: 'Draft', child: Text('پیش‌نویس')),
                      DropdownMenuItem(value: 'Pending', child: Text('در جریان')),
                      DropdownMenuItem(value: 'Final', child: Text('نهایی')),
                      DropdownMenuItem(value: 'Rejected', child: Text('ردشده')),
                    ],
                    onChanged: (value) => setState(() {
                      _status = value ?? '';
                      _reload();
                    }),
                  ),
                ],
              ),
            ),

            // Certificate List
            Expanded(
              child: FutureBuilder<({List<EmploymentCertificate> items, int total})>(
                future: _rows,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ErrorState(
                      failure: failureMessage(snapshot.error),
                      onRetry: () => setState(_reload),
                    );
                  }
                  final result = snapshot.data!;
                  if (result.items.isEmpty) {
                    return _query.isNotEmpty || _status.isNotEmpty
                        ? const EmptyState(
                            icon: Icons.search_off_outlined,
                            title: 'گواهی‌ای پیدا نشد',
                            description: 'گواهی‌ای مطابق عبارت جست‌وجو یا فیلتر وضعیت یافت نشد.',
                          )
                        : const EmptyState(
                            icon: Icons.description_outlined,
                            title: 'گواهی‌ای ثبت نشده است',
                            description: 'برای این دفتر هنوز گواهی اشتغال به کاری ثبت نشده است.',
                          );
                  }

                  final draftCount = result.items.where((i) => i.isDraft).length;
                  final pendingCount = result.items.where((i) => i.isInReview).length;
                  final finalCount = result.items.where((i) => i.isFinal).length;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            _buildStatusCountBox('پیش‌نویس', draftCount, AsoudColors.warning, AsoudColors.warningSurface),
                            const SizedBox(width: 8),
                            _buildStatusCountBox('در جریان', pendingCount, AsoudColors.primary, const Color(0xFFEFF6FF)),
                            const SizedBox(width: 8),
                            _buildStatusCountBox('نهایی', finalCount, AsoudColors.success, AsoudColors.successSurface),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: result.items.length,
                          itemBuilder: (context, index) {
                            final item = result.items[index];
                            final isDraft = item.isDraft;
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.employeeName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _statusBg(item.statusGroup),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            item.statusLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _statusColor(item.statusGroup),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 6),
                              Text(
                                'کد پرسنلی: ${item.employeeNumber} | شماره سند: ${item.number}',
                                style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'مخاطب: ${item.addresseeName.isEmpty ? 'تعیین نشده' : item.addresseeName}',
                                style: const TextStyle(fontSize: 11, color: AsoudColors.muted),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => isDraft ? _openNewForm(item.name) : _openPreview(item.name),
                                    child: Text(
                                      isDraft ? 'ادامه ویرایش' : 'مشاهده',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.print, size: 14),
                                    label: const Text('چاپ', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: AsoudColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _openPreview(item.name),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  ),
),
    );
  }
}
