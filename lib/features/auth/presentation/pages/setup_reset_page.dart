import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/frappe_client.dart';
import '../../../../core/offline/offline_mutation_store.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/utils/persian_format.dart';
import '../../../../core/widgets/asoud_ui.dart';

/// Always reached through real sign-in; destructive authority remains server-side.
class SetupResetPage extends StatefulWidget {
  const SetupResetPage({super.key});
  @override
  State<SetupResetPage> createState() => _SetupResetPageState();
}

class _SetupResetPageState extends State<SetupResetPage> {
  final password = TextEditingController(), confirmation = TextEditingController();
  Map<String, dynamic>? plan;
  bool loading = true, busy = false, backup = false;
  String? error;
  int queued = 0;
  String? job;
  String? progress;
  Timer? poll;
  bool checking = false;
  late final client = context.read<FrappeApiClient>();
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { poll?.cancel(); password.dispose(); confirmation.dispose(); super.dispose(); }

  Future<Map<String, dynamic>> call(String method, [Map<String, dynamic> data = const {}]) async {
    // Deliberately raw online RPC: a password must never enter the offline queue.
    final response = await client.callMethod('asoud_erp.api.v1.setup_reset.$method', data: data);
    final envelope = response['message'];
    if (envelope is! Map || envelope['ok'] != true || envelope['data'] is! Map) throw const ApiException.protocol();
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }

  Future<int> pendingWrites() async {
    final user = await client.getCurrentUser();
    final server = client is FrappeClient ? (client as FrappeClient).serverIdentity : null;
    final pending = await OfflineMutationStore.instance.pending();
    return pending.where((row) {
      final data = row['payload'];
      return data is Map && data['_asoud_owner'] == user.userId &&
          (server == null || data['_asoud_server'] == server);
    }).length;
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; plan = null; backup = false; });
    try {
      final result = await call('preview');
      if (result['job'] is String) {
        follow(result['job'] as String);
        return;
      }
      final pending = await pendingWrites();
      if (mounted) setState(() { plan = result; queued = pending; });
    } catch (failure) {
      if (mounted) setState(() => error = failureDetail(failure));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> reset() async {
    if (busy || loading || plan == null || !backup || password.text.isEmpty || confirmation.text != 'شروع دوباره') return;
    setState(() { busy = true; error = null; });
    final previewToken = plan!['token'];
    try {
      if (await pendingWrites() > 0) {
        throw const ApiException(kind: ApiFailureKind.validation,
            message: 'این حساب عملیات آفلاینِ ارسال‌نشده دارد؛ ابتدا صف آن را تعیین تکلیف کنید.');
      }
      final result = await call('perform', {'token': plan!['token'], 'password': password.text,
          'confirmation': confirmation.text, 'backup_confirmed': 1});
      if (result['job'] is! String) throw const ApiException.protocol();
      follow(result['job'] as String);
    } catch (failure) {
      // A lost HTTP response does not imply that authorization/enqueue failed.
      // Recover only the job for THIS preview, never a previous completed reset.
      try {
        final accepted = await call('status', {'preview_token': previewToken});
        if (accepted['job'] is String) {
          follow(accepted['job'] as String);
          return;
        }
      } catch (_) { /* No matching accepted job: retain the original error. */ }
      if (mounted) setState(() { error = failureDetail(failure); plan = null; });
    } finally {
      password.clear();
      if (mounted && job == null) setState(() => busy = false);
    }
  }

  void follow(String value) {
    if (!mounted) return;
    setState(() { job = value; busy = true; plan = null; error = null; progress = null; });
    poll?.cancel();
    poll = Timer.periodic(const Duration(seconds: 2), (_) => checkStatus());
    checkStatus();
  }

  Future<void> checkStatus() async {
    if (checking || job == null || !mounted) return;
    checking = true;
    try {
      final result = await call('status', {'job': job});
      if (!mounted) return;
      if (result['state'] == 'completed') {
        poll?.cancel();
        setState(() { busy = false; job = null; });
        Navigator.pop(context, true);
      } else if (result['state'] == 'failed') {
        poll?.cancel();
        setState(() { error = '${result['message'] ?? 'بازنشانی اجرا نشد.'}'; job = null; busy = false; });
      } else if (!const {'queued', 'running'}.contains(result['state'])) {
        throw const ApiException.protocol();
      } else {
        setState(() { error = null; progress = result['message'] as String?; });
        if (poll?.isActive != true) {
          poll = Timer.periodic(const Duration(seconds: 2), (_) => checkStatus());
        }
      }
    } catch (failure) {
      poll?.cancel();
      if (mounted) {
        setState(() => error =
          'نتیجهٔ بازنشانی هنوز تأیید نشده است. ${failureDetail(failure)} وضعیت را دوباره دریافت کنید؛ حذف را تکرار نکنید.');
      }
    } finally { checking = false; }
  }

  @override
  Widget build(BuildContext context) {
    final blockers = (plan?['blockers'] as List?)?.map((v) => '$v').toList() ?? [];
    final companies = (plan?['companies'] as List?) ?? [];
    final counts = plan?['counts'] is Map ? plan!['counts'] as Map : const {};
    return PopScope(canPop: !busy || job != null, child: Directionality(textDirection: TextDirection.rtl,
      child: Scaffold(appBar: const AsoudHeader(title: 'بازنشانی موقت راه‌اندازی'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (job != null) ...[
            Text(progress?.isNotEmpty == true ? progress! : 'عملیات بازنشانی در صف یا در حال اجراست؛ نتیجه را از سرور پیگیری می‌کنیم. بستن صفحه عملیات سرور را لغو نمی‌کند.'),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            TextButton(onPressed: checkStatus, child: const Text('دریافت دوبارهٔ وضعیت')),
          ],
          const Text('این عملیات اطلاعات محدودهٔ تأییدشده را از سرور حذف می‌کند؛ صرفاً پاک‌کردن حافظهٔ گوشی نیست.',
              style: TextStyle(color: AsoudColors.danger, fontWeight: FontWeight.bold, height: 1.8)),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text(error!, style: const TextStyle(color: AsoudColors.danger)),
          if (!loading) OutlinedButton(onPressed: busy ? null : load, child: const Text('دریافت پیش‌نمایش تازه')),
          if (plan != null) ...[
            const Text('مشخصات شخصی و وضعیت راه‌اندازی مدیر فعلی نیز پاک می‌شود؛ شناسهٔ ورود، نام کاربری، رمز و اختیار مدیر سیستم حفظ می‌شوند.',
                style: TextStyle(height: 1.8, color: AsoudColors.danger)),
            const SizedBox(height: 12),
            const AsoudSectionTitle(title: 'دفاتر مشمول پاک‌سازی'),
            for (final company in companies) ListTile(leading: const Icon(Icons.business_outlined), title: Text('$company')),
            if (companies.isEmpty) const Text('دفتر ثبت‌شده‌ای با مالکیت این حساب پیدا نشد؛ بازنشانی مشخصات مدیر جداگانه در همین پیش‌نمایش است.'),
            const SizedBox(height: 12),
            const AsoudSectionTitle(title: 'اطلاعات مشمول'),
            for (final item in counts.entries)
              ListTile(dense: true, title: Text(_typeLabel('${item.key}')),
                  trailing: Text(formatCount(item.value is num ? (item.value as num).toInt() : 0))),
            const AsoudSectionTitle(title: 'اطلاعاتی که حفظ می‌شوند'),
            for (final item in (plan!['preserved'] as List?) ?? [])
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• $item')),
            if (queued > 0) Text('این حساب ${formatCount(queued)} عملیات آفلاین تعیین‌تکلیف‌نشده دارد؛ بازنشانی متوقف است.',
                style: const TextStyle(color: AsoudColors.danger)),
            for (final blocker in blockers) Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(blocker, style: const TextStyle(color: AsoudColors.danger))),
            if (blockers.isEmpty && queued == 0) ...[
              CheckboxListTile(value: backup, onChanged: busy ? null : (value) => setState(() => backup = value == true),
                  title: const Text('نسخهٔ پشتیبان قابل‌بازیابی دارم و حذف اطلاعات نمایش‌داده‌شده را تأیید می‌کنم.')),
              TextField(controller: confirmation, enabled: !busy, hintLocales: const [Locale('fa')],
                  onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'عبارت «شروع دوباره» را دقیق وارد کنید')),
              const SizedBox(height: 12),
              TextField(controller: password, enabled: !busy, obscureText: true, enableSuggestions: false,
                  autocorrect: false, onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'تأیید مجدد رمز حساب مدیر')),
              const SizedBox(height: 16),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: AsoudColors.danger),
                  onPressed: busy || !backup || confirmation.text != 'شروع دوباره' || password.text.isEmpty ? null : reset,
                  child: Text(busy ? 'در حال بازنشانی…' : 'حذف اطلاعات و شروع دوباره')),
            ],
          ],
        ]))));
  }
}

String _typeLabel(String name) => const {
  'Company': 'دفتر کار', 'ASOUD Company Setup': 'تنظیمات دفتر', 'Employee': 'پرسنل',
  'Department': 'واحد سازمانی', 'ASOUD Organization Chart': 'ساختار و جایگاه‌ها',
  'ASOUD Personnel Record': 'سوابق پروندهٔ پرسنلی', 'ASOUD Party Profile': 'مشخصات اشخاص',
  'ASOUD Office Role Assignment': 'نقش‌های دفتر', 'ASOUD Access Assignment': 'دسترسی‌های اختصاصی',
  'ASOUD Role Definition': 'نقش‌های ایجادشده', 'Role Profile': 'پروفایل نقش',
  'Role': 'نقش‌های فنی اختصاصی', 'Custom DocPerm': 'مجوزهای اختصاصی',
  'ASOUD Form': 'فرم‌ها', 'ASOUD Form Revision': 'نسخه‌های فرم',
  'ASOUD Workflow Definition': 'تعریف گردش‌کار', 'ASOUD Workflow Stage': 'مراحل گردش‌کار',
  'ASOUD Workflow Transition': 'مسیرهای گردش‌کار', 'ASOUD Document Template': 'الگوهای سند',
  'User Permission': 'دسترسی دفتر', 'User': 'حساب‌های پرسنلی ایجادشده',
  'Fiscal Year': 'سال مالی', 'Account': 'حساب‌های دفتر', 'Cost Center': 'مراکز هزینه',
  'Warehouse': 'انبارهای دفتر', 'Sales Taxes and Charges Template': 'تنظیمات مالیات فروش',
  'Purchase Taxes and Charges Template': 'تنظیمات مالیات خرید', 'Item Tax Template': 'تنظیمات مالیات کالا',
}[name] ?? 'اطلاعات وابستهٔ دفتر';
