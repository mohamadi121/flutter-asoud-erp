import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../hr/data/personnel_file_repository.dart';
import '../../../hr/data/personnel_repository.dart';
import '../../../hr/domain/personnel_file.dart';
import '../../../workflows/data/generic_request_repository.dart';
import '../../../workflows/presentation/pages/generic_request_page.dart';
import '../widgets/employee_photo.dart';

String _value(String? value) =>
    value == null || value.trim().isEmpty || value.contains('LOCAL-')
        ? 'ثبت نشده'
        : value;
bool _isLtrValue(String value) =>
    !RegExp(r'\p{Script=Arabic}', unicode: true).hasMatch(value) &&
    RegExp(r'[A-Za-z0-9]').hasMatch(value);
String _role(String designation, String department) {
  final parts =
      [designation, department].where((part) => part.isNotEmpty).join(' · ');
  return parts.isEmpty ? 'ثبت نشده' : parts;
}

String _label(String value) =>
    const {
      'Single': 'مجرد',
      'Married': 'متأهل',
      'Divorced': 'مطلقه',
      'Widowed': 'همسر فوت‌شده',
      'Active': 'فعال',
      'Inactive': 'غیرفعال',
      'Left': 'پایان همکاری',
      'Suspended': 'تعلیق',
      'Full-time': 'تمام وقت',
      'Part-time': 'پاره وقت',
      'Contract': 'قراردادی',
      'Intern': 'کارآموز',
      'Internship': 'کارآموزی',
      'Temporary': 'موقت',
      'Permanent': 'دائم'
    }[value] ??
    _value(value);

class MyInfoPage extends StatefulWidget {
  const MyInfoPage(
      {required this.repository,
      this.showDocuments = false,
      this.requests,
      super.key});
  final PersonnelFileRepository repository;
  final bool showDocuments;
  final GenericRequestRepository? requests;
  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  late Future<PersonnelFile> future = widget.repository.myFile();
  late bool documents = widget.showDocuments;
  int tab = 0;

  Future<void> _edit(PersonnelFile file) async {
    final proceed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('درخواست ویرایش اطلاعات',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      const Text(
                          'تغییر اطلاعات هویتی و تماس به صورت درخواست برای بررسی به واحد منابع انسانی ارسال می‌شود.'),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('بررسی امکان ثبت درخواست')),
                    ]))));
    if (proceed != true || !mounted) return;
    GenericRequestRepository? repository;
    try {
      repository = widget.requests ??
          GenericRequestRepository(
              context.read<FrappeApiClient>(), file.header.company);
      final options = await repository.options();
      final suitable = options.where((option) {
        final title =
            '${option['workflow_title'] ?? option['title'] ?? option['name'] ?? ''}';
        return RegExp('اصلاح|ویرایش|تغییر|بروزرسانی|به‌روزرسانی')
                .hasMatch(title) &&
            RegExp('اطلاعات فردی|اطلاعات پرسنلی|اطلاعات هویتی|اطلاعات تماس|مشخصات فردی')
                .hasMatch(title);
      }).firstOrNull;
      if (!mounted) return;
      if (suitable != null) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => GenericRequestPage(
                repository: repository!, definition: suitable)));
      } else {
        _editUnavailable();
      }
    } catch (_) {
      if (mounted) _editUnavailable();
    } finally {
      if (widget.requests == null) repository?.dispose();
    }
  }

  void _editUnavailable() =>
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('برای ویرایش اطلاعات با واحد منابع انسانی هماهنگ کنید')));

  Widget _row(String label, String? raw) {
    final value = _value(raw);
    final isLtr = _isLtrValue(value);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 5,
              child: Tooltip(
                message: label,
                child: Text(label,
                    softWrap: true,
                    style: const TextStyle(color: Colors.black54)),
              )),
          const SizedBox(width: 8),
          Expanded(
              flex: 6,
              child: Tooltip(
                message: value,
                child: Text(value,
                    softWrap: true,
                    maxLines: 2,
                    textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
                    textAlign: TextAlign.end),
              )),
        ]));
  }

  Widget _section(String title, Map<String, String?> values) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            for (final entry in values.entries) _row(entry.key, entry.value)
          ])));
  Map<String, String?> _serviceStatus(PersonnelFile f) {
    final employmentType = f.header.employmentType.isNotEmpty
        ? f.header.employmentType
        : f.employment.employmentType;
    return {
      if (f.header.status.isNotEmpty) 'وضعیت': _label(f.header.status),
      if (employmentType.isNotEmpty) 'نوع خدمت': _label(employmentType),
      if (f.employment.relievingDate.isNotEmpty)
        'تاریخ پایان خدمت': formatJalaliIso(f.employment.relievingDate)
    };
  }

  List<Widget> _content(PersonnelFile f) {
    final p = f.personal, o = f.organization, e = f.employment;
    final contract = f.contracts.where((c) => c.state == 'active').firstOrNull;
    final serviceStatus = _serviceStatus(f);
    return switch (tab) {
      0 => [
          _section('اطلاعات فردی', {
            'نام و نام خانوادگی': f.header.name,
            'کد ملی': p.nationalId,
            'تاریخ تولد': formatJalaliIso(p.birthDate),
            'وضعیت تأهل': _label(p.maritalStatus)
          }),
          if (serviceStatus.isNotEmpty) _section('وضعیت خدمت', serviceStatus)
        ],
      1 => [
          _section('اطلاعات سازمانی', {
            'واحد': o.departmentName,
            'سمت': o.designation,
            'مدیر مستقیم': o.reportsTo?.name,
            'محل کار/شعبه': o.branch
          })
        ],
      2 => [
          _section('اطلاعات استخدامی', {
            'نوع همکاری': _label(e.employmentType),
            'تاریخ شروع': formatJalaliIso(e.dateOfJoining),
            'سابقه خدمت': e.serviceLength?.label
          }),
          _section('قرارداد جاری', {
            'تاریخ شروع قرارداد': formatJalaliIso(contract?.startDate ?? ''),
            'تاریخ پایان قرارداد': formatJalaliIso(contract?.endDate ?? ''),
            'زمان باقی‌مانده': contract?.daysRemaining == null
                ? null
                : '${toPersianDigits(contract!.daysRemaining!)} روز'
          })
        ],
      _ => [
          _section('اطلاعات تماس',
              {'شماره موبایل': p.mobile, 'ایمیل': p.email, 'نشانی': p.address})
        ],
    };
  }

  Future<void> _download(PersonnelDocument document) async {
    try {
      final data = await PersonnelRepository(context.read<FrappeApiClient>())
          .record(document.id);
      final bytes = base64Decode('${data['file'] ?? ''}');
      if (bytes.isEmpty) throw const FormatException();
      await FilePicker.platform.saveFile(
          fileName: '${data['filename'] ?? document.filename}'
              .split(RegExp(r'[/\\]'))
              .last,
          bytes: bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('دریافت فایل ممکن نشد.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<PersonnelFile>(
          future: future,
          builder: (context, snapshot) => Scaffold(
                appBar: AppBar(title: const Text('اطلاعات من'), actions: [
                  TextButton(
                      onPressed:
                          snapshot.hasData ? () => _edit(snapshot.data!) : null,
                      child: const Text('ویرایش'))
                ]),
                body: snapshot.hasError
                    ? Center(
                        child: TextButton(
                            onPressed: () => setState(() {
                                  future = widget.repository.myFile();
                                }),
                            child: const Text(
                                'دریافت اطلاعات ممکن نشد؛ تلاش دوباره')))
                    : !snapshot.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : _body(snapshot.data!),
              )));
  Widget _body(PersonnelFile f) {
    final h = f.header;
    final code = h.employeeCode;
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            EmployeePhoto(name: h.name, recordId: h.photoRecord),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_value(h.name),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_role(h.designation, h.departmentName)),
                  Chip(
                      label: Text(_label(h.status)),
                      visualDensity: VisualDensity.compact)
                ]))
          ])),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _row(
              'کد پرسنلی',
              code == null || code.trim().isEmpty || code.contains('LOCAL-')
                  ? 'در انتظار ثبت'
                  : code)),
      DefaultTabController(
          length: 4,
          child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              onTap: (index) => setState(() {
                    tab = index;
                    documents = false;
                  }),
              tabs: const [
                Tab(text: 'اطلاعات کلی'),
                Tab(text: 'سازمانی'),
                Tab(text: 'استخدامی'),
                Tab(text: 'تماس')
              ])),
      Expanded(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!documents) ..._content(f),
                    TextButton.icon(
                        onPressed: () => setState(() => documents = !documents),
                        icon: const Icon(Icons.folder_outlined),
                        label: Text(documents ? 'بازگشت به اطلاعات' : 'مدارک')),
                    if (documents) ...[
                      const Text('مدارک',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      if (f.documents.isEmpty)
                        const Text('مدرکی ثبت نشده است.'),
                      for (final d in f.documents
                          .where((d) => d.category != 'Financial')) ...[
                        _section(_value(d.title), {
                          'نوع': d.categoryLabel,
                          'شماره': d.documentNumber,
                          'تاریخ صدور': formatJalaliIso(d.issueDate),
                          'تاریخ انقضا': formatJalaliIso(d.expiryDate),
                          'وضعیت': d.statusLabel
                        }),
                        OutlinedButton.icon(
                            onPressed: () => _download(d),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('مشاهده/دانلود فایل')),
                      ],
                    ],
                  ]))),
    ]);
  }
}
