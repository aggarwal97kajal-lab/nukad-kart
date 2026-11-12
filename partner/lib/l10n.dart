// Partner app words in English and Hindi. Keys are the English text; {0}, {1}… are filled from the list.
part 'l10n_hi.dart';

String gLang = 'en';

/// Simple text.
String t(String en) => tr(en);

/// Text with values put in: tr('Pay ₹{0} with UPI', [price]).
String tr(String en, [List<Object?> args = const []]) {
  var s = gLang == 'hi' ? (hi[en] ?? en) : en;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
