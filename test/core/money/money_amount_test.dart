import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/core/money/money_amount.dart';

void main() {
  group('MoneyAmount', () {
    test('stores CNY with 2 decimal places as minor units', () {
      final amount = MoneyAmount.fromMajorString('32.50', 'CNY');
      expect(amount.minorUnits, 3250);
      expect(amount.toDecimal(), Decimal.parse('32.50'));
    });

    test('JPY uses zero decimal scale', () {
      final amount = MoneyAmount.fromMajorString('1200', 'JPY');
      expect(amount.minorUnits, 1200);
      expect(amount.format(), '1200');
    });

    test('add and subtract same currency', () {
      final a = MoneyAmount.fromMajorString('10.00', 'CNY');
      final b = MoneyAmount.fromMajorString('2.50', 'CNY');
      expect((a + b).minorUnits, 1250);
      expect((a - b).minorUnits, 750);
    });

    test('rejects mixed currency arithmetic', () {
      final cny = MoneyAmount.fromMajorString('1', 'CNY');
      final usd = MoneyAmount.fromMajorString('1', 'USD');
      expect(() => cny + usd, throwsArgumentError);
    });
  });
}
