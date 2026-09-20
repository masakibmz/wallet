import 'package:drift/drift.dart';
import 'package:wallet/data/database/app_database.dart';

class CurrencySeed {
  static Future<void> seed(AppDatabase db) async {
    final now = DateTime.now().toUtc();
    final existing = await db.select(db.currencies).get();
    if (existing.isNotEmpty) {
      return;
    }

    final rows = <CurrenciesCompanion>[
      _c('CNY', '人民币', 2, '¥', now),
      _c('USD', '美元', 2, r'$', now),
      _c('JPY', '日元', 0, '¥', now),
      _c('EUR', '欧元', 2, '€', now),
      _c('GBP', '英镑', 2, '£', now),
      _c('HKD', '港币', 2, r'HK$', now),
      _c('KRW', '韩元', 0, '₩', now),
    ];

    await db.batch((batch) {
      batch.insertAll(db.currencies, rows);
    });
  }

  static CurrenciesCompanion _c(
    String code,
    String name,
    int scale,
    String symbol,
    DateTime now,
  ) {
    return CurrenciesCompanion.insert(
      code: code,
      name: name,
      minorUnitScale: scale,
      symbol: Value(symbol),
      createdAt: now,
      updatedAt: now,
    );
  }
}
