import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../widgets/ui.dart';
import '../widgets/voice_search.dart';
import 'product_screen.dart';
import 'store_screen.dart';

/// Hindi / Hinglish words people say, mapped to the English product names.
const Map<String, String> kSearchWords = {
  'doodh': 'milk', 'dudh': 'milk', 'दूध': 'milk',
  'cheeni': 'sugar', 'chini': 'sugar', 'चीनी': 'sugar',
  'aata': 'atta', 'आटा': 'atta',
  'chawal': 'rice', 'चावल': 'rice',
  'dal': 'dal', 'daal': 'dal', 'दाल': 'dal',
  'tel': 'oil', 'तेल': 'oil',
  'tamatar': 'tomato', 'टमाटर': 'tomato',
  'pyaz': 'onion', 'pyaaz': 'onion', 'प्याज': 'onion', 'प्याज़': 'onion',
  'aloo': 'potato', 'alu': 'potato', 'आलू': 'potato',
  'anda': 'eggs', 'ande': 'eggs', 'अंडा': 'eggs', 'अंडे': 'eggs',
  'makhan': 'butter', 'ghee': 'ghee', 'घी': 'ghee',
  'sabun': 'soap', 'साबुन': 'soap',
  'chai': 'tea', 'चाय': 'tea', 'patti': 'tea',
  'namkeen': 'chips', 'biscuit': 'biscuits', 'बिस्कुट': 'biscuits',
  'diya': 'diya', 'दीया': 'diya', 'agarbatti': 'agarbatti', 'अगरबत्ती': 'agarbatti',
  'kapoor': 'camphor', 'कपूर': 'camphor', 'maggi': 'noodles', 'मैगी': 'noodles',
};

List<String> searchTerms(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  final out = <String>{q};
  for (final w in q.split(RegExp(r'\s+'))) {
    out.add(w);
    final m = kSearchWords[w];
    if (m != null) out.add(m);
  }
  return out.where((x) => x.length >= 2).toList();
}

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  final bool startVoice;
  const SearchScreen({super.key, this.initialQuery = '', this.startVoice = false});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String q = '';
  final _ctl = TextEditingController();

  @override
  void initState() {
    super.initState();
    q = widget.initialQuery;
    _ctl.text = q;
    if (widget.startVoice) WidgetsBinding.instance.addPostFrameCallback((_) => _voice());
  }

  Future<void> _voice() async {
    final said = await showVoiceSearch(context);
    if (said == null || said.isEmpty || !mounted) return;
    setState(() {
      q = said;
      _ctl.text = said;
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = q.trim().toLowerCase();
    final terms = searchTerms(query);
    bool hit(String text) => terms.any((w) => text.toLowerCase().contains(w));
    final products = query.isEmpty ? <Product>[] : kProducts.where((p) => hit(p.name) || hit(p.sub)).toList();
    final stores = query.isEmpty ? <Store>[] : kStores.where((s) => s.name.toLowerCase().contains(query)).toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        surfaceTintColor: kCard,
        foregroundColor: kInk,
        titleSpacing: 0,
        actions: [IconButton(onPressed: _voice, icon: Icon(Icons.mic_none, color: kG))],
        title: TextField(
          autofocus: !widget.startVoice && widget.initialQuery.isEmpty,
          controller: _ctl,
          onChanged: (v) => setState(() => q = v),
          style: body(15.5, weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Search atta, doodh, tamatar…',
            hintStyle: body(15, color: kMute),
            border: InputBorder.none,
          ),
        ),
      ),
      body: query.isEmpty
          ? ListView(padding: EdgeInsets.all(16), children: [
              Text('Popular near you', style: head(15)),
              SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in ['Atta', 'Milk', 'Tomato', 'Noodles', 'Diya', 'Soap'])
                  ActionChip(
                    label: Text(t, style: body(13, weight: FontWeight.w600)),
                    backgroundColor: kCard,
                    side: BorderSide(color: kLine),
                    onPressed: () => setState(() {
                      q = t;
                      _ctl.text = t;
                    }),
                  ),
              ]),
            ])
          : ListView(padding: EdgeInsets.all(12), children: [
              if (products.isEmpty && stores.isEmpty)
                Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('No match for “$q” near you', textAlign: TextAlign.center, style: body(14, color: kMute)),
                ),
              for (final st in stores)
                ListTile(
                  tileColor: kCard,
                  leading: Icon(Icons.storefront, color: kG),
                  title: Text(st.name, style: body(14.5, weight: FontWeight.w700)),
                  subtitle: Text('${st.distanceM} m · store', style: body(12, color: kMute)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(store: st))),
                ),
              for (final p in products)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(product: p))),
                    child: CardBox(
                      padding: EdgeInsets.all(10),
                      child: Row(children: [
                        EmojiTile(p.emoji, size: 50),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.name, style: body(14, weight: FontWeight.w700)),
                            Text('${p.size} · ${p.sub}', style: body(12, color: kMute)),
                          ]),
                        ),
                        Icon(Icons.chevron_right, color: kMute),
                      ]),
                    ),
                  ),
                ),
            ]),
    );
  }
}
