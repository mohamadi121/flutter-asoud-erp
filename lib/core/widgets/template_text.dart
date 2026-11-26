import 'package:flutter/material.dart';

final _token = RegExp(r'\{\{([^{}\r\n]+)\}\}');

/// A token occupies one cursor position. The original spelling is retained,
/// including for an unrecognised legacy token. Never persist [text].
class TemplateTextController extends TextEditingController {
  TemplateTextController(Map<String, String> labels, {String source = ''})
      : _labels = labels {
    loadSource(source);
  }

  void loadSource(String source) {
    final reserved = source.codeUnits.toSet();
    text = source.replaceAllMapped(_token, (match) {
      final raw = match[0]!;
      return _marker(raw, reserved);
    });
  }

  final Map<String, String> _labels;
  final _tokens = <String, String>{};
  int _next = 0xe000;

  String _marker(String raw, Set<int> reserved) {
    for (final entry in _tokens.entries) {
      if (entry.value == raw) return entry.key;
    }
    while (reserved.contains(_next)) {
      _next++;
    }
    if (_next > 0xf8ff) return raw;
    final marker = String.fromCharCode(_next++);
    _tokens[marker] = raw;
    return marker;
  }

  String get source => [
        for (var i = 0; i < text.length; i++) _tokens[text[i]] ?? text[i]
      ].join();

  void insertToken(String raw) {
    if (!_labels.containsKey(raw)) return;
    final mark = _marker(raw, text.codeUnits.toSet());
    final range = selection.isValid && selection.end <= text.length
        ? selection
        : TextSelection.collapsed(offset: text.length);
    value = TextEditingValue(
      text: text.replaceRange(range.start, range.end, mark),
      selection: TextSelection.collapsed(offset: range.start + mark.length),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_tokens.isEmpty) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }
    final spans = <InlineSpan>[];
    final composing = value.composing;
    var start = 0;
    void addText(int end) {
      while (start < end) {
        final active = withComposing &&
            value.isComposingRangeValid &&
            start >= composing.start &&
            start < composing.end;
        final boundary = withComposing && value.isComposingRangeValid
            ? (active ? composing.end : composing.start)
            : end;
        final stop = boundary > start && boundary < end ? boundary : end;
        spans.add(TextSpan(
            text: text.substring(start, stop),
            style: active
                ? const TextStyle(decoration: TextDecoration.underline)
                : null));
        start = stop;
      }
    }

    for (var i = 0; i < text.length; i++) {
      final token = _tokens[text[i]];
      if (token == null) continue;
      addText(i);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F1FF),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(_labels[token] ?? 'فیلد ناشناخته',
              textDirection: TextDirection.rtl,
              style: (style ?? const TextStyle())
                  .copyWith(color: const Color(0xFF1755A6), fontSize: 12)),
        ),
      ));
      start = i + 1;
    }
    addText(text.length);
    return TextSpan(style: style, children: spans);
  }
}

String displayTemplateText(String source, Map<String, String> labels) => source
    .replaceAllMapped(_token, (match) => labels[match[0]] ?? 'فیلد ناشناخته');

({String text, Set<String> missing}) renderTemplateText(
    String source, Map<String, String> labels, Map<String, String> values) {
  final missing = <String>{};
  final text = source.replaceAllMapped(_token, (match) {
    final raw = match[0]!;
    final value = labels.containsKey(raw) ? values[raw] : null;
    if (value != null && value.trim().isNotEmpty) return value;
    missing.add(labels[raw] ?? 'فیلد ناشناخته در متن قالب');
    return '—';
  });
  return (text: text, missing: missing);
}
