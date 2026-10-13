import 'package:flutter/material.dart';
import '../workflows/presentation/pages/generic_request_page.dart';
import 'calendar_page.dart';

Future<void> showAsoudCreateMenu(BuildContext context, String company) async {
  final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('ایجاد', style: TextStyle(fontWeight: FontWeight.w800)),
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
