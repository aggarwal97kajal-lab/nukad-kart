import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../widgets/ui.dart';
import '../state/thela_tracker.dart';
import '../widgets/thela_live.dart';
import '../widgets/thela_real_map.dart';
import '../services/live_data.dart';
import '../state/app_state.dart';

/// Moving sellers: no cart, no in-app payment. The customer sees where the thela is
/// and today's prices, and pays the seller in person. Numbers are never shown.
class ThelaScreen extends StatefulWidget {
  final Thela thela;
  const ThelaScreen({super.key, required this.thela});
  @override
  State<ThelaScreen> createState() => _ThelaScreenState();
}

/// While this page is open the thela's position is asked every 10 s.
class _ThelaScreenState extends State<ThelaScreen> {
  @override
  void initState() {
    super.initState();
    LiveData.instance.fast(true);
  }

  @override
  void dispose() {
    LiveData.instance.fast(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ThelaView(thela: widget.thela);
}

class _ThelaView extends StatelessWidget {
  final Thela thela;
  const _ThelaView({required this.thela});

  static String _price(ThelaItem it) {
    final p = it.exactPrice == 0 ? it.price : it.exactPrice;
    final v = p == p.roundToDouble() ? '₹${p.toInt()}' : '₹${p.toStringAsFixed(2)}';
    return '$v/${it.unit}';
  }

  @override
  Widget build(BuildContext context) {
    // The list refreshes every 20 s; always show the newest copy of this thela.
    return ListenableBuilder(
      listenable: ThelaTracker.instance,
      builder: (context, _) {
        final th = kThelas.firstWhere((x) => x.id == thela.id, orElse: () => thela);
        final lv = ThelaTracker.instance.of(th.id);
        return Scaffold(
          backgroundColor: kBg,
          body: ListView(padding: EdgeInsets.zero, children: [
            Container(
              decoration: BoxDecoration(color: kGD, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8, 6, 16, 16),
                  child: Row(children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back, color: Colors.white)),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(th.name, style: head(19, color: Colors.white)),
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            thelaStatusPill(lv.status, lv.seenAgo),
                            Text(thelaStatusLine(lv), style: body(12, color: kBrand)),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ThelaRealMap(thelaId: th.id, homeLat: AppScope.of(context).current.lat, homeLng: AppScope.of(context).current.lng),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: switch (lv.status) {
                ThelaStatus.standing => NoteBox('Standing here now. The pin moves when the thela moves.',
                    icon: Icons.check_circle_outline, color: kGText, bg: kPillBg),
                ThelaStatus.moving => NoteBox('On the move. The pin updates every few seconds.',
                    icon: Icons.directions_walk, color: kGText, bg: kPillBg),
                ThelaStatus.wasHere => NoteBox('Location hasn’t updated for a few minutes. The thela may have moved on.',
                    icon: Icons.history, color: kAmb, bg: kAmbBg),
                ThelaStatus.notAvailable => NoteBox(
                    'Not within 500 m right now. You’ll get a notification when it’s back near you.',
                    icon: Icons.notifications_none),
              },
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (th.door) Pill(t('Comes to your door')),
                  if (th.pickup) Pill(t('Pickup at thela'), color: kBlu, bg: kBluBg),
                ]),
                SizedBox(height: 14),
                Text(t('Today’s prices'), style: head(16)),
                SizedBox(height: 8),
                if (th.items.isEmpty)
                  Text('This thela hasn’t added today’s prices yet.', style: body(13, color: kMute))
                else
                  CardBox(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: Column(children: [
                      for (var i = 0; i < th.items.length; i++)
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                              border: i == th.items.length - 1 ? null : Border(bottom: BorderSide(color: kLine))),
                          child: Row(children: [
                            EmojiTile(th.items[i].emoji, size: 48, bg: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(th.items[i].hindi, style: body(14, weight: FontWeight.w700)),
                                if (th.items[i].english.isNotEmpty) Text(th.items[i].english, style: body(11.5, color: kMute)),
                              ]),
                            ),
                            Text(_price(th.items[i]), style: body(14, weight: FontWeight.w800)),
                          ]),
                        ),
                    ]),
                  ),
                SizedBox(height: 12),
                NoteBox(
                  'No cart for thelas. Buy at the thela and pay the seller directly — not through Nukad Kart. '
                  'Soon: call this thela to your street or chat with it, without sharing phone numbers.',
                  color: kBlu,
                  bg: kBluBg,
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
