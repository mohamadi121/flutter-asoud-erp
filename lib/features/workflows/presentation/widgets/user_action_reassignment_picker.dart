import 'package:flutter/material.dart';

import '../../../../core/utils/failure_message.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../form_builder/form_repository.dart';
import '../../data/workflow_action_repository.dart';

/// Reads only eligible native recipients. The caller performs the transfer.
class UserActionReassignmentPicker extends StatefulWidget {
  const UserActionReassignmentPicker({required this.repository, super.key});
  final WorkflowActionRepository repository;

  @override
  State<UserActionReassignmentPicker> createState() => _PickerState();
}

class _PickerState extends State<UserActionReassignmentPicker> {
  final search = TextEditingController();
  List<FormMap> rows = [];
  String? selected, error;
  bool loading = false, more = false;
  String query = '';

  @override
  void initState() {
    super.initState();
    load().ignore();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool next = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final term = next ? query : search.text.trim();
      final result =
          await widget.repository.candidates(term, next ? rows.length : 0);
      if (!mounted) return;
      setState(() {
        query = term;
        rows = [
          ...(next ? rows : <FormMap>[]),
          ...formMaps(result['reassignment_candidates'])
        ];
        more = result['has_more'] == true;
        if (!next) selected = null;
      });
    } catch (failure) {
      if (mounted) setState(() => error = failureMessage(failure));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: SingleChildScrollView(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                          const Text('واگذاری مجدد',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 10),
                          const Text(
                              'همین وظیفه منتقل می‌شود. پیش‌نویس ذخیره‌شده و پیوست‌ها باقی می‌مانند؛ تغییرات ذخیره‌نشده منتقل نمی‌شوند.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AsoudColors.muted,
                                  height: 1.7)),
                          const SizedBox(height: 12),
                          TextField(
                              controller: search,
                              enabled: !loading,
                              maxLength: 100,
                              onSubmitted: (_) => load(),
                              decoration: InputDecoration(
                                  hintText: 'جست‌وجوی فرد مجاز…',
                                  suffixIcon: IconButton(
                                      onPressed: loading ? null : load,
                                      icon: const Icon(Icons.search)))),
                          if (loading) const LinearProgressIndicator(),
                          if (error != null) ...[
                            Text(error!,
                                style:
                                    const TextStyle(color: AsoudColors.danger)),
                            TextButton(
                                onPressed: loading ? null : load,
                                child: const Text('تلاش دوباره')),
                          ],
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!loading && error == null && rows.isEmpty)
                                  const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                          'فرد دیگری با شرایط و دسترسی لازم یافت نشد.')),
                                for (final row in rows)
                                  ListTile(
                                      title: Text('${row['label']}'),
                                      leading: Icon(
                                          selected == row['user']
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: AsoudColors.primary),
                                      onTap: loading || error != null
                                          ? null
                                          : () => setState(() =>
                                              selected = '${row['user']}')),
                                if (more)
                                  TextButton(
                                      onPressed: loading
                                          ? null
                                          : () => load(next: true),
                                      child: const Text('نمایش بیشتر')),
                              ]),
                        ]))),
                    FilledButton(
                        onPressed: selected == null || loading || error != null
                            ? null
                            : () => Navigator.pop(context, selected),
                        child: const Text('تأیید و واگذاری وظیفه')),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('انصراف')),
                  ]))));
}
