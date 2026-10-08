import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

const _low = ['late', 'not_fixed', 'rude', 'expensive', 'unclear_price'];
const _high = ['fast', 'polite', 'clean'];

/// Rate the technician after a job is done (stars, quick tags, an optional comment).
class FeedbackForm extends StatefulWidget {
  const FeedbackForm({super.key, required this.request, required this.onSubmit});
  final PortalRequest request;
  final Future<void> Function(int rating, List<String> tags, String comment) onSubmit;
  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  int rating = 0;
  final List<String> tags = [];
  final _comment = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (r.feedbackRating != null) {
      final rated = r.feedbackRating!;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Brand.orangeTint, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (var v = 1; v <= 5; v++) Icon(v <= rated ? Icons.star_rounded : Icons.star_outline_rounded, size: 22, color: v <= rated ? Brand.orange : Brand.line),
            const SizedBox(width: 8),
            Expanded(child: Text(context.tr('feedback.rated', params: {'rating': rated}), style: TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w900))),
          ]),
          if (r.feedbackTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [for (final tag in r.feedbackTags) Chip(label: Text(context.tr('feedback.tag.$tag'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), visualDensity: VisualDensity.compact, backgroundColor: Colors.white)]),
          ],
          if (r.feedbackComment != null && r.feedbackComment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.feedbackComment!, style: const TextStyle(fontSize: 14)),
          ],
        ]),
      );
    }
    if (!r.canFeedback) return const SizedBox.shrink();
    return Section(
      title: context.tr('feedback.title'),
      hint: context.tr('feedback.hint'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          for (var v = 1; v <= 5; v++)
            IconButton(
              onPressed: () => setState(() {
                rating = v;
                tags.clear();
              }),
              icon: Icon(v <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 34, color: v <= rating ? Brand.orange : Brand.line),
            ),
        ]),
        if (rating > 0) ...[
          Wrap(spacing: 8, runSpacing: 4, children: [for (final tag in (rating <= 3 ? _low : _high)) FilterChip(label: Text(context.tr('feedback.tag.$tag')), selected: tags.contains(tag), onSelected: (on) => setState(() => on ? tags.add(tag) : tags.remove(tag)))]),
          const SizedBox(height: 10),
          TextField(controller: _comment, maxLines: 3, minLines: 2, maxLength: 500, decoration: InputDecoration(hintText: context.tr('feedback.comment'))),
          const SizedBox(height: 4),
          BusyButton(label: context.tr('feedback.send'), onPressed: () => widget.onSubmit(rating, tags, _comment.text.trim())),
        ],
      ]),
    );
  }
}
