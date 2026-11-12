/// GSTIN check: 15 characters, right pattern, and the last character is the correct check digit.
const _chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
final _pattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

String normalizeGstin(String s) => s.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

bool isValidGstin(String raw) {
  final g = normalizeGstin(raw);
  if (!_pattern.hasMatch(g)) return false;
  final state = int.parse(g.substring(0, 2));
  if (state < 1 || state > 38 && state != 97 && state != 99) return false;
  var sum = 0;
  for (var i = 0; i < 14; i++) {
    final p = _chars.indexOf(g[i]) * (i.isEven ? 1 : 2);
    sum += p ~/ 36 + p % 36;
  }
  return g[14] == _chars[(36 - sum % 36) % 36];
}
