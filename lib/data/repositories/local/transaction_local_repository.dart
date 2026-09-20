import 'package:drift/drift.dart';

import 'package:wallet/data/database/app_database.dart';

import 'package:wallet/data/mappers/transaction_mapper.dart';

import 'package:wallet/data/repositories/local/account_local_repository.dart';

import 'package:wallet/data/repositories/local/local_repository.dart';

import 'package:wallet/data/repositories/local/transaction_input.dart';

import 'package:wallet/domain/entities/transaction.dart';

import 'package:wallet/services/accounting/ledger_accounting_service.dart';



abstract class TransactionRepository {

  Stream<int> watchTransactionCount({required String ledgerId});



  Stream<List<WalletTransaction>> watchTransactions({

    required String ledgerId,

  });



  Future<List<WalletTransaction>> getTransactions({

    required String ledgerId,

  });



  Future<WalletTransaction?> getById(String id);



  Future<WalletTransaction> createTransaction(CreateTransactionInput input);



  Future<WalletTransaction> updateTransaction(UpdateTransactionInput input);



  Future<void> softDelete(String id);

}



class TransactionLocalRepository extends LocalRepository

    implements TransactionRepository {

  TransactionLocalRepository(
    this._db,
    AccountRepository accountRepository, [
    LedgerAccountingService? ledger,
  ]) : _ledger = ledger ?? LedgerAccountingService(_db, accountRepository);

  final AppDatabase _db;
  final LedgerAccountingService _ledger;



  @override

  Stream<int> watchTransactionCount({required String ledgerId}) {

    return watchTransactions(ledgerId: ledgerId).map((list) => list.length);

  }



  @override

  Stream<List<WalletTransaction>> watchTransactions({

    required String ledgerId,

  }) {

    final query = _db.select(_db.transactions)

      ..where(

        (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),

      )

      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);

    return query.watch().asyncMap(_attachTags);

  }



  @override

  Future<List<WalletTransaction>> getTransactions({

    required String ledgerId,

  }) async {

    final rows = await (_db.select(_db.transactions)

          ..where(

            (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),

          )

          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))

        .get();

    return _attachTags(rows);

  }



  @override

  Future<WalletTransaction?> getById(String id) async {

    final row = await (_db.select(_db.transactions)

          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))

        .getSingleOrNull();

    if (row == null) {

      return null;

    }

    final tags = await _tagIdsForTransaction(id);

    return TransactionMapper.fromRow(row, tagIds: tags);

  }



  @override

  Future<WalletTransaction> createTransaction(

    CreateTransactionInput input,

  ) =>

      _ledger.createTransaction(input);



  @override

  Future<WalletTransaction> updateTransaction(

    UpdateTransactionInput input,

  ) =>

      _ledger.updateTransaction(input);



  @override

  Future<void> softDelete(String id) => _ledger.softDeleteTransaction(id);



  Future<List<WalletTransaction>> _attachTags(

    List<TransactionRow> rows,

  ) async {

    if (rows.isEmpty) {

      return const [];

    }

    final ids = rows.map((r) => r.id).toList();

    final tagRows = await (_db.select(_db.transactionTags)

          ..where((t) => t.transactionId.isIn(ids)))

        .get();

    final tagMap = <String, List<String>>{};

    for (final link in tagRows) {

      tagMap.putIfAbsent(link.transactionId, () => []).add(link.tagId);

    }

    return rows

        .map(

          (r) => TransactionMapper.fromRow(

            r,

            tagIds: tagMap[r.id] ?? const [],

          ),

        )

        .toList(growable: false);

  }



  Future<List<String>> _tagIdsForTransaction(String transactionId) async {

    final rows = await (_db.select(_db.transactionTags)

          ..where((t) => t.transactionId.equals(transactionId)))

        .get();

    return rows.map((r) => r.tagId).toList(growable: false);

  }

}


