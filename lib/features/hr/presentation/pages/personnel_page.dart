import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../../../core/widgets/asoud_form.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/personnel_file.dart';
import '../../data/personnel_file_repository.dart';
import '../../domain/personnel_record.dart';
import '../../data/personnel_repository.dart';
import '../cubit/personnel_cubit.dart';

import '../../../parties/domain/entities/party_profile.dart';
import '../../../parties/domain/repositories/party_repository.dart';
import '../../../parties/presentation/pages/party_form_page.dart';
import '../../../parties/presentation/pages/party_management_page.dart';
import '../../../parties/presentation/pages/personnel_roles_page.dart';
import 'hr_home_page.dart';
part 'personnel_design.dart';
part 'personnel_forms.dart';
part 'personnel_file_page.dart';
part 'personnel_file_sections.dart';

class PersonnelPage extends StatelessWidget {
  const PersonnelPage({required this.company, this.repository, super.key});
  final String company;
  final PersonnelRepository? repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PersonnelCubit(
            repository ?? PersonnelRepository(context.read<FrappeApiClient>()),
            company)
          ..load(),
        child: const _PersonnelList(),
      );
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice(
      {required this.offline, required this.pending, required this.failed});
  final bool offline, pending, failed;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading:
              Icon(failed ? Icons.error_outline : Icons.cloud_off_outlined),
          title: Text(failed
              ? 'همگام‌سازی نیازمند بررسی است'
              : pending
                  ? 'ذخیره روی گوشی؛ در انتظار همگام‌سازی'
                  : 'نمایش نسخه ذخیره‌شده روی گوشی'),
          subtitle: Text(failed
              ? 'سرور تغییر را نپذیرفته است؛ اطلاعات محلی حذف نشده‌اند.'
              : 'برای بررسی اتصال و ارسال تغییرات، فهرست پرسنل را تازه کنید.'),
        ),
      );
}

const _organization = {
  'job_title': 'سمت',
  'department': 'واحد سازمانی',
  'date_of_joining': 'تاریخ استخدام',
  'employment_type': 'نوع همکاری',
  'branch': 'شعبه',
  'reports_to': 'مدیر مستقیم',
  'final_confirmation_date': 'پایان دوره آزمایشی',
  'contract_end_date': 'پایان قرارداد',
  'notice_number_of_days': 'مهلت اعلام (روز)',
};
const _benefits = {
  'base_salary': 'حقوق پایه',
  'housing_allowance': 'حق مسکن',
  'transport_allowance': 'حق ایاب و ذهاب',
  'other_allowances': 'سایر مزایا',
  'deductions': 'کسورات',
  'net_salary': 'حقوق خالص'
};
const _sections = {
  'attendance': 'کارکرد و سوابق حضور',
  'document': 'مدارک و مستندات',
  'evaluation': 'ارزیابی عملکرد',
  'history': 'تاریخچه',
  'photo': 'تصویر پرسنل'
};

class _PersonnelPhoto extends StatefulWidget {
  const _PersonnelPhoto(
      {required this.recordId, required this.repository, this.size = 52});
  final double size;
  final String? recordId;
  final PersonnelRepository repository;
  @override
  State<_PersonnelPhoto> createState() => _PersonnelPhotoState();
}

class _PersonnelPhotoState extends State<_PersonnelPhoto> {
  Future<Map<String, dynamic>>? photo;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(_PersonnelPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId) load();
  }

  void load() {
    photo = widget.recordId == null
        ? null
        : widget.repository.record(widget.recordId!);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<Map<String, dynamic>>(
          future: photo,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const CircleAvatar(
                  child: Icon(Icons.broken_image_outlined));
            }
            final file = snapshot.data?['file'];
            if (file is! String) {
              return Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5F0FA),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.person_outline_rounded,
                      color: const Color(0xFF8BAAC1), size: widget.size * .65));
            }
            return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(base64Decode(file),
                    fit: BoxFit.cover,
                    cacheWidth: (widget.size * 2).round(),
                    errorBuilder: (_, error, trace) =>
                        const Icon(Icons.broken_image_outlined)));
          }));
}

