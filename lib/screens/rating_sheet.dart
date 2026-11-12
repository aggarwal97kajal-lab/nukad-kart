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
    backgroundColor: kCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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

  @override
  void initState() {
    super.initState();
    stars = AppScope.read(context).ratings[widget.vendorId] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final options = ['Fresh items', 'Fast delivery', 'Correct items', 'Polite', 'Fair price'];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3))),
        SizedBox(height: 16),
        Text(widget.editing ? 'Change your rating of the shop' : 'How is ${widget.vendorName} overall?',
            textAlign: TextAlign.center, style: head(20)),
        SizedBox(height: 4),
        Text(widget.editing ? widget.vendorName : 'We ask only once. You can change it later.',
            textAlign: TextAlign.center, style: body(12.5, color: kMute)),
        SizedBox(height: 16),
        StarRow(value: stars, size: 42, onChanged: (v) => setState(() => stars = v)),
        SizedBox(height: 6),
        Text(ratingWord(stars), style: body(13.5, color: kGText, weight: FontWeight.w700)),
        SizedBox(height: 8),
        Text('Your overall rating of the shop. It counts once in the rating other customers see.',
            textAlign: TextAlign.center, style: body(11.5, color: kMute)),
        SizedBox(height: 18),
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


/// Rating for one order (stars + what went well / wrong). After the first rating of an order,
/// the shop's overall rating is asked only if the customer has never rated that shop.
Future<void> showOrderRatingSheet(BuildContext context, Order o, {required String storeName, bool editing = false}) async {
  final s = AppScope.read(context);
  s.orderPromptShown.add(o.id);
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => _OrderRatingBody(order: o, storeName: storeName, editing: editing),
  );
  if (done == true && !editing && context.mounted && s.shouldAskRating(o.storeId)) {
    await showRatingSheet(context, vendorId: o.storeId, vendorName: storeName);
  }
}

class _OrderRatingBody extends StatefulWidget {
  final Order order;
  final String storeName;
  final bool editing;
  const _OrderRatingBody({required this.order, required this.storeName, required this.editing});
  @override
  State<_OrderRatingBody> createState() => _OrderRatingBodyState();
}

class _OrderRatingBodyState extends State<_OrderRatingBody> {
  static const goodOptions = ['On time', 'Well packed', 'Fresh items', 'Polite delivery'];
  static const badOptions = ['Late', 'Missing item', 'Damaged', 'Wrong item', 'Expired'];
  int stars = 0;
  final Set<String> good = {}, bad = {};
  final comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    final r = AppScope.read(context).orderRatings[widget.order.id];
    if (r != null) {
      stars = r.stars;
      good.addAll(r.good);
      bad.addAll(r.bad);
      comment.text = r.comment;
    }
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Widget _chip(String o, Set<String> set, {bool badChip = false}) {
    final sel = set.contains(o);
    final c = badChip ? kRed : kGText;
    return FilterChip(
      label: Text(o),
      selected: sel,
      showCheckmark: false,
      labelStyle: body(12.5, color: sel ? c : kInk, weight: FontWeight.w700),
      selectedColor: badChip ? kRedBg : kGBg,
      backgroundColor: kCard,
      side: BorderSide(color: sel ? c : kLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (v) => setState(() => v ? set.add(o) : set.remove(o)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3)))),
          SizedBox(height: 14),
          Text(widget.editing ? 'Change your order rating' : 'Rate this order', style: head(20)),
          Text('#${o.id} · ${widget.storeName}', style: body(12.5, color: kMute)),
          SizedBox(height: 14),
          Center(child: StarRow(value: stars, size: 40, onChanged: (v) => setState(() => stars = v))),
          SizedBox(height: 4),
          Center(child: Text(ratingWord(stars), style: body(13.5, color: kGText, weight: FontWeight.w700))),
          SizedBox(height: 12),
          Text('What went well?', style: body(13, weight: FontWeight.w700)),
          SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final x in goodOptions) _chip(x, good)]),
          SizedBox(height: 12),
          Text('Anything wrong?', style: body(13, weight: FontWeight.w700)),
          SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final x in badOptions) _chip(x, bad, badChip: true)]),
          SizedBox(height: 12),
          TextField(
            controller: comment,
            maxLength: 200,
            style: body(14),
            decoration: InputDecoration(
              hintText: 'Add a comment (optional)',
              hintStyle: body(13.5, color: kMute),
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: kCard,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kLine)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kG, width: 2)),
            ),
          ),
          SizedBox(height: 6),
          Text('This rating is only for this order. Your rating of the shop stays as it is.',
              style: body(11.5, color: kMute)),
          SizedBox(height: 14),
          PrimaryButton(widget.editing ? 'Update order rating' : 'Submit order rating',
              onTap: stars == 0
                  ? null
                  : () {
                      AppScope.read(context).rateOrder(
                          o.id,
                          OrderRating(stars,
                              good: goodOptions.where(good.contains).toList(),
                              bad: badOptions.where(bad.contains).toList(),
                              comment: comment.text.trim()));
                      showToast(context, 'Thanks! Order rating saved.');
                      Navigator.pop(context, true);
                    }),
          if (!widget.editing)
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Not now', style: body(13.5, color: kMute, weight: FontWeight.w600)),
              ),
            ),
        ]),
      ),
    );
  }
}
