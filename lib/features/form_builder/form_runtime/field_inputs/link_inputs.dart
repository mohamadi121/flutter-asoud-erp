import 'package:flutter/material.dart';

import '../../../../core/offline/offline_failure.dart';
import '../../form_repository.dart';

Widget? buildLinkInput({
  required BuildContext context,
  required FormMap f,
  required FormMap computed,
  required dynamic value,
  required String label,
  required FormRepository repository,
  required String? formName,
  required ValueChanged<dynamic> onChanged,
}) {
  if (f['type'] != 'Link') {
    return null;
  }

  return ListTile(
    title: Text(label),
    subtitle: Text('${value ?? 'انتخاب از اطلاعات مجاز'}'),
    trailing: const Icon(Icons.search),
    onTap: () async {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => LinkPicker(
          repository: repository,
          source: '${f['source']}',
          formName: formName,
          filterField: formMap(f['link_filter'])['field'] as String?,
          filterValue: computed[formMap(f['link_filter'])['value_field']],
        ),
      );
      if (result != null) {
        onChanged(result);
      }
    },
  );
}

class LinkPicker extends StatefulWidget {
  const LinkPicker({
    required this.repository,
    required this.source,
    this.formName,
    this.filterField,
    this.filterValue,
    super.key,
  });

  final FormRepository repository;
  final String source;
  final String? formName;
  final String? filterField;
  final dynamic filterValue;

  @override
  State<LinkPicker> createState() => _LinkPickerState();
}

class _LinkPickerState extends State<LinkPicker> {
  late Future<List<FormMap>> rows;

  @override
  void initState() {
    super.initState();
    rows = load('');
  }

  Future<List<FormMap>> load(String query) async => formMaps(
        await widget.repository.call('get_link_options', {
          'company': widget.repository.company,
          'source': widget.source,
          'query': query,
          'form': widget.formName,
          'filter_field': widget.filterField,
          'filter_value': widget.filterValue,
        }),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'جست‌وجو و تأیید',
                    suffixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (q) => setState(() => rows = load(q)),
                ),
                Expanded(
                  child: FutureBuilder<List<FormMap>>(
                    future: rows,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(offlineFailureMessage(snapshot.error!));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ListView(
                        children: [
                          for (final r in snapshot.data!)
                            ListTile(
                              title: Text('${r['label']}'),
                              subtitle: Text('${r['name']}'),
                              onTap: () =>
                                  Navigator.pop(context, '${r['name']}'),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('بستن'),
                ),
              ],
            ),
          ),
        ),
      );
}
