import 'package:drift/drift.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/repositories/local/local_repository.dart';

class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.transactionId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountMinor,
    required this.feeMinor,
    this.currencyCode,
  });

  final String id;
  final String transactionId;
  final String fromAccountId;
  final String toAccountId;
  final int amountMinor;
  final int feeMinor;
  final String? currencyCode;
}

abstract class TransferRepository {
  Future<TransferRecord?> getByTransactionId(String transactionId);

  Future<List<TransferRecord>> listActiveForLedger(String ledgerId);
}

class TransferLocalRepository extends LocalRepository
    implements TransferRepository {
  TransferLocalRepository(this._db);

  final AppDatabase _db;

  @override
  Future<TransferRecord?> getByTransactionId(String transactionId) async {
    final row = await (_db.select(_db.transfers)
          ..where(
            (t) =>
                t.transactionId.equals(transactionId) & t.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<TransferRecord>> listActiveForLedger(String ledgerId) async {
    final txs = await (_db.select(_db.transactions)
          ..where(
            (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
          ))
        .get();
    if (txs.isEmpty) {
      return const [];
    }
    final ids = txs.map((t) => t.id).toList();
    final rows = await (_db.select(_db.transfers)
          ..where(
            (t) => t.transactionId.isIn(ids) & t.deletedAt.isNull(),
          ))
        .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  TransferRecord _fromRow(TransferRow row) {
    return TransferRecord(
      id: row.id,
      transactionId: row.transactionId,
      fromAccountId: row.fromAccountId,
      toAccountId: row.toAccountId,
      amountMinor: row.amountMinor,
      feeMinor: row.feeMinor,
      currencyCode: row.currencyCode,
    );
  }
}
