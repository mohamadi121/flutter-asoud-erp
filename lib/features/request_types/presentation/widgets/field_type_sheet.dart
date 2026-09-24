import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../domain/request_type_catalog.dart';

/// "افزودن فیلد جدید": pick a field type. Unsupported types are shown
/// disabled so the admin knows they are planned.
Future<RequestFieldType?> showFieldTypeSheet(BuildContext context) =>
    showModalBottomSheet<RequestFieldType>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('افزودن فیلد جدید',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          for (final type in requestFieldTypes)
            ListTile(
              enabled: type.supported,
              leading: Icon(type.icon,
                  color:
                      type.supported ? AsoudColors.primary : AsoudColors.muted),
              title: Text(type.label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              subtitle: type.supported
                  ? null
                  : const Text('به‌زودی', style: TextStyle(fontSize: 10)),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.of(context).pop(type),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
