import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/widgets/asoud_ui.dart';
import '../../domain/entities/party_profile.dart';
import '../../domain/repositories/party_repository.dart';

class PartyLinksPage extends StatefulWidget {
  const PartyLinksPage(
      {required this.profile, required this.repository, super.key});
  final PartyProfile profile;
  final PartyRepository repository;

  @override
  State<PartyLinksPage> createState() => _PartyLinksPageState();
}

class _PartyLinksPageState extends State<PartyLinksPage> {
  List<FloatingDetail> details = const [];
  bool loading = true, saving = false;
  String? error;

  String get roleTitle => widget.profile.roles.contains(PartyRole.employee)
      ? 'پرسنل'
      : widget.profile.roles.contains(PartyRole.supplier)
          ? 'تأمین‌کننده'
          : 'مشتری';

  String get detailType => widget.profile.roles.contains(PartyRole.employee)
      ? 'Employee'
      : widget.profile.roles.contains(PartyRole.supplier)
          ? 'Supplier'
          : 'Customer';

  String? get primaryGroup =>
      details.firstOrNull?.groupId ?? widget.profile.detailGroups.firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository
          .listDetails(search: widget.profile.displayName);
      if (mounted) setState(() => details = result);
    } catch (_) {
      if (mounted) setState(() => error = 'دریافت کدهای تفصیلی انجام نشد.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = details.firstOrNull;
    return Scaffold(
      appBar: AsoudHeader(
        title: 'تفصیلی‌های $roleTitle',
        subtitle: widget.profile.displayName,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
              children: [
                _GroupBanner(
                  title: group?.groupTitle ?? 'گروه اصلی $roleTitle',
                  code: group?.groupId ?? primaryGroup,
                ),
                const SizedBox(height: 10),
                const _HelpCard(),
                const SizedBox(height: 12),
                Row(children: [
                  const Expanded(
                    child: Text('کدهای متصل',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w900)),
                  ),
                  Text('${details.length} کد',
                      style: const TextStyle(
                          fontSize: 10, color: AsoudColors.muted)),
                ]),
                const SizedBox(height: 8),
                if (loading) const _LinksSkeleton(),
                if (error != null)
                  _StateCard(
                    text: error!,
                    actionLabel: 'تلاش مجدد',
                    onAction: _load,
                  ),
                if (!loading && error == null && details.isEmpty)
                  const _StateCard(
                      text: 'هنوز کد تفصیلی برای این شخص ثبت نشده است.'),
                for (var index = 0; index < details.length; index++)
                  _DetailRow(detail: details[index], index: index),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'کد بعدی فقط هنگام ثبت در ERPNext و داخل گروه ${group?.groupTitle ?? primaryGroup ?? ''} تولید می‌شود.',
                      style: const TextStyle(
                          fontSize: 10, color: AsoudColors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AsoudColors.border)),
          ),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : _connectExisting,
                child: const Text('اتصال کد موجود'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: saving ? null : _createNew,
                icon: const Icon(Icons.add_rounded),
                label: const Text('افزودن کد جدید'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _createNew() async {
    final group = primaryGroup;
    final profileId = widget.profile.id;
    if (group == null || profileId == null) {
      _message('گروه اصلی یا شناسه شخص مشخص نیست.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن کد تفصیلی جدید'),
        content: Text(
          'کد جدید برای ${widget.profile.displayName} در گروه $group توسط ERPNext تولید شود؟',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ایجاد کد')),
        ],
      ),
    );
    if (approved != true) return;
    setState(() => saving = true);
    try {
      await widget.repository.createDetail(
        title: widget.profile.displayName,
        type: detailType,
        detailGroup: group,
        profileId: profileId,
      );
      await _load();
      _message('کد تفصیلی جدید ایجاد شد.');
    } catch (_) {
      _message('ایجاد کد تفصیلی انجام نشد.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _connectExisting() async {
    final group = primaryGroup;
    final profileId = widget.profile.id;
    if (group == null || profileId == null) {
      _message('گروه اصلی یا شناسه شخص مشخص نیست.');
      return;
    }
    setState(() => saving = true);
    try {
      final all = await widget.repository.listDetails(detailGroup: group);
      final linkedIds = details.map((item) => item.id).toSet();
      final available = all
          .where((item) =>
              !linkedIds.contains(item.id) &&
              (item.linkedDocument == null || item.linkedDocument!.isEmpty))
          .toList(growable: false);
      if (!mounted) return;
      final selected = await showModalBottomSheet<FloatingDetail>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            children: [
              const Text('انتخاب کد موجود',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (available.isEmpty)
                const _StateCard(
                    text: 'کد آزاد و قابل اتصالی در این گروه وجود ندارد.'),
              for (final item in available)
                Card(
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.code, textDirection: TextDirection.ltr),
                    onTap: () => Navigator.pop(sheetContext, item),
                  ),
                ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      await widget.repository
          .linkDetail(detailId: selected.id, profileId: profileId);
      await _load();
      _message('کد موجود به شخص متصل شد.');
    } catch (_) {
      _message('اتصال کد موجود انجام نشد.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

class _GroupBanner extends StatelessWidget {
  const _GroupBanner({required this.title, required this.code});
  final String title;
  final String? code;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const AsoudIconBox(
              icon: Icons.account_tree_outlined,
              color: AsoudColors.primary,
              size: 34),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900)),
              if (code != null)
                Text('کد گروه: $code',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        fontSize: 9, color: AsoudColors.primary)),
            ]),
          ),
        ]),
      );
}

class _HelpCard extends StatelessWidget {
  const _HelpCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AsoudColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'هر کد تفصیلی مستقل است و می‌تواند به حساب‌های معین مجاز متصل شود. کد جدید فقط در Backend تولید می‌شود.',
              style: TextStyle(fontSize: 10, color: AsoudColors.muted),
            ),
          ),
        ]),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.detail, required this.index});
  final FloatingDetail detail;
  final int index;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(children: [
            Container(
              width: 31,
              height: 31,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AsoudColors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: AsoudColors.primary, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.title,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                    Text(detail.groupTitle ?? 'گروه ${detail.groupId}',
                        style: const TextStyle(
                            fontSize: 8, color: AsoudColors.muted)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(detail.code,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AsoudColors.primary,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      );
}

class _LinksSkeleton extends StatelessWidget {
  const _LinksSkeleton();
  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          4,
          (_) => Container(
            height: 58,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F8),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.text, this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Text(text, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}
