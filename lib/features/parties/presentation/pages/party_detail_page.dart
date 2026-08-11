import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';
import 'party_form_page.dart';
import 'party_links_page.dart';

class PartyDetailPage extends StatefulWidget {
  const PartyDetailPage({required this.profile, super.key});
  final PartyProfile profile;

  @override
  State<PartyDetailPage> createState() => _PartyDetailPageState();
}

class _PartyDetailPageState extends State<PartyDetailPage> {
  late PartyProfile profile;
  bool disabling = false;

  @override
  void initState() {
    super.initState();
    profile = widget.profile;
  }

  PartyRole get primaryRole => profile.roles.contains(PartyRole.customer)
      ? PartyRole.customer
      : profile.roles.contains(PartyRole.supplier)
          ? PartyRole.supplier
          : profile.roles.contains(PartyRole.employee)
              ? PartyRole.employee
              : profile.roles.contains(PartyRole.shareholder)
                  ? PartyRole.shareholder
                  : PartyRole.other;

  @override
  Widget build(BuildContext context) {
    final detail = profile.floatingDetails.firstOrNull;
    return Scaffold(
      appBar: AsoudHeader(
        title: 'مشخصات ${_roleLabel(primaryRole)}',
        subtitle: 'کارت کامل شخص و اطلاعات ارتباطی',
        action: PopupMenuButton<_PartyMenuAction>(
          tooltip: 'عملیات بیشتر',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: _onMenu,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _PartyMenuAction.details,
              child: _MenuRow(
                  icon: Icons.account_tree_outlined, label: 'کدهای تفصیلی'),
            ),
            PopupMenuItem(
              value: _PartyMenuAction.share,
              child:
                  _MenuRow(icon: Icons.share_outlined, label: 'اشتراک‌گذاری'),
            ),
            PopupMenuItem(
              value: _PartyMenuAction.copy,
              child:
                  _MenuRow(icon: Icons.copy_all_outlined, label: 'کپی اطلاعات'),
            ),
            PopupMenuItem(
              value: _PartyMenuAction.disable,
              child: _MenuRow(icon: Icons.block_rounded, label: 'غیرفعال‌کردن'),
            ),
            PopupMenuItem(
              value: _PartyMenuAction.delete,
              child: _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: 'حذف',
                danger: true,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
              children: [
                if (detail != null) _DetailCodeBanner(detail: detail),
                if (detail != null) const SizedBox(height: 10),
                _ProfileSummary(profile: profile),
                const SizedBox(height: 10),
                _QuickActions(profile: profile),
                const SizedBox(height: 10),
                ..._informationCards(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AsoudColors.border)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: FilledButton.icon(
              onPressed: disabling ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('ویرایش اطلاعات'),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _informationCards() {
    final identity = <(String, String?, _ValueAction)>[
      (
        'نوع شخصیت',
        profile.kind == PartyKind.individual ? 'حقیقی' : 'حقوقی',
        _ValueAction.none
      ),
      (
        profile.kind == PartyKind.individual
            ? 'نام و نام خانوادگی'
            : 'نام شرکت',
        profile.displayName,
        _ValueAction.copy
      ),
      ('نام مستعار / تجاری', profile.aliasName, _ValueAction.copy),
      if (profile.kind == PartyKind.organization)
        ('نام مدیر', profile.managerName, _ValueAction.copy),
      ('کد ملی / شناسه ملی', profile.nationalId, _ValueAction.copy),
      if (profile.kind == PartyKind.organization)
        ('شماره ثبت', profile.registrationNumber, _ValueAction.copy),
      if (profile.kind == PartyKind.organization)
        ('کد اقتصادی', profile.economicCode, _ValueAction.copy),
      (
        'تاریخ تولد / تأسیس',
        profile.kind == PartyKind.individual
            ? profile.birthDate
            : profile.foundingDate,
        _ValueAction.none
      ),
    ];
    final contact = <(String, String?, _ValueAction)>[
      ('موبایل', profile.mobile, _ValueAction.phone),
      ('تلفن ثابت', profile.phone, _ValueAction.phone),
      ('تلفن دوم', profile.secondaryPhone, _ValueAction.phone),
      ('ایمیل', profile.email, _ValueAction.email),
      ('وب‌سایت', profile.website, _ValueAction.website),
    ];
    final finance = <(String, String?, _ValueAction)>[
      ('سقف اعتبار', _money(profile.creditLimit), _ValueAction.copy),
      ('مانده افتتاحیه', _money(profile.openingBalance), _ValueAction.copy),
      ('نوع مانده', _balanceLabel(profile.balanceType), _ValueAction.none),
      ('بانک', profile.bankName, _ValueAction.none),
      ('صاحب حساب', profile.accountHolder, _ValueAction.none),
      ('شماره حساب', profile.accountNumber, _ValueAction.copy),
      ('شماره کارت', profile.cardNumber, _ValueAction.copy),
      ('شماره شبا', profile.iban, _ValueAction.copy),
      ('توضیحات', profile.description, _ValueAction.none),
    ];
    final address = <(String, String?, _ValueAction)>[
      ('استان', profile.province, _ValueAction.none),
      ('شهر', profile.city, _ValueAction.none),
      ('منطقه', profile.region, _ValueAction.none),
      ('محله', profile.neighborhood, _ValueAction.none),
      ('نشانی کامل', profile.address, _ValueAction.copy),
      ('پلاک', profile.plaque, _ValueAction.none),
      ('واحد', profile.unit, _ValueAction.none),
      ('کد پستی', profile.postalCode, _ValueAction.copy),
    ];
    return [
      _InfoCard(
          title: 'اطلاعات هویتی',
          icon: Icons.badge_outlined,
          color: AsoudColors.primary,
          rows: identity),
      if (_hasValue(contact))
        _InfoCard(
            title: 'راه‌های ارتباطی',
            icon: Icons.contact_phone_outlined,
            color: AsoudColors.success,
            rows: contact),
      if (_hasValue(finance))
        _InfoCard(
            title: 'اعتبار و توضیحات',
            icon: Icons.account_balance_wallet_outlined,
            color: AsoudColors.warning,
            rows: finance),
      if (_hasValue(address) || _hasLocation)
        _AddressCard(profile: profile, rows: address, onMap: _openMap),
    ];
  }

  bool _hasValue(List<(String, String?, _ValueAction)> rows) =>
      rows.any((row) => row.$2?.trim().isNotEmpty == true);
  bool get _hasLocation =>
      profile.latitude != null && profile.longitude != null;

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PartyFormPage(
          company: profile.company,
          initialRole: primaryRole,
          profile: profile,
        ),
      ),
    );
    if (updated == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onMenu(_PartyMenuAction action) async {
    switch (action) {
      case _PartyMenuAction.details:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PartyLinksPage(
              profile: profile,
              repository: context.read<PartyRepository>(),
            ),
          ),
        );
      case _PartyMenuAction.share:
        await _share(_shareText);
      case _PartyMenuAction.copy:
        await _copy(context, _shareText, 'اطلاعات شخص کپی شد.');
      case _PartyMenuAction.disable:
      case _PartyMenuAction.delete:
        await _confirmDisable(deleteWording: action == _PartyMenuAction.delete);
    }
  }

  String get _shareText => [
        profile.displayName,
        if (profile.mobile?.isNotEmpty == true) 'موبایل: ${profile.mobile}',
        if (profile.phone?.isNotEmpty == true) 'تلفن: ${profile.phone}',
        if (profile.email?.isNotEmpty == true) 'ایمیل: ${profile.email}',
        if (profile.address?.isNotEmpty == true) 'نشانی: ${profile.address}',
      ].join('\n');

  Future<void> _confirmDisable({required bool deleteWording}) async {
    if (profile.id == null || disabling) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(deleteWording ? 'حذف شخص' : 'غیرفعال‌کردن شخص'),
        content: Text(
          'آیا از ${deleteWording ? 'حذف' : 'غیرفعال‌کردن'} ${profile.displayName} مطمئن هستید؟ این عملیات ممکن است روی اسناد و گزارش‌های مرتبط تأثیر بگذارد. اطلاعات به‌صورت فیزیکی حذف نمی‌شود.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AsoudColors.danger),
            child: Text(deleteWording ? 'حذف' : 'غیرفعال‌کردن'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => disabling = true);
    try {
      await context.read<PartyRepository>().disableParty(profile.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شخص با موفقیت غیرفعال شد.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => disabling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('غیرفعال‌کردن شخص انجام نشد.')),
        );
      }
    }
  }

  Future<void> _openMap() async {
    if (!_hasLocation) return;
    await _launchUri(
      'https://www.google.com/maps/search/?api=1&query=${profile.latitude},${profile.longitude}',
    );
  }
}

class _DetailCodeBanner extends StatelessWidget {
  const _DetailCodeBanner({required this.detail});
  final FloatingDetail detail;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AsoudColors.primary,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(children: [
          const Icon(Icons.numbers_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('کد تفصیلی: ${detail.code}',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
              Text('گروه اصلی: ${detail.groupTitle ?? detail.groupId}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
          ),
          IconButton(
            tooltip: 'کپی کد تفصیلی',
            onPressed: () => _copy(context, detail.code, 'کد تفصیلی کپی شد.'),
            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
          ),
        ]),
      );
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});
  final PartyProfile profile;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: AsoudColors.primary.withValues(alpha: .1),
              child: Text(
                  profile.displayName.trim().isEmpty
                      ? 'ش'
                      : profile.displayName.trim()[0],
                  style: const TextStyle(
                      color: AsoudColors.primary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                        profile.kind == PartyKind.individual
                            ? 'شخص حقیقی'
                            : 'شخص حقوقی',
                        style: const TextStyle(
                            fontSize: 12, color: AsoudColors.muted)),
                    const SizedBox(height: 9),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _Tag(
                          label: profile.disabled ? 'غیرفعال' : 'فعال',
                          color: profile.disabled
                              ? AsoudColors.danger
                              : AsoudColors.success),
                      for (final role in profile.roles)
                        _Tag(label: _roleLabel(role), color: _roleColor(role)),
                      for (final role in profile.employeeRoles)
                        _Tag(label: role, color: AsoudColors.cyan),
                    ]),
                  ]),
            ),
          ]),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.profile});
  final PartyProfile profile;

  @override
  Widget build(BuildContext context) {
    final phones = [profile.mobile, profile.phone, profile.secondaryPhone]
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .toList();
    return Row(children: [
      Expanded(
          child: _QuickButton(
              label: 'تماس',
              icon: Icons.call_outlined,
              color: AsoudColors.success,
              enabled: phones.isNotEmpty,
              onTap: () => _chooseAndLaunch(context, phones, 'tel'))),
      const SizedBox(width: 6),
      Expanded(
          child: _QuickButton(
              label: 'پیامک',
              icon: Icons.sms_outlined,
              color: AsoudColors.primary,
              enabled: profile.mobile?.isNotEmpty == true,
              onTap: () => _launch('sms', profile.mobile!))),
      const SizedBox(width: 6),
      Expanded(
          child: _QuickButton(
              label: 'ایمیل',
              icon: Icons.email_outlined,
              color: AsoudColors.purple,
              enabled: profile.email?.isNotEmpty == true,
              onTap: () => _launch('mailto', profile.email!))),
      const SizedBox(width: 6),
      Expanded(
          child: _QuickButton(
              label: 'موقعیت',
              icon: Icons.location_on_outlined,
              color: AsoudColors.warning,
              enabled: profile.latitude != null && profile.longitude != null,
              onTap: () => _launchUri(
                  'https://www.google.com/maps/search/?api=1&query=${profile.latitude},${profile.longitude}'))),
    ]);
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.enabled,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          decoration: BoxDecoration(
              color: enabled
                  ? color.withValues(alpha: .08)
                  : const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: enabled ? color : AsoudColors.muted, size: 21),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: enabled ? AsoudColors.text : AsoudColors.muted)),
          ]),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.rows});
  final String title;
  final IconData icon;
  final Color color;
  final List<(String, String?, _ValueAction)> rows;
  @override
  Widget build(BuildContext context) {
    final visible =
        rows.where((row) => row.$2?.trim().isNotEmpty == true).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AsoudIconBox(icon: icon, color: color, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900)),
            )
          ]),
          const SizedBox(height: 10),
          for (final row in visible)
            _ValueRow(label: row.$1, value: row.$2!, action: row.$3),
        ]),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard(
      {required this.profile, required this.rows, required this.onMap});
  final PartyProfile profile;
  final List<(String, String?, _ValueAction)> rows;
  final VoidCallback onMap;
  @override
  Widget build(BuildContext context) {
    final hasLocation = profile.latitude != null && profile.longitude != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            AsoudIconBox(
                icon: Icons.location_on_outlined,
                color: AsoudColors.purple,
                size: 32),
            SizedBox(width: 8),
            Text('نشانی و موقعیت',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900))
          ]),
          const SizedBox(height: 10),
          for (final row
              in rows.where((row) => row.$2?.trim().isNotEmpty == true))
            _ValueRow(label: row.$1, value: row.$2!, action: row.$3),
          const SizedBox(height: 8),
          InkWell(
            onTap: hasLocation ? onMap : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F6FF),
                  border: Border.all(color: AsoudColors.border),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        hasLocation
                            ? Icons.map_outlined
                            : Icons.location_off_outlined,
                        color: hasLocation
                            ? AsoudColors.primary
                            : AsoudColors.muted,
                        size: 34),
                    const SizedBox(height: 7),
                    Text(
                        hasLocation
                            ? 'مشاهده در نقشه'
                            : 'موقعیتی برای این شخص ثبت نشده است.',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    if (hasLocation)
                      Text('${profile.latitude}, ${profile.longitude}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 9, color: AsoudColors.muted)),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(
      {required this.label, required this.value, required this.action});
  final String label, value;
  final _ValueAction action;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: action == _ValueAction.none
            ? null
            : () => _actOnValue(context, action, value),
        onLongPress: () => _copy(context, value, 'مقدار کپی شد.'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(children: [
            Expanded(
                flex: 2,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AsoudColors.muted))),
            const SizedBox(width: 8),
            Expanded(
                flex: 3,
                child: Text(value,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700))),
            if (action != _ValueAction.none)
              const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(Icons.open_in_new_rounded,
                      size: 15, color: AsoudColors.primary)),
          ]),
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w800)));
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.icon, required this.label, this.danger = false});
  final IconData icon;
  final String label;
  final bool danger;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 19, color: danger ? AsoudColors.danger : null),
        const SizedBox(width: 9),
        Text(label, style: TextStyle(color: danger ? AsoudColors.danger : null))
      ]);
}

enum _PartyMenuAction { details, share, copy, disable, delete }

enum _ValueAction { none, copy, phone, email, website }

Future<void> _actOnValue(
    BuildContext context, _ValueAction action, String value) async {
  switch (action) {
    case _ValueAction.none:
      return;
    case _ValueAction.copy:
      return _copy(context, value, 'مقدار کپی شد.');
    case _ValueAction.phone:
      return _launch('tel', value);
    case _ValueAction.email:
      return _launch('mailto', value);
    case _ValueAction.website:
      final uri =
          Uri.tryParse(value.contains('://') ? value : 'https://$value');
      if (uri != null) await _launchUri(uri.toString());
  }
}

Future<void> _chooseAndLaunch(
    BuildContext context, List<String> values, String scheme) async {
  if (values.length == 1) return _launch(scheme, values.first);
  final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(
                title: Text('انتخاب شماره',
                    style: TextStyle(fontWeight: FontWeight.w900))),
            for (final value in values)
              ListTile(
                  leading: const Icon(Icons.call_outlined),
                  title: Text(value, textDirection: TextDirection.ltr),
                  onTap: () => Navigator.pop(context, value)),
          ])));
  if (selected != null) await _launch(scheme, selected);
}

Future<void> _launch(String scheme, String value) async {
  await _launchUri(Uri(scheme: scheme, path: value).toString());
}

const _nativeActions = MethodChannel('ir.asoud.asoud_erp/actions');

Future<void> _launchUri(String uri) =>
    _nativeActions.invokeMethod<void>('launchUri', {'uri': uri});

Future<void> _share(String text) =>
    _nativeActions.invokeMethod<void>('shareText', {'text': text});

Future<void> _copy(BuildContext context, String value, String message) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

String? _money(double? value) =>
    value == null ? null : '${_formatNumber(value)} ریال';
String _formatNumber(double value) {
  final raw = value.round().abs().toString();
  final parts = <String>[];
  for (var end = raw.length; end > 0; end -= 3) {
    parts.insert(0, raw.substring((end - 3).clamp(0, raw.length), end));
  }
  return '${value < 0 ? '-' : ''}${parts.join(',')}';
}

String? _balanceLabel(String? value) => switch (value) {
      'Debit' => 'بدهکار',
      'Credit' => 'بستانکار',
      'None' => 'بدون مانده',
      _ => value,
    };

String _roleLabel(PartyRole role) => switch (role) {
      PartyRole.customer => 'مشتری',
      PartyRole.supplier => 'تأمین‌کننده',
      PartyRole.employee => 'پرسنل',
      PartyRole.shareholder => 'سهام‌دار',
      PartyRole.other => 'شخص',
    };

Color _roleColor(PartyRole role) => switch (role) {
      PartyRole.customer => AsoudColors.purple,
      PartyRole.supplier => AsoudColors.primary,
      PartyRole.employee => AsoudColors.success,
      PartyRole.shareholder => AsoudColors.warning,
      PartyRole.other => AsoudColors.muted,
    };
