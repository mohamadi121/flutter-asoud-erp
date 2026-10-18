import 'dart:async';

import 'package:flutter/material.dart';

import '../../form_repository.dart';

class SmartLinkPickerDropdown extends StatefulWidget {
  const SmartLinkPickerDropdown({
    required this.source,
    required this.selectedId,
    required this.selectedLabel,
    required this.onSelected,
    this.repository,
    this.company,
    super.key,
  });

  final String source;
  final String? selectedId;
  final String? selectedLabel;
  final ValueChanged<FormMap?> onSelected;
  final FormRepository? repository;
  final String? company;

  @override
  State<SmartLinkPickerDropdown> createState() => _SmartLinkPickerDropdownState();
}

class _SmartLinkPickerDropdownState extends State<SmartLinkPickerDropdown> {
  bool isOpen = false;
  bool isLoading = false;
  String? errorMessage;
  List<FormMap> results = [];
  Timer? debounceTimer;
  late TextEditingController searchCtrl;

  @override
  void initState() {
    super.initState();
    searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchResults(query);
    });
  }

  Future<void> _fetchResults(String query) async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (widget.repository != null) {
        final list = formMaps(
          await widget.repository!.call('get_link_options', {
            'company': widget.company ?? widget.repository!.company,
            'source': widget.source,
            'query': query,
          }),
        );
        if (mounted) {
          setState(() {
            results = list;
            isLoading = false;
          });
        }
      } else {
        // Fallback for previews without active repository
        final fakeData = _mockResults(widget.source, query);
        if (mounted) {
          setState(() {
            results = fakeData;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'خطا در برقراری ارتباط با سرور';
        });
      }
    }
  }

  List<FormMap> _mockResults(String source, String query) {
    final list = <FormMap>[
      {'name': 'EMP-001', 'label': 'علی محمدی (مدیر مالی - ۱۰۱)'},
      {'name': 'EMP-002', 'label': 'سارا احمدی (کارشناس فروش - ۱۰۲)'},
      {'name': 'POS-001', 'label': 'مدیر مالی (مالی)'},
      {'name': 'POS-002', 'label': 'کارشناس منابع انسانی (اداری)'},
      {'name': 'ITEM-001', 'label': 'کاغذ A4 (کد ۱۰۰۱)'},
      {'name': 'ITEM-002', 'label': 'لپ‌تاپ لنوو (کد ۲۰۲)'},
      {'name': 'WH-001', 'label': 'انبار مرکزی (کد ۰۱)'},
      {'name': 'WH-002', 'label': 'انبار قطعات (کد ۰۲)'},
      {'name': 'ACC-001', 'label': 'بانک ملت (کد ۱۱۰۱)'},
      {'name': 'ACC-002', 'label': 'صندوق شرکت (کد ۱۰۰۱)'},
    ];
    if (query.trim().isEmpty) return list.take(5).toList();
    return list.where((item) => '${item['label']}'.contains(query) || '${item['name']}'.contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.selectedId != null && widget.selectedId!.isNotEmpty;
    final displayLabel = widget.selectedLabel ?? widget.selectedId ?? 'انتخاب از اطلاعات مجاز';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              setState(() {
                isOpen = !isOpen;
                if (isOpen && results.isEmpty) {
                  _fetchResults(searchCtrl.text);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isOpen ? const Color(0xFF1876D2) : const Color(0xFFE2E8F2),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasSelection ? displayLabel : 'انتخاب از اطلاعات مجاز...',
                      style: TextStyle(
                        fontSize: 14,
                        color: hasSelection ? const Color(0xFF122044) : const Color(0xFF5B6478),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasSelection)
                    InkWell(
                      onTap: () => widget.onSelected(null),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.close, size: 18, color: Color(0xFF5B6478)),
                      ),
                    ),
                  Icon(
                    isOpen ? Icons.keyboard_arrow_up : Icons.search,
                    color: const Color(0xFF1876D2),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isOpen) ...[
          const SizedBox(height: 6),
          Material(
            color: Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'جست‌وجو...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F2)),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 8),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E)),
                      ),
                    )
                  else if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'موردی یافت نشد',
                        style: TextStyle(fontSize: 12, color: Color(0xFF5B6478)),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = results[index];
                          final isSel = item['name'] == widget.selectedId;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            title: Text(
                              '${item['label'] ?? item['name']}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? const Color(0xFF1876D2) : const Color(0xFF122044),
                              ),
                            ),
                            trailing: isSel ? const Icon(Icons.check, size: 16, color: Color(0xFF1876D2)) : null,
                            onTap: () {
                              widget.onSelected(item);
                              setState(() => isOpen = false);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
