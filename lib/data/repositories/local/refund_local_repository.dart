import 'package:wallet/data/repositories/local/local_repository.dart';
import 'package:wallet/data/repositories/local/transaction_input.dart';
import 'package:wallet/data/repositories/local/transaction_local_repository.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/accounting/accounting_service.dart';
import 'package:wallet/services/accounting/ledger_accounting_service.dart';

abstract class RefundRepository {
  Future<WalletTransaction> createRefund({
    required String ledgerId,
    required String originalTransactionId,
    required int refundAmountMinor,
    required String currencyCode,
    String? accountId,
    DateTime? occurredAt,
    String? note,
  });

  Future<void> deleteRefund(String refundTransactionId);
}

class RefundLocalRepository extends LocalRepository implements RefundRepository {
  RefundLocalRepository(
    this._transactions,
    this._ledger, [
    AccountingService? accounting,
  ]) : _accounting = accounting ?? const AccountingService();

  final TransactionRepository _transactions;
  final LedgerAccountingService _ledger;
  final AccountingService _accounting;

  @override
  Future<WalletTransaction> createRefund({
    required String ledgerId,
    required String originalTransactionId,
    required int refundAmountMinor,
    required String currencyCode,
    String? accountId,
    DateTime? occurredAt,
    String? note,
  }) async {
    final original = await _transactions.getById(originalTransactionId);
    if (original == null || original.ledgerId != ledgerId) {
      throw RepositoryException('原账单不存在');
    }

    final all = await _transactions.getTransactions(ledgerId: ledgerId);
    try {
      _accounting.assertRefundAllowed(
        originalExpense: original,
        allTransactions: all,
        refundAmountMinor: refundAmountMinor,
      );
    } on AccountingRuleException catch (e) {
      throw RepositoryException(e.message);
    }

    final remainingAfter = _accounting.refundableRemainingMinor(
      originalExpense: original,
      allTransactions: all,
    );
    final isFull = refundAmountMinor == remainingAfter;

    return _ledger.createRefundWithRecord(
      input: CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.refund,
        amountMinor: refundAmountMinor,
        currencyCode: currencyCode,
        accountId: accountId ?? original.accountId,
        occurredAt: occurredAt ?? DateTime.now(),
        note: note,
        originalTransactionId: originalTransactionId,
        refundStatus: isFull ? RefundStatus.full : RefundStatus.partial,
      ),
      refundStatus: isFull ? RefundStatus.full : RefundStatus.partial,
    );
  }

  @override
  Future<void> deleteRefund(String refundTransactionId) async {
    await _ledger.softDeleteTransaction(refundTransactionId);
  }
}
