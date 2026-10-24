import 'package:flutter/material.dart';

import '../../../../core/offline/offline_failure.dart';
import '../../form_repository.dart';
import '../record_links.dart';

Widget? buildLinkInput({
  required BuildContext context,
  required FormMap f,
  required FormMap computed,
  required dynamic value,
  required String label,
  required FormRepository repository,
  required String? formName,
  required ValueChanged<dynamic> onChanged,
  void Function(String name, FormMap extra)? onPicked,
}) {
  final isAsoudText = f['type'] == 'Text' && f['source_mode'] == 'asoud';
  if (f['type'] != 'Link' && !isAsoudText) {
    return null;
  }

  final source = f['source'] != null && '${f['source']}'.isNotEmpty
      ? '${f['source']}'
      : 'Employee';
  return _LinkTile(
    label: label,
    value: value,
    onTap: () => showModalBottomSheet<FormMap>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => LinkPicker(
        repository: repository,
        source: source,
        formName: formName,
        filterField: formMap(f['link_filter'])['field'] as String?,
        filterValue: computed[formMap(f['link_filter'])['value_field']],
        excludeSelf: f['exclude_self'] == true,
      ),
    ),
    onPicked: (row) {
      final name = '${row['name']}';
      if (onPicked != null) {
        onPicked(name, formMap(row['extra']));
      } else {
        onChanged(name);
      }
    },
  );
}

class _LinkTile extends StatefulWidget {
  const _LinkTile({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onPicked,
  });

  final String label;
  final dynamic value;
  final Future<FormMap?> Function() onTap;
  final ValueChanged<FormMap> onPicked;

  @override
  State<_LinkTile> createState() => _LinkTileState();
}

class _LinkTileState extends State<_LinkTile> {
  String? pickedName, pickedLabel;

  @override
  Widget build(BuildContext context) {
    final shown = pickedName == '${widget.value}' && pickedLabel != null
        ? pickedLabel
        : widget.value;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        title: Text(widget.label),
        subtitle: Text('${shown ?? 'انتخاب از اطلاعات مجاز'}'),
        trailing: const Icon(Icons.search),
        onTap: () async {
          final row = await widget.onTap();
          if (row == null) return;
          setState(() {
            pickedName = '${row['name']}';
            pickedLabel = '${row['label'] ?? row['name']}';
          });
          widget.onPicked(row);
        },
      ),
    );
  }
}

class LinkPicker extends StatefulWidget {
  const LinkPicker({
    required this.repository,
    required this.source,
    this.formName,
    this.filterField,
    this.filterValue,
    this.excludeSelf = false,
    super.key,
  });

  final FormRepository repository;
  final String source;
  final String? formName;
  final String? filterField;
  final dynamic filterValue;
  final bool excludeSelf;

  @override
  State<LinkPicker> createState() => _LinkPickerState();
}

class _LinkPickerState extends State<LinkPicker> {
  late Future<({List<FormMap> rows, String? reason})> rows;

  bool get serverOnly =>
      serverOnlyLinkSources.contains(widget.source) &&
      !widget.repository.client.isAuthenticated;

  @override
  void initState() {
    super.initState();
    rows = load('');
  }

  Future<({List<FormMap> rows, String? reason})> load(String query) async {
    if (serverOnly) return (rows: <FormMap>[], reason: null);
    return widget.repository.linkOptions({
      'company': widget.repository.company,
      'source': widget.source,
      'query': query,
      'form': widget.formName,
      'filter_field': widget.filterField,
      'filter_value': widget.filterValue,
      if (widget.excludeSelf) 'exclude_self': 1,
    });
  }
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
                  child: serverOnly
                      ? const Center(child: Text(serverOnlyListMessage))
                      : FutureBuilder<({List<FormMap> rows, String? reason})>(
                          future: rows,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                offlineFailureMessage(snapshot.error!),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final data = snapshot.data!;
                            if (data.rows.isEmpty) {
                              return Center(
                                child: Text(
                                  data.reason == 'no_employee'
                                      ? noEmployeeMessage
                                      : 'موردی برای انتخاب پیدا نشد.',
                                ),
                              );
                            }
                            final showId =
                                !serverOnlyLinkSources.contains(widget.source);
                            return ListView(
                              children: [
                                for (final r in data.rows)
                                  ListTile(
                                    title: Text('${r['label']}'),
                                    subtitle:
                                        showId ? Text('${r['name']}') : null,
                                    onTap: () => Navigator.pop(context, r),
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
