import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/frappe_client.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../../../core/widgets/states.dart';
import '../../data/personnel_introduction_letter_repository.dart';
import 'personnel_introduction_letter_form_page.dart';
import 'personnel_introduction_letter_preview_page.dart';
import 'personnel_introduction_letter_template_builder_page.dart';

class PersonnelIntroductionLettersPage extends StatefulWidget {
  const PersonnelIntroductionLettersPage({required this.company, super.key});
  final String company;

  @override
  State<PersonnelIntroductionLettersPage> createState() =>
      _PersonnelIntroductionLettersPageState();
}

class _PersonnelIntroductionLettersPageState extends State<PersonnelIntroductionLettersPage> {
  PersonnelIntroductionLetterRepository? _injectedRepository;
  PersonnelIntroductionLetterRepository get _repository {
    try {
      return RepositoryProvider.of<PersonnelIntroductionLetterRepository>(context, listen: false);
    } catch (_) {
      return _injectedRepository ??=
          FrappePersonnelIntroductionLetterRepository(context.read<FrappeApiClient>());
    }
  }

  late Future<({List<PersonnelIntroductionLetter> items, int total})> _rows;
  String _status = '';
  String _query = '';
  bool _canManageTemplate = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
    _loadTemplateCapability().ignore();
  }

  Future<void> _loadTemplateCapability() async {
    try {
      final template = await _repository.getTemplate(company: widget.company);
      if (mounted) setState(() => _canManageTemplate = template.canManageTemplate);
    } catch (_) {
      if (mounted) setState(() => _canManageTemplate = false);
    }
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

  void _openNewForm([String letterName = '']) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: _repository,
          child: PersonnelIntroductionLetterFormPage(
            company: widget.company,
            initialLetterName: letterName,
          ),
        ),
      ),
    );
    if (result == true || mounted) {
      setState(_reload);
    }
  }

  void _openPreview(String letterName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: _repository,
          child: PersonnelIntroductionLetterPreviewPage(
            letterName: letterName,
            company: widget.company,
          ),
        ),
      ),
    );
  }

  void _openTemplateBuilder() {
    if (!_canManageTemplate) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: _repository,
          child: PersonnelIntroductionLetterTemplateBuilderPage(company: widget.company),
        ),
      ),
    );
  }

  Widget _buildStatusTile(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4EAF1)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF62768C)),
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
          title: 'معرفی‌نامه‌های پرسنلی',
          subtitle: 'اسناد پرسنلی / معرفی‌نامه پرسنل',
          action: _canManageTemplate ? IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'ویرایش قالب',
            onPressed: _openTemplateBuilder,
          ) : null,
        ),
        body: RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                            child: const Icon(Icons.assignment_ind_outlined,
                                color: Color(0xFF2379BE), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مدیریت معرفی‌نامه‌های پرسنلی',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF243F60)),
                                ),
                                Text(
                                  'صدور، مشاهده و چاپ معرفی‌نامه‌ها',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF748398)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('＋ معرفی‌نامه جدید'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AsoudColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _openNewForm(),
                            ),
                          ),
                          if (_canManageTemplate) const SizedBox(width: 8),
                          if (_canManageTemplate) Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.tune, size: 16),
                              label: const Text('ویرایش قالب', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _openTemplateBuilder,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.grid_view_outlined, size: 18, color: Color(0xFF243F60)),
                          SizedBox(width: 6),
                          Text(
                            'فهرست معرفی‌نامه‌ها',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF243F60)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'نام، کد پرسنلی، شماره یا مخاطب...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _query = '';
                                      _reload();
                                    });
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onSubmitted: (v) {
                          setState(() {
                            _query = v.trim();
                            _reload();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _status.isEmpty ? 'all' : _status,
                        decoration: const InputDecoration(
                          labelText: 'فیلتر وضعیت',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('همه وضعیت‌ها')),
                          DropdownMenuItem(value: 'draft', child: Text('پیش‌نویس')),
                          DropdownMenuItem(value: 'pending', child: Text('در جریان')),
                          DropdownMenuItem(value: 'final', child: Text('نهایی')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _status = val == 'all' ? '' : (val ?? '');
                            _reload();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<({List<PersonnelIntroductionLetter> items, int total})>(
                future: _rows,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    final err = snapshot.error;
                    return ErrorState(
                      failure: err ?? 'ارتباط با سرور برقرار نشد.',
                      onRetry: () => setState(_reload),
                    );
                  }

                  final data = snapshot.data;
                  final items = data?.items ?? const [];

                  final draftCount = items.where((i) => i.status == 'Draft').length;
                  final pendingCount =
                      items.where((i) => i.status != 'Draft' && i.status != 'Final').length;
                  final finalCount = items.where((i) => i.status == 'Final').length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _buildStatusTile(
                                  '$draftCount', 'پیش‌نویس', const Color(0xFF62768C))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildStatusTile(
                                  '$pendingCount', 'در جریان', AsoudColors.warning)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildStatusTile(
                                  '$finalCount', 'نهایی', AsoudColors.success)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${items.length} معرفی‌نامه یافت شد',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF62768C)),
                      ),
                      const SizedBox(height: 8),
                      if (items.isEmpty)
                        const EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'معرفی‌نامه‌ای یافت نشد',
                          description: 'سندی با این شرایط در سیستم ثبت نشده است.',
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final row = items[index];
                            final isDraft = row.status == 'Draft';
                            final isFinal = row.status == 'Final';

                            return Card(
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'معرفی‌نامه ـ ${row.employeeName}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Color(0xFF243F60),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isFinal
                                                ? AsoudColors.successSurface
                                                : isDraft
                                                    ? const Color(0xFFEDF0F4)
                                                    : AsoudColors.warningSurface,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            row.statusLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isFinal
                                                  ? AsoudColors.success
                                                  : isDraft
                                                      ? const Color(0xFF62768C)
                                                      : AsoudColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'کد پرسنلی: ${row.employeeNumber} | شماره: ${row.number}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF62768C)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'مخاطب: ${row.recipientText}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF42556B)),
                                    ),
                                    if (row.purpose.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'هدف: ${row.purpose}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF42556B)),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: Icon(
                                              isDraft ? Icons.edit_outlined : Icons.visibility_outlined,
                                              size: 14,
                                            ),
                                            label: Text(
                                              isDraft ? 'ادامه ویرایش' : 'مشاهده',
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AsoudColors.primary,
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              minimumSize: Size.zero,
                                            ),
                                            onPressed: () =>
                                                isDraft ? _openNewForm(row.name) : _openPreview(row.name),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.print_outlined, size: 14),
                                            label: const Text('چاپ', style: TextStyle(fontSize: 11)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              minimumSize: Size.zero,
                                            ),
                                            onPressed: () => _openPreview(row.name),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
