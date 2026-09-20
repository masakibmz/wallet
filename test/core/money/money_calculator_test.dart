import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/core/money/money_amount.dart';
import 'package:wallet/core/money/money_calculator.dart';

void main() {
  group('MoneyCalculator', () {
    test('sum minor units without float', () {
      final items = [
        MoneyAmount.fromMajorString('0.10', 'CNY'),
        MoneyAmount.fromMajorString('0.20', 'CNY'),
      ];
      final total = MoneyCalculator.sum(items, 'CNY');
      expect(total.minorUnits, 30);
    });

    test('multiply by decimal factor', () {
      final base = MoneyAmount.fromMajorString('100.00', 'CNY');
      final result = MoneyCalculator.multiply(base, Decimal.parse('0.15'));
      expect(result.minorUnits, 1500);
    });

    test('allocate remainder across parts', () {
      final total = MoneyAmount(minorUnits: 100, currencyCode: 'CNY');
      final parts = List.generate(3, (i) => MoneyCalculator.allocate(total, 3, i)!);
      expect(parts[0].minorUnits + parts[1].minorUnits + parts[2].minorUnits, 100);
      expect(parts[0].minorUnits, 34);
      expect(parts[1].minorUnits, 33);
      expect(parts[2].minorUnits, 33);
    });
  });
}
