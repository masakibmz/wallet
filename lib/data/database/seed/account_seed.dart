import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class AccountSeed {
  AccountSeed(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<void> ensureForLedger(String ledgerId, {String currencyCode = 'CNY'}) async {
    final existing = await (_db.select(_db.accounts)
          ..where(
            (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
          )
          ..limit(1))
        .get();
    if (existing.isNotEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            id: _uuid.v4(),
            ledgerId: ledgerId,
            name: '现金',
            category: AccountCategory.cash,
            currencyCode: currencyCode,
            initialBalanceMinor: 0,
            sortOrder: const Value(0),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
