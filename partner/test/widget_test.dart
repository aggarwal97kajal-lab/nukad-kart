import 'package:flutter_test/flutter_test.dart';
import 'package:nukad_partner/upi.dart';

void main() {
  test('UPI answer is read from the app reply', () {
    final a = UpiAnswer('txnId=1&responseCode=00&Status=SUCCESS&txnRef=NK1-0001&ApprovalRefNo=999');
    expect(a.status, 'SUCCESS');
    expect(a.ref, '999');
    expect(UpiAnswer(null).status, '');
    expect(newPaymentKey().length, 24);
  });
}
