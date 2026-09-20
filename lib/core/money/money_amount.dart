import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// Amount stored as integer minor units (e.g. cents) to avoid float drift.
class MoneyAmount extends Equatable {
  const MoneyAmount({
    required this.minorUnits,
    required this.currencyCode,
  });

  final int minorUnits;
  final String currencyCode;

  static int scaleFor(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'JPY':
      case 'KRW':
        return 0;
      default:
        return 2;
    }
  }

  factory MoneyAmount.fromDecimal(Decimal value, String currencyCode) {
    return MoneyAmount.fromMajorString(value.toString(), currencyCode);
  }

  factory MoneyAmount.fromMajorString(String major, String currencyCode) {
    final scale = scaleFor(currencyCode);
    return MoneyAmount(
      minorUnits: _parseMajorToMinor(major.trim(), scale),
      currencyCode: currencyCode.toUpperCase(),
    );
  }

  static int _parseMajorToMinor(String major, int scale) {
    final negative = major.startsWith('-');
    final normalized = negative ? major.substring(1) : major;
    final parts = normalized.split('.');
    final wholePart = parts.first.isEmpty ? '0' : parts.first;
    var fractional = parts.length > 1 ? parts[1] : '';
    if (fractional.length > scale) {
      fractional = fractional.substring(0, scale);
    } else {
      fractional = fractional.padRight(scale, '0');
    }
    final factor = math.pow(10, scale).toInt();
    final minor = int.parse(wholePart) * factor + int.parse(fractional.isEmpty ? '0' : fractional);
    return negative ? -minor : minor;
  }

  Decimal toDecimal() {
    final scale = scaleFor(currencyCode);
    if (scale == 0) {
      return Decimal.fromInt(minorUnits);
    }
    final negative = minorUnits < 0;
    final absMinor = minorUnits.abs();
    final factor = math.pow(10, scale).toInt();
    final whole = absMinor ~/ factor;
    final frac = absMinor % factor;
    final fracStr = frac.toString().padLeft(scale, '0');
    final dec = Decimal.parse('$whole.$fracStr');
    return negative ? -dec : dec;
  }

  String format({bool showSymbol = false}) {
    final dec = toDecimal();
    final scale = scaleFor(currencyCode);
    final fixed = dec.toStringAsFixed(scale);
    if (!showSymbol) {
      return fixed;
    }
    return '$currencyCode $fixed';
  }

  MoneyAmount operator +(MoneyAmount other) {
    _assertSameCurrency(other);
    return MoneyAmount(
      minorUnits: minorUnits + other.minorUnits,
      currencyCode: currencyCode,
    );
  }

  MoneyAmount operator -(MoneyAmount other) {
    _assertSameCurrency(other);
    return MoneyAmount(
      minorUnits: minorUnits - other.minorUnits,
      currencyCode: currencyCode,
    );
  }

  MoneyAmount abs() => MoneyAmount(
        minorUnits: minorUnits.abs(),
        currencyCode: currencyCode,
      );

  bool get isNegative => minorUnits < 0;
  bool get isZero => minorUnits == 0;

  void _assertSameCurrency(MoneyAmount other) {
    if (currencyCode != other.currencyCode) {
      throw ArgumentError(
        'Currency mismatch: $currencyCode vs ${other.currencyCode}',
      );
    }
  }

  @override
  List<Object?> get props => [minorUnits, currencyCode];
}
