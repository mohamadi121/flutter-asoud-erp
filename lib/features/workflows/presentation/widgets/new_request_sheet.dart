import 'package:flutter/material.dart';

import '../../../../core/theme/asoud_colors.dart';
import '../../../request_types/domain/request_type_catalog.dart';
import '../../data/new_request_catalog.dart';

Future<Map<String, dynamic>?> showNewRequestSheet(
  BuildContext context, {
  required Future<List<Map<String, dynamic>>> Function() loadTypes,
}) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewRequestSheet(loadTypes: loadTypes),
    );

class NewRequestSheet extends StatefulWidget {
  const NewRequestSheet({required this.loadTypes, super.key});
  final Future<List<Map<String, dynamic>>> Function() loadTypes;
  @override
  State<NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends State<NewRequestSheet> {
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> future = widget.loadTypes();
  String module = 'همه', subgroup = 'همه درخواست‌ها';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() => setState(() {
        future = widget.loadTypes();
      });
  String get listTitle =>
      module == 'همه' ? 'همه درخواست‌ها' : 'درخواست‌های $module';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: .9,
        minChildSize: .5,
        maxChildSize: .95,
        expand: false,
        builder: (context, controller) => ScaffoldMessenger(
            child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
              top: false,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: future,
                builder: (context, snapshot) {
                  final filtered = filterNewRequestTypes(
                      snapshot.data ?? const [],
                      module: module,
                      subgroup: subgroup,
                      query: search.text);
                  return ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      children: [
                        Center(
                            child: Container(
                                width: 38,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFCBD5E1),
                                    borderRadius: BorderRadius.circular(4)))),
                        Stack(alignment: Alignment.center, children: [
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('انتخاب درخواست جدید',
                                  style: TextStyle(
                                      color: Color(0xFF15264A),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700))),
                          Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                  key: const Key('new-request-close'),
                                  tooltip: 'بستن',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded))),
                        ]),
                        TextField(
                            controller: search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                                hintText: 'جستجوی درخواست‌ها...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: const Color(0xFFF5F8FC),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFD8E1EC))))),
                        const SizedBox(height: 16),
                        const Text('انتخاب ماژول',
                            style: TextStyle(
                                color: Color(0xFF15264A),
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.22,
                            mainAxisSpacing: 7,
                            crossAxisSpacing: 7,
                            children: [
                              for (final item in newRequestModules)
                                _moduleCard(item),
                            ]),
                        if (module != 'همه') ...[
                          const SizedBox(height: 14),
                          const Text('زیرگروه درخواست',
                              style: TextStyle(
                                  color: Color(0xFF15264A),
                                  fontWeight: FontWeight.w700)),
                          DropdownButtonFormField<String>(
                              initialValue: subgroup,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4)),
                              items: [
                                for (final value in subgroupsForModule(module))
                                  DropdownMenuItem(
                                      value: value, child: Text(value))
                              ],
                              onChanged: (value) =>
                                  setState(() => subgroup = value!)),
                        ],
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: Text(listTitle,
                                  style: const TextStyle(
                                      color: Color(0xFF15264A),
                                      fontWeight: FontWeight.w700))),
                          Container(
                              key: const Key('new-request-count'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                  color:
                                      AsoudColors.primary.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('${filtered.length}'))
                        ]),
                        const SizedBox(height: 8),
                        if (snapshot.hasError)
                          Center(
                              child: Column(children: [
                            const Text('دریافت درخواست‌ها ممکن نشد.'),
                            TextButton(
                                onPressed: reload,
                                child: const Text('تلاش دوباره'))
                          ]))
                        else if (!snapshot.hasData)
                          const Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(child: CircularProgressIndicator()))
                        else if (filtered.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(child: Text('درخواستی پیدا نشد')))
                        else
                          for (final type in filtered) _row(type),
                        if (snapshot.hasData &&
                            module == 'همه' &&
                            search.text.isEmpty)
                          _row({
                            'workflow_title': 'فرم‌های منتشرشده سازمان',
                            'short_title': 'جستجو و انتخاب فرم‌های نسخه‌دار',
                            'icon_key': 'form',
                            'versioned_forms': true,
                          }),
                      ]);
                },
              )),
        ))),
      ),
    );
  }

  Widget _moduleCard(({String title, IconData icon, Color color}) item) {
    final selected = module == item.title;
    return InkWell(
      key: Key('new-request-module-${item.title}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        module = item.title;
        subgroup = 'همه درخواست‌ها';
      }),
      child: DecoratedBox(
          decoration: BoxDecoration(
              color: selected
                  ? AsoudColors.primary
                  : item.color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(item.icon,
                size: 21, color: selected ? Colors.white : item.color),
            const SizedBox(height: 3),
            Text(item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                    fontSize: 10,
                    color: selected ? Colors.white : const Color(0xFF263A5B),
                    fontWeight: FontWeight.w600))
          ])),
    );
  }

  Widget _row(Map<String, dynamic> type) {
    final visual = requestIconFor('${type['icon_key'] ?? ''}');
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFD8E1EC))),
          child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              leading: Icon(visual.icon, color: visual.color),
              title: Text('${type['workflow_title']}',
                  style: const TextStyle(
                      color: Color(0xFF15264A), fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${type['short_title'] ?? type['process_description'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AsoudColors.muted)),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () {
                if (type['offline_unavailable'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('این فرم فقط با اتصال به سرور در دسترس است.')));
                  return;
                }
                Navigator.pop(context, type);
              }),
        ));
  }
}
