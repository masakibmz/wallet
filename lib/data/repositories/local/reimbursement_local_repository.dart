import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/repositories/local/local_repository.dart';
import 'package:wallet/data/repositories/local/transaction_input.dart';
import 'package:wallet/data/repositories/local/transaction_local_repository.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/accounting/ledger_accounting_service.dart';

abstract class ReimbursementRepository {
  Future<Set<String>> getIncomeTransactionIdsForLedger(String ledgerId);

  Future<void> markExpensePendingReimbursement({
    required String expenseTransactionId,
    required int amountMinor,
    String? target,
  });

  Future<String> recordReimbursementIncome({
    required String ledgerId,
    required String expenseTransactionId,
    required String incomeAccountId,
    required int amountMinor,
    required String currencyCode,
    DateTime? occurredAt,
    String? note,
  });
}

class ReimbursementLocalRepository extends LocalRepository
    implements ReimbursementRepository {
  ReimbursementLocalRepository(
    this._db,
    this._ledger,
    this._transactions,
  );

  final AppDatabase _db;
  final LedgerAccountingService _ledger;
  final TransactionRepository _transactions;
  static const _uuid = Uuid();

  @override
  Future<Set<String>> getIncomeTransactionIdsForLedger(String ledgerId) async {
    final rows = await (_db.select(_db.reimbursements)
          ..where((r) => r.deletedAt.isNull() & r.incomeTransactionId.isNotNull()))
        .get();
    if (rows.isEmpty) {
      return const {};
    }
    final incomeIds = rows.map((r) => r.incomeTransactionId!).toList();
    final txRows = await (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.id.isIn(incomeIds) &
                t.ledgerId.equals(ledgerId) &
                t.deletedAt.isNull(),
          ))
        .get();
    return txRows.map((t) => t.id).toSet();
  }

  @override
  Future<void> markExpensePendingReimbursement({
    required String expenseTransactionId,
    required int amountMinor,
    String? target,
  }) async {
    final expense = await _transactions.getById(expenseTransactionId);
    if (expense == null || expense.type != TransactionType.expense) {
      throw RepositoryException('报销必须关联支出账单');
    }
    if (amountMinor <= 0 || amountMinor > expense.amountMinor) {
      throw RepositoryException('报销金额无效');
    }
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.transactions)
            ..where((t) => t.id.equals(expenseTransactionId)))
          .write(
        TransactionsCompanion(
          reimbursementStatus: const Value(ReimbursementStatus.pending),
          reimbursementTarget: Value(target),
          updatedAt: Value(now),
        ),
      );
      await _db.into(_db.reimbursements).insert(
            ReimbursementsCompanion.insert(
              id: _uuid.v4(),
              transactionId: expenseTransactionId,
              amountMinor: amountMinor,
              target: Value(target),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  @override
  Future<String> recordReimbursementIncome({
    required String ledgerId,
    required String expenseTransactionId,
    required String incomeAccountId,
    required int amountMinor,
    required String currencyCode,
    DateTime? occurredAt,
    String? note,
  }) async {
    final expense = await _transactions.getById(expenseTransactionId);
    if (expense == null || expense.type != TransactionType.expense) {
      throw RepositoryException('报销必须关联支出账单');
    }
    final now = DateTime.now().toUtc();
    final income = await _ledger.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.income,
        amountMinor: amountMinor,
        currencyCode: currencyCode,
        accountId: incomeAccountId,
        occurredAt: occurredAt ?? DateTime.now(),
        note: note ?? '报销入账',
      ),
    );

    await _db.transaction(() async {
      await (_db.update(_db.reimbursements)
            ..where(
              (r) =>
                  r.transactionId.equals(expenseTransactionId) &
                  r.deletedAt.isNull(),
            ))
          .write(
        ReimbursementsCompanion(
          incomeTransactionId: Value(income.id),
          reimbursedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.transactions)
            ..where((t) => t.id.equals(expenseTransactionId)))
          .write(
        TransactionsCompanion(
          reimbursementStatus: const Value(ReimbursementStatus.reimbursed),
          updatedAt: Value(now),
        ),
      );
    });
    return income.id;
  }
}
