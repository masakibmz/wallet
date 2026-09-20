import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/mappers/account_mapper.dart';
import 'package:wallet/data/repositories/local/local_repository.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/entities/account.dart';
import 'package:wallet/domain/enums/app_enums.dart';

abstract class AccountRepository {
  Stream<List<Account>> watchActiveAccounts(String ledgerId);

  Future<List<Account>> getActiveAccounts(String ledgerId);

  Future<Account?> getById(String id);

  Future<Account> createAccount({
    required String ledgerId,
    required String name,
    required AccountCategory category,
    required String currencyCode,
    int initialBalanceMinor = 0,
    bool includeInTotal = true,
    bool isHidden = false,
    String? note,
  });

  Future<Account> updateAccount({
    required String id,
    String? name,
    AccountCategory? category,
    String? currencyCode,
    int? initialBalanceMinor,
    bool? includeInTotal,
    bool? isHidden,
    int? sortOrder,
    String? note,
  });

  Future<void> updateSortOrders(Map<String, int> idToSortOrder);

  Future<void> softDelete(String id);
}

class AccountLocalRepository extends LocalRepository implements AccountRepository {
  AccountLocalRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Stream<List<Account>> watchActiveAccounts(String ledgerId) {
    final query = _db.select(_db.accounts)
      ..where(
        (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.watch().map(AccountMapper.fromRows);
  }

  @override
  Future<List<Account>> getActiveAccounts(String ledgerId) async {
    final query = _db.select(_db.accounts)
      ..where(
        (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return AccountMapper.fromRows(await query.get());
  }

  @override
  Future<Account?> getById(String id) async {
    final row = await (_db.select(_db.accounts)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : AccountMapper.fromRow(row);
  }

  @override
  Future<Account> createAccount({
    required String ledgerId,
    required String name,
    required AccountCategory category,
    required String currencyCode,
    int initialBalanceMinor = 0,
    bool includeInTotal = true,
    bool isHidden = false,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final maxSort = await _maxSortOrder(ledgerId);

    await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            name: name,
            category: category,
            currencyCode: currencyCode,
            initialBalanceMinor: initialBalanceMinor,
            includeInTotal: Value(includeInTotal),
            isHidden: Value(isHidden),
            sortOrder: Value(maxSort + 1),
            note: Value(note),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return (await getById(id))!;
  }

  @override
  Future<Account> updateAccount({
    required String id,
    String? name,
    AccountCategory? category,
    String? currencyCode,
    int? initialBalanceMinor,
    bool? includeInTotal,
    bool? isHidden,
    int? sortOrder,
    String? note,
  }) async {
    final existing = await getById(id);
    if (existing == null) {
      throw RepositoryException('账户不存在');
    }

    final now = DateTime.now().toUtc();
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
          AccountsCompanion(
            name: name == null ? const Value.absent() : Value(name),
            category:
                category == null ? const Value.absent() : Value(category),
            currencyCode: currencyCode == null
                ? const Value.absent()
                : Value(currencyCode),
            initialBalanceMinor: initialBalanceMinor == null
                ? const Value.absent()
                : Value(initialBalanceMinor),
            includeInTotal: includeInTotal == null
                ? const Value.absent()
                : Value(includeInTotal),
            isHidden:
                isHidden == null ? const Value.absent() : Value(isHidden),
            sortOrder:
                sortOrder == null ? const Value.absent() : Value(sortOrder),
            note: note == null ? const Value.absent() : Value(note),
            updatedAt: Value(now),
          ),
        );

    return (await getById(id))!;
  }

  @override
  Future<void> updateSortOrders(Map<String, int> idToSortOrder) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      for (final entry in idToSortOrder.entries) {
        await (_db.update(_db.accounts)..where((t) => t.id.equals(entry.key)))
            .write(
          AccountsCompanion(
            sortOrder: Value(entry.value),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  @override
  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
          AccountsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<int> _maxSortOrder(String ledgerId) async {
    final query = _db.select(_db.accounts)
      ..where((t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
      ..limit(1);
    final rows = await query.get();
    if (rows.isEmpty) {
      return -1;
    }
    return rows.first.sortOrder;
  }
}
