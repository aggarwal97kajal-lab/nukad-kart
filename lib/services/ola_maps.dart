import 'dart:convert';
import 'dart:io';
import '../config/keys.dart';

/// A place found from a map pin (Ola reverse geocoding).
class OlaPlace {
  final String formatted, area, city, state, pin;
  const OlaPlace({this.formatted = '', this.area = '', this.city = '', this.state = '', this.pin = ''});
}

/// Ola Maps: map style for MapLibre + reverse geocoding.
/// Every Ola request needs `api_key`, including vector tiles, sprites and fonts,
/// so the style JSON is fetched once and rewritten with the key on every URL.
class OlaMaps {
  static const _base = 'https://api.olamaps.io';
  static final Map<String, Future<String>> _styles = {};

  static String withKey(String url) =>
      url.contains('api_key=') ? url : '$url${url.contains('?') ? '&' : '?'}api_key=$olaMapsApiKey';

  static Future<Map<String, dynamic>> _getJson(String url) async {
    final client = HttpClient()..connectionTimeout = Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw HttpException('Ola Maps ${res.statusCode}');
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    } finally {
      client.close();
    }
  }

  /// Style JSON string for MapLibre. Cached for the app session.
  static Future<String> style({bool dark = false, String lang = 'en'}) {
    final name = '${dark ? 'default-dark-standard' : 'default-light-standard'}${lang == 'hi' ? '-hi' : ''}';
    return _styles.putIfAbsent(name, () async {
      try {
        return await _build(name);
      } catch (e) {
        _styles.remove(name);
        if (lang == 'hi') return style(dark: dark); // fall back to English labels
        rethrow;
      }
    });
  }

  static Future<String> _build(String name) async {
    final s = await _getJson(withKey('$_base/tiles/vector/v1/styles/$name/style.json'));
    final sources = Map<String, dynamic>.from((s['sources'] as Map?) ?? {});
    for (final key in sources.keys.toList()) {
      final src = Map<String, dynamic>.from(sources[key] as Map);
      final url = src['url'];
      if (url is String) {
        try {
          final tj = await _getJson(withKey(url));
          src.remove('url');
          src['tiles'] = [for (final t in (tj['tiles'] as List)) withKey('$t')];
          for (final f in ['minzoom', 'maxzoom', 'bounds', 'attribution', 'scheme']) {
            if (tj[f] != null) src[f] = tj[f];
          }
        } catch (_) {
          src['url'] = withKey(url);
        }
      } else if (src['tiles'] is List) {
        src['tiles'] = [for (final t in (src['tiles'] as List)) withKey('$t')];
      }
      sources[key] = src;
    }
    s['sources'] = sources;
    if (s['sprite'] is String) s['sprite'] = withKey(s['sprite'] as String);
    if (s['glyphs'] is String) s['glyphs'] = withKey(s['glyphs'] as String);
    return jsonEncode(s);
  }

  /// Address for a point. Returns null if Ola can't be reached.
  static Future<OlaPlace?> reverse(double lat, double lng) async {
    try {
      final d = await _getJson(withKey('$_base/places/v1/reverse-geocode?latlng=$lat,$lng'));
      final results = (d['results'] as List?) ?? [];
      if (results.isEmpty) return null;
      final r = Map<String, dynamic>.from(results.first as Map);
      String pick(List<String> types) {
        for (final t in types) {
          for (final c in (r['address_components'] as List? ?? [])) {
            final m = Map<String, dynamic>.from(c as Map);
            if ((m['types'] as List?)?.contains(t) == true) return '${m['long_name'] ?? ''}';
          }
        }
        return '';
      }

      final sub = pick(['sublocality_level_1', 'sublocality', 'neighborhood']);
      final l3 = pick(['administrative_area_level_3']);
      final area = [sub, if (l3.isNotEmpty && l3 != sub) l3].where((x) => x.isNotEmpty).join(', ');
      return OlaPlace(
        formatted: '${r['formatted_address'] ?? ''}',
        area: area,
        city: pick(['locality', 'administrative_area_level_2']),
        state: pick(['administrative_area_level_1']),
        pin: pick(['postal_code']),
      );
    } catch (_) {
      return null;
    }
  }
}
