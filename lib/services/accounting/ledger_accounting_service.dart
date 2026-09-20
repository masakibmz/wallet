import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/mappers/transaction_mapper.dart';
import 'package:wallet/data/repositories/local/account_local_repository.dart';
import 'package:wallet/data/repositories/local/transaction_input.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/accounting/accounting_service.dart';
import 'package:wallet/services/accounting/ledger_rollback_probe.dart';

/// Coordinates Drift transactions and auxiliary tables (Transfers, Refunds, …).
class LedgerAccountingService {
  LedgerAccountingService(
    this._db,
    this._accountRepository, [
    AccountingService? accounting,
  ]) : _accounting = accounting ?? const AccountingService();

  final AppDatabase _db;
  final AccountRepository _accountRepository;
  final AccountingService _accounting;
  static const _uuid = Uuid();

  Future<WalletTransaction> createTransaction(
    CreateTransactionInput input,
  ) async {
    await _validateInput(input);
    if (input.type == TransactionType.refund) {
      await _validateRefundCreate(input);
    }

    final now = DateTime.now().toUtc();
    final id = _uuid.v4();

    await _db.transaction(() async {
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: id,
              ledgerId: input.ledgerId,
              type: input.type,
              amountMinor: input.amountMinor,
              currencyCode: input.currencyCode,
              accountId: Value(input.accountId),
              toAccountId: Value(input.toAccountId),
              categoryId: Value(input.categoryId),
              subCategoryId: Value(input.subCategoryId),
              occurredAt: input.occurredAt.toUtc(),
              note: Value(input.note),
              feeMinor: Value(input.feeMinor),
              couponMinor: Value(input.couponMinor),
              reimbursementStatus: Value(input.reimbursementStatus),
              reimbursementTarget: Value(input.reimbursementTarget),
              originalTransactionId: Value(input.originalTransactionId),
              refundStatus: Value(input.refundStatus),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceTags(id, input.tagIds);
      await _syncTransferRowForTransaction(
        transactionId: id,
        input: input,
        now: now,
        isCreate: true,
      );
    });

    return (await _getById(id))!;
  }

  /// Creates refund transaction and [Refunds] row in one database transaction.
  Future<WalletTransaction> createRefundWithRecord({
    required CreateTransactionInput input,
    required RefundStatus refundStatus,
  }) async {
    await _validateInput(input);
    await _validateRefundCreate(input);

    final now = DateTime.now().toUtc();
    final id = _uuid.v4();

    await _db.transaction(() async {
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: id,
              ledgerId: input.ledgerId,
              type: TransactionType.refund,
              amountMinor: input.amountMinor,
              currencyCode: input.currencyCode,
              accountId: Value(input.accountId),
              occurredAt: input.occurredAt.toUtc(),
              note: Value(input.note),
              originalTransactionId: Value(input.originalTransactionId),
              refundStatus: Value(refundStatus),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceTags(id, input.tagIds);
      await _db.into(_db.refunds).insert(
            RefundsCompanion.insert(
              id: _uuid.v4(),
              originalTransactionId: input.originalTransactionId!,
              refundTransactionId: id,
              amountMinor: input.amountMinor,
              status: refundStatus,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    return (await _getById(id))!;
  }

  @visibleForTesting
  Future<void> debugRollbackProbe({required String ledgerId}) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: id,
              ledgerId: ledgerId,
              type: TransactionType.expense,
              amountMinor: 1,
              currencyCode: 'CNY',
              occurredAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      throw const LedgerRollbackProbeException();
    });
  }

  Future<WalletTransaction> updateTransaction(
    UpdateTransactionInput input,
  ) async {
    final existing = await _getById(input.id);
    if (existing == null) {
      throw RepositoryException('账单不存在');
    }

    final merged = CreateTransactionInput(
      ledgerId: existing.ledgerId,
      type: input.type ?? existing.type,
      amountMinor: input.amountMinor ?? existing.amountMinor,
      currencyCode: input.currencyCode ?? existing.currencyCode,
      occurredAt: input.occurredAt ?? existing.occurredAt,
      accountId: input.accountId ?? existing.accountId,
      toAccountId: input.toAccountId ?? existing.toAccountId,
      categoryId: input.categoryId ?? existing.categoryId,
      subCategoryId: input.subCategoryId ?? existing.subCategoryId,
      note: input.note ?? existing.note,
      feeMinor: input.feeMinor ?? existing.feeMinor,
      couponMinor: input.couponMinor ?? existing.couponMinor,
      reimbursementStatus:
          input.reimbursementStatus ?? existing.reimbursementStatus,
      reimbursementTarget:
          input.reimbursementTarget ?? existing.reimbursementTarget,
      originalTransactionId: existing.originalTransactionId,
      refundStatus: existing.refundStatus,
      tagIds: input.tagIds ?? existing.tagIds,
    );
    await _validateInput(merged);

    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.transactions)..where((t) => t.id.equals(input.id)))
          .write(
        TransactionsCompanion(
          type: input.type == null ? const Value.absent() : Value(input.type!),
          amountMinor: input.amountMinor == null
              ? const Value.absent()
              : Value(input.amountMinor!),
          currencyCode: input.currencyCode == null
              ? const Value.absent()
              : Value(input.currencyCode!),
          accountId: input.accountId == null
              ? const Value.absent()
              : Value(input.accountId),
          toAccountId: input.toAccountId == null
              ? const Value.absent()
              : Value(input.toAccountId),
          categoryId: input.categoryId == null
              ? const Value.absent()
              : Value(input.categoryId),
          subCategoryId: input.subCategoryId == null
              ? const Value.absent()
              : Value(input.subCategoryId),
          occurredAt: input.occurredAt == null
              ? const Value.absent()
              : Value(input.occurredAt!.toUtc()),
          note: input.note == null ? const Value.absent() : Value(input.note),
          feeMinor: input.feeMinor == null
              ? const Value.absent()
              : Value(input.feeMinor!),
          couponMinor: input.couponMinor == null
              ? const Value.absent()
              : Value(input.couponMinor!),
          reimbursementStatus: input.reimbursementStatus == null
              ? const Value.absent()
              : Value(input.reimbursementStatus!),
          reimbursementTarget: input.reimbursementTarget == null
              ? const Value.absent()
              : Value(input.reimbursementTarget),
          updatedAt: Value(now),
        ),
      );
      if (input.tagIds != null) {
        await _replaceTags(input.id, input.tagIds!);
      }
      await _syncTransferRowForTransaction(
        transactionId: input.id,
        input: merged,
        now: now,
        isCreate: false,
      );
    });

    return (await _getById(input.id))!;
  }

  Future<void> softDeleteTransaction(String id) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.transfers)..where((t) => t.transactionId.equals(id)))
          .write(
        TransfersCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.refunds)
            ..where((r) => r.refundTransactionId.equals(id)))
          .write(
        RefundsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<void> _syncTransferRowForTransaction({
    required String transactionId,
    required CreateTransactionInput input,
    required DateTime now,
    required bool isCreate,
  }) async {
    final isTransferLike = input.type == TransactionType.transfer ||
        input.type == TransactionType.creditRepayment;
    if (!isTransferLike) {
      if (!isCreate) {
        await (_db.update(_db.transfers)
              ..where(
                (t) =>
                    t.transactionId.equals(transactionId) &
                    t.deletedAt.isNull(),
              ))
            .write(
          TransfersCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
      return;
    }

    final from = input.accountId!;
    final to = input.toAccountId!;
    if (isCreate) {
      await _db.into(_db.transfers).insert(
            TransfersCompanion.insert(
              id: _uuid.v4(),
              transactionId: transactionId,
              fromAccountId: from,
              toAccountId: to,
              amountMinor: Value(input.amountMinor),
              feeMinor: Value(input.feeMinor),
              currencyCode: Value(input.currencyCode),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return;
    }

    final updated = await (_db.update(_db.transfers)
          ..where(
            (t) => t.transactionId.equals(transactionId) & t.deletedAt.isNull(),
          ))
        .write(
      TransfersCompanion(
        fromAccountId: Value(from),
        toAccountId: Value(to),
        amountMinor: Value(input.amountMinor),
        feeMinor: Value(input.feeMinor),
        currencyCode: Value(input.currencyCode),
        updatedAt: Value(now),
      ),
    );
    if (updated == 0) {
      await _db.into(_db.transfers).insert(
            TransfersCompanion.insert(
              id: _uuid.v4(),
              transactionId: transactionId,
              fromAccountId: from,
              toAccountId: to,
              amountMinor: Value(input.amountMinor),
              feeMinor: Value(input.feeMinor),
              currencyCode: Value(input.currencyCode),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _validateRefundCreate(CreateTransactionInput input) async {
    final originalId = input.originalTransactionId;
    if (originalId == null) {
      throw RepositoryException('退款必须关联原账单');
    }
    final original = await _getById(originalId);
    if (original == null) {
      throw RepositoryException('原账单不存在');
    }
    if (original.type != TransactionType.expense) {
      throw RepositoryException('仅支持对支出账单退款');
    }
    final all = await _allTransactionsForLedger(input.ledgerId);
    try {
      _accounting.assertRefundAllowed(
        originalExpense: original,
        allTransactions: all,
        refundAmountMinor: input.amountMinor,
      );
    } on AccountingRuleException catch (e) {
      throw RepositoryException(e.message);
    }
  }

  Future<List<WalletTransaction>> _allTransactionsForLedger(
    String ledgerId,
  ) async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    return _attachTags(rows);
  }

  Future<void> _validateInput(CreateTransactionInput input) async {
    if (input.amountMinor <= 0) {
      throw RepositoryException('金额必须大于 0');
    }
    if (input.feeMinor < 0 || input.couponMinor < 0) {
      throw RepositoryException('手续费或优惠不能为负数');
    }

    switch (input.type) {
      case TransactionType.expense:
      case TransactionType.income:
        await _assertUsableAccount(input.accountId, input.ledgerId);
      case TransactionType.transfer:
      case TransactionType.creditRepayment:
        await _assertUsableAccount(input.accountId, input.ledgerId);
        await _assertUsableAccount(input.toAccountId, input.ledgerId);
        if (input.accountId == input.toAccountId) {
          throw RepositoryException('转出与转入账户不能相同');
        }
      case TransactionType.refund:
        await _assertUsableAccount(input.accountId, input.ledgerId);
    }
  }

  Future<void> _assertUsableAccount(String? accountId, String ledgerId) async {
    if (accountId == null || accountId.isEmpty) {
      throw RepositoryException('请选择账户');
    }
    final account = await _accountRepository.getById(accountId);
    if (account == null || account.ledgerId != ledgerId) {
      throw RepositoryException('账户无效');
    }
    if (account.isHidden) {
      throw RepositoryException('隐藏账户不能用于记账');
    }
  }

  Future<WalletTransaction?> _getById(String id) async {
    final row = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    final tags = await _tagIdsForTransaction(id);
    return TransactionMapper.fromRow(row, tagIds: tags);
  }

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

  Future<void> _replaceTags(String transactionId, List<String> tagIds) async {
    await (_db.delete(_db.transactionTags)
          ..where((t) => t.transactionId.equals(transactionId)))
        .go();
    if (tagIds.isEmpty) {
      return;
    }
    await _db.batch((batch) {
      batch.insertAll(
        _db.transactionTags,
        tagIds
            .map(
              (tagId) => TransactionTagsCompanion.insert(
                transactionId: transactionId,
                tagId: tagId,
              ),
            )
            .toList(),
      );
    });
  }
}
