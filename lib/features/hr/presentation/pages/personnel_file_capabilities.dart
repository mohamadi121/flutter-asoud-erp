part of 'personnel_page.dart';

/// Empty values always read as «ثبت نشده»; a dash is never shown.
const capEmpty = 'ثبت نشده';
const capPendingRegistration = 'در انتظار ثبت';

String capText(String? value, {String fallback = capEmpty}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty ||
      isLocalPersonnelId(text) ||
      text.contains('LOCAL-') ||
      text.contains('personnel-import-')) {
    return fallback;
  }
  return text;
}

String capEmployeeCode(String? code) =>
    capText(code, fallback: capPendingRegistration);

/// Latin/ASCII-number values (O+, emails, codes) are laid out LTR; anything
/// with Persian/Arabic script, including Persian digits, stays RTL.
bool capIsLtr(String value) =>
    !RegExp(r'\p{Script=Arabic}', unicode: true).hasMatch(value) &&
    RegExp(r'[A-Za-z0-9]').hasMatch(value);

Widget capValueText(String value,
        {TextStyle? style, TextAlign? textAlign, int? maxLines}) =>
    Directionality(
        textDirection: capIsLtr(value) ? TextDirection.ltr : TextDirection.rtl,
        child: Text(value,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis));

String capDate(String value) {
  final formatted = formatJalaliIso(value).trim();
  return formatted.isEmpty ? capEmpty : formatted;
}

String capError(Object error) => switch (error) {
      ApiException() => error.message,
      StateError() => error.message,
      FormatException() => error.message,
      _ => 'دریافت یا ذخیره اطلاعات انجام نشد؛ دوباره تلاش کنید.',
    };

Widget capSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Text(title,
        style: const TextStyle(
            color: _ink, fontSize: 14, fontWeight: FontWeight.w900)));

ContractSummary? currentContract(PersonnelFile file) {
  for (final contract in file.contracts) {
    if (contract.state == 'active' || contract.state == 'upcoming') {
      return contract;
    }
  }
  return null;
}

String daysRemainingLabel(ContractSummary contract) =>
    contract.daysRemaining == null
        ? capEmpty
        : contract.daysRemaining! < 0 || contract.status == 'expired'
            ? 'منقضی'
        : '${toPersianDigits(contract.daysRemaining!)} روز مانده';

String serviceLengthLabel(PersonnelFile file) =>
    file.employment.serviceLength?.label ??
    file.header.serviceLength?.label ??
    capEmpty;

/// The overview speaks in contract terms, not employee-status terms, so an
/// active contract reads «در جریان» rather than the generic «فعال».
String contractStateLabel(ContractSummary contract) => switch (contract.state) {
      'active' => 'در جریان',
      'upcoming' => 'آینده',
      'expired' => 'منقضی',
      'unsigned' => 'امضا نشده',
      _ => contract.stateLabel,
    };

Color contractStateColor(ContractSummary contract) => switch (contract.state) {
      'active' => AsoudColors.success,
      'expired' => AsoudColors.danger,
      'upcoming' || 'unsigned' => AsoudColors.warning,
      _ => AsoudColors.muted,
    };

Color documentStatusColor(PersonnelDocument document) =>
    switch (document.status) {
      'valid' => AsoudColors.success,
      'expiring' => AsoudColors.warning,
      'expired' => AsoudColors.danger,
      _ => AsoudColors.muted,
    };

IconData capEventIcon(String kind, String title) => switch (kind) {
      'joining' => Icons.person_add,
      'internal' => Icons.swap_horiz,
      'promotion' => Icons.trending_up,
      'transfer' => Icons.compare_arrows,
      'contract' => Icons.description,
      'salary' => Icons.payments,
      'attendance' => Icons.event_available_outlined,
      'evaluation' => Icons.star_border_rounded,
      'document' => Icons.description_outlined,
      'photo' => Icons.photo_outlined,
      'relieving' => Icons.logout,
      _ => capTitleIcon(title),
    };

/// The activity feed often carries no `kind`, so the icon is read off the
/// Persian title instead of always showing the generic history glyph.
IconData capTitleIcon(String title) {
  for (final (words, icon) in [
    (['قرارداد', 'تمدید'], Icons.description),
    (['ارتقا', 'تغییر سمت', 'سمت'], Icons.trending_up),
    (['حقوق', 'دستمزد', 'مزایا'], Icons.payments),
    (['حضور', 'غیاب', 'کارکرد'], Icons.event_available_outlined),
    (['مدرک', 'مدارک', 'گواهی'], Icons.description_outlined),
    (['تصویر', 'پروفایل'], Icons.photo_outlined),
  ]) {
    if (words.any(title.contains)) return icon;
  }
  return Icons.history;
}

Color capEventColor(String kind) => switch (kind) {
      'joining' => AsoudColors.success,
      'promotion' => AsoudColors.purple,
      'salary' => AsoudColors.warning,
      'relieving' => AsoudColors.danger,
      'transfer' => AsoudColors.cyan,
      _ => AsoudColors.primary,
    };

String capDetails(String details) {
  var result = details;
  for (final entry in const {
    'Designation': 'سمت',
    'Department': 'واحد',
    'Branch': 'شعبه',
    'Reports To': 'مدیر مستقیم',
    'Salary Structure': 'ساختار حقوقی',
  }.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

class CapChip extends StatelessWidget {
  const CapChip(this.label, {this.color = AsoudColors.muted, super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(12)),
      child: capValueText(label,
          maxLines: 1,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)));
}

class CapRows extends StatelessWidget {
  const CapRows({required this.values, super.key});
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (index, entry) in values.entries.indexed) ...[
          if (index > 0) const Divider(height: 1),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    flex: 2,
                    child: Text(entry.key,
                        style: const TextStyle(
                            color: AsoudColors.muted, fontSize: 11))),
                const SizedBox(width: 12),
                Expanded(
                    flex: 3,
                    child: capValueText(entry.value,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700))),
              ])),
        ],
      ]));
}

Future<void> savePersonnelFileAttachment(BuildContext context,
    Future<({String filename, String contentBase64})> Function() load) async {
  try {
    final result = await load();
    final bytes = base64Decode(result.contentBase64);
    if (bytes.isEmpty) throw const FormatException('فایل خالی است.');
    await FilePicker.platform.saveFile(
        fileName: result.filename.split(RegExp(r'[/\\]')).last, bytes: bytes);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('دریافت فایل ممکن نشد.')));
    }
  }
}

/// Shared data loader: fetches [PersonnelFile] from [PersonnelFileRepository]
/// and falls back to [personnelFileFromLegacy] on offline, unhandled or demo errors.
Future<PersonnelFile?> loadPersonnelFile({
  required String id,
  required PersonnelRepository repository,
  PersonnelFileRepository? fileRepository,
  Map<String, dynamic>? detail,
}) async {
  final data = detail ?? await repository.detail(id);
  if (fileRepository != null) {
    try {
      return await fileRepository.file(id);
    } catch (error) {
      if (canUseLegacyPersonnelFile(error) ||
          isLocalPersonnelId(id) ||
          data['offline'] == true ||
          _isLocalDemo(repository)) {
        return personnelFileFromLegacy(data);
      }
      return null;
    }
  }
  return null;
}

bool _isLocalDemo(PersonnelRepository repository) {
  try {
    return repository.localDemo;
  } catch (_) {
    return false;
  }
}
