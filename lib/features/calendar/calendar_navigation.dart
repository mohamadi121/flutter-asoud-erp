import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/frappe_client.dart';
import '../directives/data/directive_repository.dart';
import '../directives/domain/directive_models.dart';
import '../directives/presentation/directive_pages.dart';
import '../workflows/presentation/pages/generic_request_page.dart';
import 'calendar_page.dart';

Future<void> showAsoudCreateMenu(BuildContext context, String company) async {
  final client = context.read<FrappeApiClient?>();
  final directiveAccess = client?.isAuthenticated == true
      ? ApiDirectiveRepository(client!).options(company)
      : null;
  final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('ایجاد', style: TextStyle(fontWeight: FontWeight.w800)),
            if (directiveAccess != null)
              FutureBuilder<DirectiveOptions>(
                  future: directiveAccess,
                  builder: (_, snapshot) => ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: const Text('صدور دستور'),
                      subtitle: Text(snapshot.hasError
                          ? 'دسترسی یا سرویس دستورات در دسترس نیست.'
                          : snapshot.data?.allowedActions.contains('issue') ==
                                  true
                              ? 'ابلاغ به زیرمجموعه مجاز'
                              : 'بررسی دسترسی صدور دستور'),
                      enabled:
                          snapshot.data?.allowedActions.contains('issue') ==
                              true,
                      onTap: () => Navigator.pop(ctx, 'directive'))),
            ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('درخواست جدید'),
                onTap: () => Navigator.pop(ctx, 'request')),
            ListTile(
                leading: const Icon(Icons.event_note),
                title: const Text('یادآور شخصی'),
                onTap: () => Navigator.pop(ctx, 'reminder')),
          ])));
  if (choice == null || !context.mounted) return;
  if (choice == 'directive') {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => DirectiveCreatePage(company: company)));
    return;
  }
  if (choice == 'reminder') {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) =>
                AsoudCalendar(company: company, createReminder: true)));
    return;
  }
  await Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) =>
              GenericRequestsPage(company: company, createOnOpen: true)));
}
