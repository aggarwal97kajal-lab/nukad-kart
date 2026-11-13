import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'categories_tab.dart';
import 'search_screen.dart';
import 'store_screen.dart';
import 'thela_screen.dart';
import 'subcategory_screen.dart';
import 'account_pages.dart';
import 'address_screen.dart';
import '../widgets/typing_hint.dart';
import '../widgets/thela_live.dart';
import '../state/thela_tracker.dart';
import '../services/live_data.dart';
import '../services/api.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  bool moving = false;
  String _at = '';

  @override
  void initState() {
    super.initState();
    LiveData.instance.startPolling();
    WidgetsBinding.instance.addObserver(this);
    // Sellers around where the phone is now (only while the app is open).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).checkHere();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.resumed && mounted) AppScope.read(context).checkHere();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (moving) LiveData.instance.fast(false);
    LiveData.instance.stopPolling();
    super.dispose();
  }

  void _setMoving(bool v) {
    if (v == moving) return;
    LiveData.instance.fast(v);
    setState(() => moving = v);
  }

  /// Shops and thelas around the chosen address (again whenever the address changes).
  void _loadFor(AppState s) {
    final b = s.browse;
    final key = '${b.lat},${b.lng}';
    if (key == _at) return;
    if (_at.isNotEmpty) ThelaTracker.instance.reset();
    _at = key;
    WidgetsBinding.instance.addPostFrameCallback((_) => LiveData.instance.loadFor(b.lat, b.lng));
    // "A thela is LIVE near you" alerts stay with the chosen (home) address, not where the phone is.
    s.sendSpot();
  }

  Future<void> _pull(AppState s) async {
    await s.checkHere();
    await LiveData.instance.loadFor(s.browse.lat, s.browse.lng, force: true);
  }

  /// Away from the chosen address: say so, and let them switch between "near me now" and the saved address.
  Widget _awayBanner(AppState s) {
    if (s.here == null) return SizedBox.shrink();
    final now = s.browsingHere;
    return Container(
      margin: EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(color: kBluBg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(now ? Icons.my_location : Icons.home_outlined, color: kBlu, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
              now ? t('You are in a new area. Showing sellers within 500 m of where you are now.') : tr('Showing sellers near {0}.', [s.current.label]),
              style: body(12.5, color: kBlu, weight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => s.setUseHere(!now),
          child: Text(now ? tr('Use {0}', [s.current.label]) : t('Near me now'), style: body(12.5, color: kBlu, weight: FontWeight.w800)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    _loadFor(s);
    return ListenableBuilder(listenable: LiveData.instance, builder: (context, _) => _build(context, s));
  }

  Widget _build(BuildContext context, AppState s) {
    final ld = LiveData.instance;
    final empty = moving ? kThelas.isEmpty : kStores.isEmpty;
    return Column(children: [
      Container(
        decoration: BoxDecoration(
          color: kCard,
          border: Border(bottom: BorderSide(color: kLine)),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: Color(0xFFFDC732), borderRadius: BorderRadius.circular(11)),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showAddressPicker(context),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.browsingHere ? t('Near you now') : deliverToLabel(s.current.label),
                        style: body(11.5, color: kMute, weight: FontWeight.w700)),
                    Row(children: [
                      Flexible(
                        child: Text(s.browsingHere ? t('Your current location') : s.address,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: head(16)),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: kInk),
                    ]),
                  ]),
                  ),
                ),
                // Language switch, next to the bell.
                GestureDetector(
                  onTap: () => showLanguageSheet(context),
                  child: Container(
                    height: 32,
                    padding: EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                        color: kSurf, borderRadius: BorderRadius.circular(16)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.translate, size: 16, color: kInk),
                      SizedBox(width: 5),
                      Text(switch (s.lang) { 'hi' => 'हिं', 'hg' => 'HG', _ => 'EN' },
                          style: body(12.5, weight: FontWeight.w800)),
                    ]),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen())),
                  icon: Stack(clipBehavior: Clip.none, children: [
                    Icon(Icons.notifications_none, color: kInk),
                    Positioned(
                      top: -5,
                      right: -6,
                      // H03: the count shrinks and fades out once notifications are read.
                      child: AnimatedScale(
                        scale: s.unreadCount > 0 ? 1.0 : 0.3,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: s.unreadCount > 0 ? 1.0 : 0.0,
                          duration: Duration(milliseconds: 300),
                          child: Container(
                            constraints: BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Color(0xFFD64545), borderRadius: BorderRadius.circular(9)),
                            child: Text('${s.unreadCount > 0 ? s.unreadCount : ''}',
                                style: body(10.5, color: Colors.white, weight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
              SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen())),
                child: Container(
                  height: 46,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: kSurf, borderRadius: BorderRadius.circular(13)),
                  child: Row(children: [
                    Icon(Icons.search, color: kInk),
                    SizedBox(width: 10),
                    Expanded(
                      child: TypingHint(
                        key: ValueKey('hint-${s.lang}'),
                        prefix: s.lang == 'hi' ? 'खोजें' : 'Search',
                        words: switch (s.lang) {
                          'hi' => ['दूध', 'आटा', 'टमाटर', 'चीनी', 'दीया और अगरबत्ती', 'मैगी'],
                          'hg' => ['doodh', 'aata', 'tamatar', 'cheeni', 'diya aur agarbatti', 'maggi'],
                          _ => ['milk', 'atta', 'tomato', 'sugar', 'diya & agarbatti', 'noodles'],
                        },
                        textColor: kMute,
                        wordColor: kInk,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => SearchScreen(startVoice: true))),
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.mic_none, color: kG),
                      ),
                    ),
                  ]),
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(color: kSurf, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  _seg(t('Shops'), Icons.storefront, !moving, () => _setMoving(false)),
                  _seg('${t('Moving sellers')} · ${kThelas.length}', Icons.shopping_cart_outlined, moving,
                      () => _setMoving(true)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      _awayBanner(s),
      Expanded(
          child: RefreshIndicator(
            onRefresh: () => _pull(s),
            child: !ld.loaded
                ? (ld.error != null ? _loadError(context, s) : const Center(child: CircularProgressIndicator()))
                : empty
                    ? (moving ? _noThelas(context, s) : _notServiceable(context, s))
                    : (moving ? _movingList(context) : _shopList(context)),
          )),
    ]);
  }

  Widget _seg(String text, IconData icon, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
              color: active ? kBrand : Colors.transparent, borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: active ? kOnBrand : kMute),
            SizedBox(width: 6),
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: body(13, color: active ? kOnBrand : kMute, weight: active ? FontWeight.w800 : FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _shopList(BuildContext context) {
    final quick = [
      kCategories[0].subs[0],
      kCategories[0].subs[2],
      kCategories[1].subs[0],
      kCategories[3].subs[3],
    ];
    return ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final sub in quick)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubcategoryScreen(sub: sub))),
            child: SizedBox(
              width: 78,
              child: Column(children: [
                SizedBox(width: 70, height: 70, child: EmojiTileFill(sub.emoji, bg: kSurf, photo: sub.photo)),
                SizedBox(height: 6),
                Text(sub.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: body(11.5, weight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
      SizedBox(height: 18),
      Text(t('Shops within 500 m'), style: head(17)),
      SizedBox(height: 10),
      // Open shops first, closed ones last.
      for (final st in [...kStores.where((x) => x.isOpen), ...kStores.where((x) => !x.isOpen)]) ...[
        _StoreCard(store: st),
        SizedBox(height: 10),
      ],
      Text(t('You pay the store at delivery, cash or UPI. Nukad Kart adds no fee to your bill.'),
          style: body(11.5, color: kMute)),
    ]);
  }

  Widget _loadError(BuildContext context, AppState s) {
    return ListView(padding: EdgeInsets.fromLTRB(16, 40, 16, 24), children: [
      Icon(Icons.wifi_off, size: 56, color: kMute),
      SizedBox(height: 10),
      Text('Couldn’t load shops near you', textAlign: TextAlign.center, style: head(18)),
      SizedBox(height: 6),
      Text('Check your internet and pull down to try again.', textAlign: TextAlign.center, style: body(14, color: kMute)),
      SizedBox(height: 16),
      Center(child: TextButton(onPressed: () => _pull(s), child: Text('Try again'))),
    ]);
  }

  /// No thela LIVE nearby: a promise and an alert button instead of an empty screen.
  Widget _noThelas(BuildContext context, AppState s) {
    final on = s.signedIn && s.thelaAlerts;
    return ListView(padding: EdgeInsets.fromLTRB(16, 18, 16, 24), children: [
      CardBox(
        padding: EdgeInsets.fromLTRB(20, 26, 20, 22),
        child: Column(children: [
          Text('🛺', style: TextStyle(fontSize: 52)),
          SizedBox(height: 8),
          Text(t('No thela is LIVE right now'), textAlign: TextAlign.center, style: head(20)),
          SizedBox(height: 6),
          Text(t('We’ll tell you as soon as one comes within 500 m. Thelas usually come in the morning and evening.'),
              textAlign: TextAlign.center, style: body(14, color: kMute)),
          SizedBox(height: 16),
          if (on)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: kPillBg, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_active_outlined, color: kG, size: 20),
                SizedBox(width: 8),
                Flexible(child: Text(t('Alert is on. We’ll tell you when a thela is near.'), style: body(13.5, color: kG, weight: FontWeight.w800))),
              ]),
            )
          else
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!s.signedIn) {
                    showToast(context, t('Log in to get thela alerts.'));
                    return;
                  }
                  s.setNotif('Thela LIVE near me', true);
                  showToast(context, t('Done. We’ll tell you when a thela is near.'));
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: kG, foregroundColor: kOnG, shape: StadiumBorder(), elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 26)),
                icon: Icon(Icons.notifications_none, size: 18),
                label: Text(t('Alert me when a thela comes'), style: head(15, color: kOnG)),
              ),
            ),
          SizedBox(height: 14),
          if (kStores.isNotEmpty)
            GestureDetector(
              onTap: () => _setMoving(false),
              child: Text(tr('Meanwhile: {0} shops near you →', [kStores.length]), style: body(13.5, color: kG, weight: FontWeight.w800)),
            ),
        ]),
      ),
    ]);
  }

  /// G05: no shops within 500 m of the chosen address.
  Widget _notServiceable(BuildContext context, AppState s) {
    return ListView(padding: EdgeInsets.fromLTRB(16, 18, 16, 24), children: [
      Text('${moving ? t('Moving sellers near you') : t('Shops near you')} (0)', style: head(18)),
      SizedBox(height: 12),
      CardBox(
        padding: EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(children: [
          Icon(Icons.storefront_outlined, size: 64, color: Color(0xFFC5CFC6)),
          SizedBox(height: 10),
          Text(moving ? 'No thela near you right now' : 'No stores available', style: head(20)),
          SizedBox(height: 6),
          Text(moving
              ? 'Thelas show here when they are LIVE within 500 m of ${s.current.short}. Pull down to check again.'
              : 'No Nukad Kart shop is open within 500 m of ${s.current.short} right now.\nTry changing your location.',
              textAlign: TextAlign.center, style: body(14, color: kMute)),
          SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => showAddressPicker(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kG, foregroundColor: kOnG, shape: StadiumBorder(), elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 26)),
              icon: Icon(Icons.location_on_outlined, size: 18),
              label: Text(t('Change location'), style: head(15, color: kOnG)),
            ),
          ),
          SizedBox(height: 12),
          GestureDetector(
            onTap: () => showToast(context, 'We’ll notify you when Nukad Kart starts in ${s.current.pin}'),
            child: Text('🔔 Tell me when Nukad Kart starts here', style: body(13, color: kG, weight: FontWeight.w700)),
          ),
        ]),
      ),
    ]);
  }

  Widget _movingList(BuildContext context) {
    return ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      Text(t('Moving sellers near you'), style: head(17)),
      SizedBox(height: 4),
      Text(t('Live thelas within 500 m. Pay the seller in person.'),
          style: body(12.5, color: kMute)),
      SizedBox(height: 12),
      for (final th in kThelas) ...[
        ListenableBuilder(
          listenable: ThelaTracker.instance,
          builder: (context, _) {
            final lv = ThelaTracker.instance.of(th.id);
            final gone = lv.status == ThelaStatus.notAvailable;
            return Opacity(
            opacity: gone ? 0.6 : 1.0,
            child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThelaScreen(thela: th))),
          child: CardBox(
            padding: EdgeInsets.all(12),
            child: Row(children: [
              th.photoUrl != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(13), child: storeImage(th.photoUrl!, width: 54, height: 54))
                  : EmojiTile(th.items.isEmpty ? '🛒' : th.items.first.emoji, size: 54, bg: kGBg),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(th.name, style: head(15)),
                  SizedBox(height: 2),
                  Text('${th.sells} · ${th.items.length} items', style: body(12, color: kMute)),
                  SizedBox(height: 5),
                  Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    thelaStatusPill(lv.status, lv.seenAgo),
                    Text(thelaStatusLine(lv), style: body(11.5, color: kMute)),
                  ]),
                ]),
              ),
              Icon(Icons.chevron_right, color: kMute),
            ]),
          ),
        ),
            );
          },
        ),
        SizedBox(height: 10),
      ],
    ]);
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  const _StoreCard({required this.store});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(store: store))),
      child: CardBox(
        padding: EdgeInsets.all(12),
        child: Row(children: [
          // The photo grows into the store page header (Hero).
          Hero(
            tag: 'store-photo-${store.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: store.isOpen
                  ? storeImage(store.photo, width: 64, height: 64)
                  : greyed(storeImage(store.photo, width: 64, height: 64)),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.name, style: head(15)),
              SizedBox(height: 2),
              Text(
                  store.isOpen
                      ? '${store.distanceM} m · Open till ${store.openTill} · ${store.ratingText}'
                      : '${store.distanceM} m · Opens ${store.opensAt} · ${store.ratingText}',
                  style: body(12, color: kMute)),
              SizedBox(height: 5),
              Wrap(spacing: 5, runSpacing: 6, children: [
                if (!store.isOpen) Pill('Closed', color: kRed, bg: kRedBg),
                if (store.door) Pill(t('Door delivery')),
                if (store.pickup) Pill(t('Pickup'), color: kBlu, bg: kBluBg),
              ]),
            ]),
          ),
          Icon(Icons.chevron_right, color: kMute),
        ]),
      ),
    );
  }
}
