import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/asoud_colors.dart';
import '../../../../core/utils/jalali_date.dart';
import '../../data/generic_request_repository.dart';
import '../../domain/entities/request_models.dart';

/// The «نظرات» thread of a request: its free comments (oldest first) and an
/// input to add one. A comment written offline is kept on the device and shown
/// with «در انتظار ارسال».
class RequestCommentsThread extends StatefulWidget {
  const RequestCommentsThread(
      {required this.repository,
      required this.requestName,
      this.enabled = true,
      this.onChanged,
      super.key});
  final GenericRequestRepository repository;
  final String requestName;

  /// False for a request that is not on the server yet.
  final bool enabled;

  /// Called with the number of comments after a load or an add.
  final ValueChanged<int>? onChanged;

  @override
  State<RequestCommentsThread> createState() => _RequestCommentsThreadState();
}

class _RequestCommentsThreadState extends State<RequestCommentsThread> {
  final input = TextEditingController();
  List<RequestComment> comments = const [];
  bool loading = true, failed = false, sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.enabled) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final value = await widget.repository.comments(widget.requestName);
      if (!mounted) return;
      setState(() => comments = value);
      widget.onChanged?.call(value.length);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final comment =
          await widget.repository.addComment(widget.requestName, text);
      if (!mounted) return;
      input.clear();
      setState(() => comments = [...comments, comment]);
      widget.onChanged?.call(comments.length);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is ApiException
                ? error.message
                : 'ارسال نظر انجام نشد.')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          key: const ValueKey('request-comment-input'),
          controller: input,
          enabled: widget.enabled && !sending,
          minLines: 1,
          maxLines: 4,
          maxLength: 2000,
          buildCounter: (_,
                  {required currentLength, required isFocused, maxLength}) =>
              null,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            hintText: widget.enabled
                ? 'نظر خود را بنویسید ...'
                : 'پس از ارسال درخواست می‌توانید نظر بنویسید.',
            suffixIcon: IconButton(
              tooltip: 'ارسال نظر',
              onPressed: widget.enabled && !sending ? _send : null,
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: AsoudColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (failed)
          Center(
              child: TextButton(
                  onPressed: _load,
                  child: const Text('دریافت نظرات ممکن نشد؛ تلاش دوباره')))
        else
          for (final comment in comments) _CommentBubble(comment: comment),
      ]);
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment});
  final RequestComment comment;

  @override
  Widget build(BuildContext context) {
    final name = comment.displayName;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: comment.isMine
              ? AsoudColors.primary.withValues(alpha: .06)
              : const Color(0xFFF6F8FC),
          borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 15,
            backgroundColor: AsoudColors.primary.withValues(alpha: .12),
            child: Text(name.isEmpty ? '؟' : name.characters.first,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AsoudColors.primary))),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(name.isEmpty ? '—' : name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800))),
              if (comment.pending)
                const Text('در انتظار ارسال',
                    style: TextStyle(
                        fontSize: 10,
                        color: AsoudColors.warning,
                        fontWeight: FontWeight.w800))
              else if (comment.creation.isNotEmpty)
                Text(formatJalaliDateTimeIso(comment.creation),
                    style: const TextStyle(
                        fontSize: 10, color: AsoudColors.muted)),
            ]),
            const SizedBox(height: 3),
            Text(comment.content,
                style: const TextStyle(fontSize: 12, height: 1.7)),
          ]),
        ),
      ]),
    );
  }
}
