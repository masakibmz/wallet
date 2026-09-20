import 'package:decimal/decimal.dart';

import 'money_amount.dart';

class MoneyCalculator {
  const MoneyCalculator._();

  static MoneyAmount sum(Iterable<MoneyAmount> amounts, String currencyCode) {
    var total = 0;
    for (final amount in amounts) {
      if (amount.currencyCode != currencyCode) {
        throw ArgumentError('All amounts must use $currencyCode');
      }
      total += amount.minorUnits;
    }
    return MoneyAmount(minorUnits: total, currencyCode: currencyCode);
  }

  static MoneyAmount multiply(MoneyAmount amount, Decimal factor) {
    final dec = amount.toDecimal() * factor;
    return MoneyAmount.fromDecimal(dec, amount.currencyCode);
  }

  static MoneyAmount? allocate(
    MoneyAmount total,
    int parts,
    int partIndex,
  ) {
    if (parts <= 0 || partIndex < 0 || partIndex >= parts) {
      return null;
    }
    final base = total.minorUnits ~/ parts;
    final remainder = total.minorUnits % parts;
    final extra = partIndex < remainder ? 1 : 0;
    return MoneyAmount(
      minorUnits: base + extra,
      currencyCode: total.currencyCode,
    );
  }
}
