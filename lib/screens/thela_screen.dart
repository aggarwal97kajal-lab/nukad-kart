import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'rating_sheet.dart';

/// Moving sellers: no in-app orders or payments. Customers call / WhatsApp
/// and pay in person, or send a request for tomorrow.
class ThelaScreen extends StatelessWidget {
  final Thela thela;
  const ThelaScreen({super.key, required this.thela});

  void _contact(BuildContext context, String how) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        surfaceTintColor: kCard,
        title: Text(how, style: head(18)),
        content: Text(
            'In the real app this opens $how with ${thela.name} (${thela.phone}). '
            'Your number is shared with the seller only when you contact them.',
            style: body(13.5, color: kMute)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final accepted = s.requests.any((r) => r.thelaId == thela.id && r.accepted);
    final myRating = s.ratings[thela.id];
    return Scaffold(
      backgroundColor: kBg,
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          decoration: BoxDecoration(
              color: kGD, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 6, 16, 16),
              child: Column(children: [
                Row(children: [
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: Colors.white)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(thela.name, style: head(19, color: Colors.white)),
                      Text('${thela.distanceM} m away · location ${thela.lastSeenSec} s ago · ★ ${thela.rating}',
                          style: body(12, color: Color(0xFFBDE89A))),
                    ]),
                  ),
                ]),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Row(children: [
                    Expanded(
                      child: _bigBtn(t('Call'), Icons.call, Colors.white, kGD, () => _contact(context, 'Call')),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _bigBtn('WhatsApp', Icons.chat, Color(0xFF25A244), Colors.white,
                          () => _contact(context, 'WhatsApp')),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, children: [
              if (thela.door) Pill(t('Comes to your door')),
              if (thela.pickup) Pill(t('Pickup at thela'), color: kBlu, bg: kBluBg),
            ]),
            SizedBox(height: 14),
            Text(t('Today’s prices'), style: head(16)),
            SizedBox(height: 8),
            CardBox(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(children: [
                for (var i = 0; i < thela.items.length; i++)
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                        border: i == thela.items.length - 1 ? null : Border(bottom: BorderSide(color: kLine))),
                    child: Row(children: [
                      EmojiTile(thela.items[i].emoji, size: 44, bg: Color(0xFFF1F4EE)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(thela.items[i].hindi, style: body(14, weight: FontWeight.w700)),
                          Text(thela.items[i].english, style: body(11.5, color: kMute)),
                        ]),
                      ),
                      Text('${rupees(thela.items[i].price)}/${thela.items[i].unit}',
                          style: body(14, weight: FontWeight.w800)),
                    ]),
                  ),
              ]),
            ),
            SizedBox(height: 12),
            NoteBox(
              'Call or WhatsApp to order. You pay the seller directly when you get your sabzi — not through Nukad Kart.',
              color: kBlu,
              bg: kBluBg,
            ),
            SizedBox(height: 14),
            PrimaryButton(t('Request for tomorrow'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestScreen(thela: thela)))),
            if (accepted) ...[
              SizedBox(height: 10),
              PrimaryButton(myRating == null ? 'Rate ${thela.name}' : 'Your rating: $myRating★ · Edit',
                  outline: true,
                  onTap: () => showRatingSheet(context,
                      vendorId: thela.id, vendorName: thela.name, editing: myRating != null)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _bigBtn(String t, IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: fg, size: 20),
            SizedBox(width: 8),
            Text(t, style: head(15, color: fg)),
          ]),
        ),
      ),
    );
  }
}

class RequestScreen extends StatefulWidget {
  final Thela thela;
  const RequestScreen({super.key, required this.thela});
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  String slot = 'Morning';
  final Set<String> items = {};

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = widget.thela;
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(t('Request for tomorrow'), subtitle: '${t.name} · ★ ${t.rating}'),
      body: ListView(padding: EdgeInsets.all(16), children: [
        Text('Ask ${t.name.split(' ').first} to come to your area tomorrow. You’ll be notified when they reply.',
            style: body(13.5, color: kMute)),
        SizedBox(height: 16),
        Text('When?', style: head(15)),
        SizedBox(height: 8),
        Row(children: [
          Expanded(child: _slot('Morning', '7 – 10 am')),
          SizedBox(width: 8),
          Expanded(child: _slot('Evening', '5 – 8 pm')),
        ]),
        SizedBox(height: 16),
        Text('What do you need? (optional)', style: head(15)),
        SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final it in t.items)
            FilterChip(
              avatar: Text(it.emoji),
              label: Text(it.hindi),
              selected: items.contains(it.hindi),
              showCheckmark: false,
              selectedColor: kGBg,
              backgroundColor: kCard,
              side: BorderSide(color: items.contains(it.hindi) ? kG : kLine),
              labelStyle: body(13, weight: FontWeight.w700),
              onSelected: (v) => setState(() => v ? items.add(it.hindi) : items.remove(it.hindi)),
            ),
        ]),
        SizedBox(height: 16),
        CardBox(
          child: Column(children: [
            Row(children: [Text('Where', style: body(13, color: kMute)), Spacer(), Text(s.address, style: body(13, weight: FontWeight.w700))]),
            SizedBox(height: 6),
            Row(children: [Text('Date', style: body(13, color: kMute)), Spacer(), Text('Tomorrow', style: body(13, weight: FontWeight.w700))]),
          ]),
        ),
        SizedBox(height: 10),
        Text('The seller sees your area and items. Your name and number are shown only after they accept.',
            style: body(11.5, color: kMute)),
        SizedBox(height: 18),
        PrimaryButton('Send request to ${t.name.split(' ').first}', onTap: () {
          s.sendRequest(t.id, slot, items.toList());
          showToast(context, 'Request sent. You’ll get a notification when ${t.name.split(' ').first} replies.');
          Navigator.pop(context);
        }),
      ]),
    );
  }

  Widget _slot(String name, String time) {
    final sel = slot == name;
    return GestureDetector(
      onTap: () => setState(() => slot = name),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? kGBg : kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? kG : kLine, width: sel ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: body(14, weight: FontWeight.w700)),
          Text(time, style: body(11.5, color: kMute)),
        ]),
      ),
    );
  }
}
