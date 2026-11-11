import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';

/// One rating per customer per store/thela. Asked once; can be edited later.
Future<void> showRatingSheet(BuildContext context,
    {required String vendorId, required String vendorName, bool editing = false}) async {
  final s = AppScope.read(context);
  s.markPromptShown(vendorId);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _RatingBody(vendorId: vendorId, vendorName: vendorName, editing: editing),
  );
}

class _RatingBody extends StatefulWidget {
  final String vendorId;
  final String vendorName;
  final bool editing;
  const _RatingBody({required this.vendorId, required this.vendorName, required this.editing});
  @override
  State<_RatingBody> createState() => _RatingBodyState();
}

class _RatingBodyState extends State<_RatingBody> {
  late int stars;
  final Set<String> tags = {};

  @override
  void initState() {
    super.initState();
    stars = AppScope.read(context).ratings[widget.vendorId] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    const options = ['Fresh items', 'Fast delivery', 'Correct items', 'Polite', 'Fair price'];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 16),
        Text(widget.editing ? 'Change your rating' : 'Rate ${widget.vendorName}',
            textAlign: TextAlign.center, style: head(20)),
        const SizedBox(height: 4),
        Text(widget.editing ? widget.vendorName : 'We ask only once. You can change it later from the store page.',
            textAlign: TextAlign.center, style: body(12.5, color: kMute)),
        const SizedBox(height: 16),
        StarRow(value: stars, size: 42, onChanged: (v) => setState(() => stars = v)),
        const SizedBox(height: 6),
        Text(ratingWord(stars), style: body(13.5, color: kGD, weight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final o in options)
            FilterChip(
              label: Text(o),
              selected: tags.contains(o),
              showCheckmark: false,
              labelStyle: body(12.5, color: tags.contains(o) ? kGD : kInk, weight: FontWeight.w700),
              selectedColor: kGBg,
              backgroundColor: Colors.white,
              side: BorderSide(color: tags.contains(o) ? kG : kLine),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onSelected: (v) => setState(() => v ? tags.add(o) : tags.remove(o)),
            ),
        ]),
        const SizedBox(height: 18),
        PrimaryButton(widget.editing ? 'Update rating' : 'Submit rating',
            onTap: stars == 0
                ? null
                : () {
                    AppScope.read(context).rate(widget.vendorId, stars);
                    showToast(context, 'Thanks! Your rating is saved.');
                    Navigator.pop(context);
                  }),
        if (!widget.editing)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Not now', style: body(13.5, color: kMute, weight: FontWeight.w600)),
          ),
      ]),
    );
  }
}
