import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../catalog.dart';
import '../session.dart';
import '../ui.dart';

/// A shop without an FSSAI number can't list food (thelas can sell vegetables and fruits).
bool canSellCat(Cat c) {
  final s = session.store ?? {};
  if (!c.food) return true;
  if (s['kind'] == 'thela') return true;
  return '${s['fssai'] ?? ''}'.isNotEmpty;
}

/// Product photo: our copy, or the category picture.
Widget productImage(Map<String, dynamic> p, {double size = 48}) {
  final photo = p['photo'];
  final cat = catByName('${p['category']}');
  final fallback = cat == null
      ? Container(width: size, height: size, color: kSurf, child: Icon(Icons.inventory_2_outlined, color: kMute))
      : Image.asset(cat.image, width: size, height: size, fit: BoxFit.cover);
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: photo == null
        ? fallback
        : Image.network('$apiBase$photo', width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
  );
}

String money(num v) => v == v.roundToDouble() ? '₹${v.toInt()}' : '₹${v.toStringAsFixed(2)}';

/// Add or edit one product. [product] = editing; [prefill] = from a barcode lookup; [loose] = a loose item template.
class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  final Map<String, dynamic>? prefill;
  final Loose? loose;
  final bool looseBlank;
  const ProductFormScreen({super.key, this.product, this.prefill, this.loose, this.looseBlank = false});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late bool loose;
  final name = TextEditingController();
  final size = TextEditingController();
  final mrp = TextEditingController();
  final price = TextEditingController();
  final hsn = TextEditingController();
  String barcode = '', brand = '', category = '', unit = 'kg', offImage = '', credit = '';
  double gst = 5;
  Set<int> sizes = {};
  bool inStock = true, countStock = false, _saving = false;
  int stock = 0;
  File? ownPhoto;

  Map<String, dynamic>? get p => widget.product;

  @override
  void initState() {
    super.initState();
    final e = p;
    final f = widget.prefill;
    final l = widget.loose;
    loose = e != null ? e['kind'] == 'loose' : (l != null || widget.looseBlank);
    if (e != null) {
      name.text = '${e['name']}';
      size.text = '${e['size'] ?? ''}';
      mrp.text = e['mrp'] == null ? '' : _num(e['mrp']);
      price.text = _num(e['price']);
      hsn.text = '${e['hsn'] ?? ''}';
      barcode = '${e['barcode'] ?? ''}';
      brand = '${e['brand'] ?? ''}';
      category = '${e['category']}';
      gst = (e['gst'] as num).toDouble();
      unit = '${e['unit'] ?? 'kg'}';
      sizes = {for (final x in (e['options'] as List? ?? [])) (x as num).toInt()};
      inStock = e['inStock'] == true;
      countStock = e['stock'] != null;
      stock = (e['stock'] as num?)?.toInt() ?? 0;
      credit = '${e['photoCredit'] ?? ''}';
    } else if (l != null) {
      name.text = l.name;
      category = l.cat;
      unit = l.unit;
      sizes = l.sizes.toSet();
      _catDefaults();
    } else if (f != null) {
      barcode = '${f['barcode'] ?? ''}';
      name.text = '${f['name'] ?? ''}';
      brand = '${f['brand'] ?? ''}';
      size.text = '${f['size'] ?? ''}';
      category = '${f['category'] ?? ''}';
      offImage = '${f['image'] ?? ''}';
      if (offImage.isNotEmpty) credit = 'Photo: Open Food Facts (CC BY-SA)';
      if (category.isNotEmpty) _catDefaults();
    }
    if (loose && sizes.isEmpty) sizes = {...kUnitSizes[unit]!.take(3)};
  }

  String _num(dynamic v) {
    final n = (v as num).toDouble();
    return n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(2);
  }

  void _catDefaults() {
    final c = catByName(category);
    if (c == null) return;
    gst = c.gst;
    hsn.text = c.hsn;
  }

  @override
  void dispose() {
    for (final c in [name, size, mrp, price, hsn]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, sc) => ListView(controller: sc, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(t('Category'), style: tx(18, weight: FontWeight.w800))),
          for (final c in kCats)
            ListTile(
              enabled: canSellCat(c),
              leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset(c.image, width: 40, height: 40, fit: BoxFit.cover)),
              title: Text(t(c.name), style: tx(15, weight: FontWeight.w700, color: canSellCat(c) ? kInk : kMute)),
              subtitle: canSellCat(c) ? null : Text(t('Add an FSSAI number to sell food'), style: tx(11.5, color: kAmb)),
              trailing: category == c.name ? Icon(Icons.check, color: kAct) : null,
              onTap: () => Navigator.pop(ctx, c.name),
            ),
        ]),
      ),
    );
    if (picked != null) {
      setState(() {
        category = picked;
        _catDefaults();
      });
    }
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 75);
    if (x != null) setState(() => ownPhoto = File(x.path));
  }

  Future<void> _save() async {
    final pr = double.tryParse(price.text.trim());
    final m = double.tryParse(mrp.text.trim());
    String? err;
    if (name.text.trim().length < 2) err = t('Enter the product name.');
    if (err == null && category.isEmpty) err = t('Pick a category.');
    if (err == null && !loose && size.text.trim().isEmpty) err = t('Enter the pack size, like 250 g.');
    if (err == null && (pr == null || pr <= 0)) err = t('Enter your price.');
    if (err == null && !loose && (m == null || m <= 0)) err = t('Enter the MRP printed on the pack.');
    if (err == null && m != null && pr! > m) err = t('Your price can’t be more than the MRP.');
    if (err == null && loose && sizes.isEmpty) err = t('Pick at least one size customers can buy.');
    if (err != null) {
      toast(context, err);
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await api.call('POST', '/v1/partner/products', {
        if (p != null) 'id': p!['id'],
        'kind': loose ? 'loose' : 'packed',
        'name': name.text.trim(),
        'brand': brand,
        'size': loose ? '' : size.text.trim(),
        'unit': loose ? unit : null,
        'options': loose ? (sizes.toList()..sort()) : null,
        'barcode': loose ? '' : barcode,
        'category': category,
        'mrp': m,
        'price': pr,
        'gst': gst,
        'hsn': hsn.text.trim(),
        'stock': countStock ? stock : null,
        'inStock': inStock,
        if (offImage.isNotEmpty && ownPhoto == null && p == null) 'offImage': offImage,
      });
      var saved = Map<String, dynamic>.from(r['product'] as Map);
      if (ownPhoto != null) {
        final u = await api.putBytes('/v1/partner/products/${saved['id']}/photo', await ownPhoto!.readAsBytes());
        saved = Map<String, dynamic>.from(u['product'] as Map);
      }
      if (!mounted) return;
      toast(context, tr('{0} saved', [saved['name']]));
      Navigator.pop(context, saved);
      return;
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Delete this product?')),
        content: Text('${p!['name']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Back'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Delete'), style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.call('DELETE', '/v1/partner/products/${p!['id']}');
      if (mounted) Navigator.pop(context, <String, dynamic>{'deleted': p!['id']});
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Widget _label(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(s, style: tx(12.5, color: kMute, weight: FontWeight.w700)));

  Widget _photo() {
    final c = catByName(category);
    Widget img;
    if (ownPhoto != null) {
      img = Image.file(ownPhoto!, fit: BoxFit.cover);
    } else if (p?['photo'] != null) {
      img = Image.network('$apiBase${p!['photo']}', fit: BoxFit.cover);
    } else if (offImage.isNotEmpty) {
      img = Image.network(offImage, fit: BoxFit.cover);
    } else if (c != null) {
      img = Image.asset(c.image, fit: BoxFit.cover);
    } else {
      img = Container(color: kSurf, child: Icon(Icons.inventory_2_outlined, color: kMute, size: 36));
    }
    final showCredit = ownPhoto == null && credit.isNotEmpty;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 96, height: 96, child: img)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showCredit) Text(credit, style: tx(11, color: kMute)),
          if (ownPhoto == null && p?['photo'] == null && offImage.isEmpty)
            Text(t('Category picture is used until you add a photo.'), style: tx(11.5, color: kMute)),
          TextButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.photo_camera_outlined), label: Text(t('Take my own photo'))),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pr = double.tryParse(price.text.trim());
    final m = double.tryParse(mrp.text.trim());
    final c = catByName(category);
    return Scaffold(
      appBar: bar(p != null ? t('Edit product') : (loose ? t('Loose item') : t('Add product'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        _photo(),
        _label(t('Name')),
        TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: field(loose ? 'Toor Dal' : 'Parle-G Gold Biscuits')),
        if (barcode.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('Barcode {0}', [barcode]), style: tx(11.5, color: kMute))),
        _label(t('Category')),
        InkWell(
          onTap: _pickCategory,
          child: InputDecorator(
            decoration: field(t('Pick a category')),
            child: Row(children: [
              Expanded(child: Text(category.isEmpty ? t('Pick a category') : t(category), style: tx(14.5, color: category.isEmpty ? kMute : kInk))),
              Icon(Icons.expand_more, color: kMute),
            ]),
          ),
        ),
        if (c != null && !canSellCat(c))
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(t('Add an FSSAI number to sell food'), style: tx(12, color: kAmb, weight: FontWeight.w700))),
        if (!loose) ...[
          _label(t('Pack size')),
          TextField(controller: size, decoration: field('250 g · 1 L · 6 pcs')),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(t('MRP ₹')),
                TextField(
                    controller: mrp,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: field('30')),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label(t('Your price ₹')),
                TextField(
                    controller: price,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: field('28')),
              ]),
            ),
          ]),
          if (pr != null && m != null && pr > m)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(t('Your price can’t be more than the MRP.'), style: tx(12, color: kRed, weight: FontWeight.w700)))
          else if (pr != null && m != null && pr < m)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('Customers see “{0} off”', [money(m - pr)]), style: tx(12, color: kAct, weight: FontWeight.w700))),
        ] else ...[
          _label(t('Sold by')),
          Row(children: [
            for (final u in const ['kg', 'litre', 'piece'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t(u)),
                  selected: unit == u,
                  onSelected: (_) => setState(() {
                    unit = u;
                    sizes = {...kUnitSizes[u]!.take(3)};
                  }),
                ),
              ),
          ]),
          _label(tr('Price per {0} ₹', [t(unit)])),
          TextField(
              controller: price,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: field('160')),
          _label(t('Customers can buy')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in kUnitSizes[unit]!)
              FilterChip(
                label: Text(pr == null ? sizeLabel(unit, n) : '${sizeLabel(unit, n)} · ${money(sizePrice(unit, pr, n))}'),
                selected: sizes.contains(n),
                onSelected: (v) => setState(() => v ? sizes.add(n) : sizes.remove(n)),
              ),
          ]),
          _label(t('MRP per unit ₹ (optional)')),
          TextField(
              controller: mrp,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: field(t('Leave empty for loose items'))),
        ],
        _label(t('GST (from the category, you can change)')),
        Wrap(spacing: 8, children: [
          for (final g in kGstRates)
            ChoiceChip(label: Text('${g.toInt()}%'), selected: gst == g, onSelected: (_) => setState(() => gst = g)),
        ]),
        const SizedBox(height: 8),
        TextField(controller: hsn, keyboardType: TextInputType.number, decoration: field('1905', label: 'HSN')),
        const SizedBox(height: 10),
        Box(
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('In stock'), style: tx(15, weight: FontWeight.w800)),
                  Text(t('Off = customers can’t order it'), style: tx(11.5, color: kMute)),
                ]),
              ),
              Switch(
                value: countStock ? stock > 0 : inStock,
                onChanged: countStock ? null : (v) => setState(() => inStock = v),
              ),
            ]),
            const Divider(),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('Count stock (optional)'), style: tx(14, weight: FontWeight.w700)),
                  Text(t('Goes down with every order. At 0 it turns off by itself.'), style: tx(11.5, color: kMute)),
                ]),
              ),
              Switch(value: countStock, onChanged: (v) => setState(() => countStock = v)),
            ]),
            if (countStock)
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton.outlined(onPressed: stock > 0 ? () => setState(() => stock--) : null, icon: const Icon(Icons.remove)),
                SizedBox(width: 56, child: Text('$stock', textAlign: TextAlign.center, style: tx(18, weight: FontWeight.w800))),
                IconButton.outlined(onPressed: () => setState(() => stock++), icon: const Icon(Icons.add)),
              ]),
          ]),
        ),
        const SizedBox(height: 18),
        Btn(_saving ? t('Saving…') : t('Save'), onTap: _saving ? null : _save),
        if (p != null) ...[
          const SizedBox(height: 8),
          Btn(t('Delete product'), outline: true, color: kRed, onTap: _saving ? null : _delete),
        ],
      ]),
    );
  }
}
