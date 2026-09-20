import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/mappers/ledger_mapper.dart';
import 'package:wallet/data/repositories/local/local_repository.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/entities/ledger.dart';
import 'package:wallet/domain/enums/app_enums.dart';

abstract class LedgerRepository {
  Stream<List<Ledger>> watchActiveLedgers();

  Future<List<Ledger>> getActiveLedgers();

  Future<Ledger?> getDefaultLedger();

  Future<Ledger> createLedger({
    required String name,
    LedgerKind kind = LedgerKind.life,
    bool makeDefault = false,
    String baseCurrencyCode = 'CNY',
  });

  Future<void> ensureDefaultLedger();

  Future<Ledger?> getById(String id);

  Future<Ledger> updateLedger({
    required String id,
    String? name,
    LedgerKind? kind,
    String? iconName,
    int? colorValue,
    int? sortOrder,
    String? baseCurrencyCode,
  });

  Future<void> setDefaultLedger(String id);

  Future<void> softDeleteLedger(String id);
}

class LedgerLocalRepository extends LocalRepository implements LedgerRepository {
  LedgerLocalRepository(this._db, {this.onLedgerCreated});

  final AppDatabase _db;
  final Future<void> Function(String ledgerId, String currencyCode)?
      onLedgerCreated;
  static const _uuid = Uuid();

  @override
  Stream<List<Ledger>> watchActiveLedgers() {
    final query = _db.select(_db.ledgers)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.watch().map(LedgerMapper.fromRows);
  }

  @override
  Future<List<Ledger>> getActiveLedgers() async {
    final query = _db.select(_db.ledgers)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return LedgerMapper.fromRows(await query.get());
  }

  @override
  Future<Ledger?> getDefaultLedger() async {
    final query = _db.select(_db.ledgers)
      ..where((t) => t.deletedAt.isNull() & t.isDefault.equals(true))
      ..limit(1);
    final rows = await query.get();
    if (rows.isEmpty) {
      return null;
    }
    return LedgerMapper.fromRow(rows.first);
  }

  @override
  Future<void> ensureDefaultLedger() async {
    final existing = await getDefaultLedger();
    if (existing != null) {
      return;
    }
    await createLedger(
      name: '默认账本',
      kind: LedgerKind.life,
      makeDefault: true,
    );
  }

  @override
  Future<Ledger> createLedger({
    required String name,
    LedgerKind kind = LedgerKind.life,
    bool makeDefault = false,
    String baseCurrencyCode = 'CNY',
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();

    await _db.transaction(() async {
      if (makeDefault) {
        await (_db.update(_db.ledgers)
              ..where((t) => t.isDefault.equals(true)))
            .write(
          LedgersCompanion(
            isDefault: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }

      await _db.into(_db.ledgers).insert(
            LedgersCompanion.insert(
              id: id,
              name: name,
              kind: kind,
              isDefault: Value(makeDefault),
              baseCurrencyCode: Value(baseCurrencyCode),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    final row = await (_db.select(_db.ledgers)..where((t) => t.id.equals(id)))
        .getSingle();
    await onLedgerCreated?.call(id, baseCurrencyCode);
    return LedgerMapper.fromRow(row);
  }

  @override
  Future<Ledger?> getById(String id) async {
    final row = await (_db.select(_db.ledgers)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : LedgerMapper.fromRow(row);
  }

  @override
  Future<Ledger> updateLedger({
    required String id,
    String? name,
    LedgerKind? kind,
    String? iconName,
    int? colorValue,
    int? sortOrder,
    String? baseCurrencyCode,
  }) async {
    if (await getById(id) == null) {
      throw RepositoryException('账本不存在');
    }
    final now = DateTime.now().toUtc();
    await (_db.update(_db.ledgers)..where((t) => t.id.equals(id))).write(
          LedgersCompanion(
            name: name == null ? const Value.absent() : Value(name),
            kind: kind == null ? const Value.absent() : Value(kind),
            iconName: iconName == null ? const Value.absent() : Value(iconName),
            colorValue:
                colorValue == null ? const Value.absent() : Value(colorValue),
            sortOrder:
                sortOrder == null ? const Value.absent() : Value(sortOrder),
            baseCurrencyCode: baseCurrencyCode == null
                ? const Value.absent()
                : Value(baseCurrencyCode),
            updatedAt: Value(now),
          ),
        );
    return (await getById(id))!;
  }

  @override
  Future<void> setDefaultLedger(String id) async {
    if (await getById(id) == null) {
      throw RepositoryException('账本不存在');
    }
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.ledgers)..where((t) => t.isDefault.equals(true)))
          .write(
        LedgersCompanion(
          isDefault: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.ledgers)..where((t) => t.id.equals(id))).write(
            LedgersCompanion(
              isDefault: const Value(true),
              updatedAt: Value(now),
            ),
          );
    });
  }

  @override
  Future<void> softDeleteLedger(String id) async {
    final target = await getById(id);
    if (target == null) {
      throw RepositoryException('账本不存在');
    }
    final active = await getActiveLedgers();
    if (active.length <= 1) {
      throw RepositoryException('至少保留一个账本');
    }

    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.ledgers)..where((t) => t.id.equals(id))).write(
            LedgersCompanion(
              deletedAt: Value(now),
              isDefault: const Value(false),
              updatedAt: Value(now),
            ),
          );

      if (target.isDefault) {
        final next = active.firstWhere((l) => l.id != id);
        await (_db.update(_db.ledgers)
              ..where((t) => t.isDefault.equals(true)))
            .write(
          LedgersCompanion(
            isDefault: const Value(false),
            updatedAt: Value(now),
          ),
        );
        await (_db.update(_db.ledgers)..where((t) => t.id.equals(next.id)))
            .write(
          LedgersCompanion(
            isDefault: const Value(true),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }
}
