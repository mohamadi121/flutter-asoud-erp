import 'package:flutter/material.dart';

import '../../../core/network/frappe_client.dart';
import '../../../core/widgets/template_text.dart';
import '../form_repository.dart';
import 'rules_engine.dart';

Iterable<FormMap> reviewFields(FormMap schema) => schemaFields(schema).where(
      (field) => !const {'File', 'Table', 'Signature', 'Password', 'Schedule'}
          .contains(field['type']),
    );

Map<String, String> requestReviewLabels(FormMap schema) => {
      for (final field in reviewFields(schema))
        '{{form.${field['key']}}}': '${field['label']}',
    };

({String text, Set<String> missing}) renderRequestReview(
  FormMap schema,
  FormMap values, {
  FrappeUserContext? employee,
  String? company,
}) {
  final readable = <String, String>{};
  for (final field in reviewFields(schema)) {
    if (!formFlag(field, schema, values, 'visible')) continue;
    final value = values[field['key']];
    if (value == null) continue;
    String display(Object? item) {
      if (item is bool) return item ? 'بله' : 'خیر';
      for (final option
          in (field['options'] as List? ?? const []).whereType<Map>()) {
        if (option['id'] == item) return '${option['label'] ?? ''}';
      }
      return item is String || item is num ? '$item' : '';
    }

    final token = '{{form.${field['key']}}}';
    if (field['default_source'] == 'employee') {
      if (employee != null &&
          employee.company == company &&
          employee.employeeId == value) {
        readable[token] = employee.employeeName ?? '';
      }
    } else {
      readable[token] = value is List
          ? value.map(display).where((v) => v.isNotEmpty).join('، ')
          : display(value);
    }
  }
  return renderTemplateText(
    '${schema['review_text'] ?? ''}',
    requestReviewLabels(schema),
    readable,
  );
}

class RequestReviewText extends StatefulWidget {
  const RequestReviewText({
    required this.schema,
    required this.values,
    required this.repository,
    this.designer = false,
    super.key,
  });
  final FormMap schema, values;
  final FormRepository repository;
  final bool designer;

  static bool exists(FormMap schema) =>
      schema['kind'] == 'Request' &&
      '${schema['review_text'] ?? ''}'.trim().isNotEmpty;

  @override
  State<RequestReviewText> createState() => _RequestReviewTextState();
}

class _RequestReviewTextState extends State<RequestReviewText> {
  late final _identity = _load();

  Future<FrappeUserContext?> _load() async {
    if (!widget.repository.client.isAuthenticated) return null;
    try {
      return await widget.repository.client.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _identity,
        builder: (context, snapshot) {
          final review = renderRequestReview(widget.schema, widget.values,
              company: widget.repository.company, employee: snapshot.data);
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('خلاصهٔ بازبینی',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(review.text),
                    if (widget.designer && review.missing.isNotEmpty)
                      Text('مقدار در دسترس نیست: ${review.missing.join('، ')}'),
                  ]),
            ),
          );
        },
      );
}
