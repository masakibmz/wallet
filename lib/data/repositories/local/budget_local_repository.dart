import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/repositories/local/local_repository.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class BudgetRecord {
  BudgetRecord({
    required this.id,
    required this.ledgerId,
    required this.period,
    required this.amountMinor,
    required this.currencyCode,
    required this.startAt,
  });

  final String id;
  final String ledgerId;
  final BudgetPeriod period;
  final int amountMinor;
  final String currencyCode;
  final DateTime startAt;
}

abstract class BudgetRepository {
  Stream<List<BudgetRecord>> watchBudgets(String ledgerId);

  Future<BudgetRecord> upsertMonthly({
    required String ledgerId,
    required int amountMinor,
    required String currencyCode,
    required DateTime month,
  });
}

class BudgetLocalRepository extends LocalRepository implements BudgetRepository {
  BudgetLocalRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Stream<List<BudgetRecord>> watchBudgets(String ledgerId) {
    final query = _db.select(_db.budgets)
      ..where(
        (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
      );
    return query.watch().map(
          (rows) => rows
              .map(
                (r) => BudgetRecord(
                  id: r.id,
                  ledgerId: r.ledgerId,
                  period: r.period,
                  amountMinor: r.amountMinor,
                  currencyCode: r.currencyCode,
                  startAt: r.startAt,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<BudgetRecord> upsertMonthly({
    required String ledgerId,
    required int amountMinor,
    required String currencyCode,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month);
    final rows = await (_db.select(_db.budgets)
          ..where(
            (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
          ))
        .get();
    BudgetRow? existing;
    for (final r in rows) {
      if (r.period == BudgetPeriod.monthly &&
          r.startAt.year == start.year &&
          r.startAt.month == start.month) {
        existing = r;
        break;
      }
    }

    final now = DateTime.now().toUtc();
    if (existing != null) {
      final row = existing;
      await (_db.update(_db.budgets)..where((t) => t.id.equals(row.id)))
          .write(
        BudgetsCompanion(
          amountMinor: Value(amountMinor),
          updatedAt: Value(now),
        ),
      );
      return BudgetRecord(
        id: row.id,
        ledgerId: ledgerId,
        period: BudgetPeriod.monthly,
        amountMinor: amountMinor,
        currencyCode: currencyCode,
        startAt: start,
      );
    }

    final id = _uuid.v4();
    await _db.into(_db.budgets).insert(
          BudgetsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            period: BudgetPeriod.monthly,
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            startAt: start,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return BudgetRecord(
      id: id,
      ledgerId: ledgerId,
      period: BudgetPeriod.monthly,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      startAt: start,
    );
  }
}
