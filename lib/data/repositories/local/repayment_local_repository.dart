import 'package:wallet/data/repositories/local/transaction_input.dart';
import 'package:wallet/data/repositories/local/transaction_local_repository.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/accounting/ledger_accounting_service.dart';

abstract class RepaymentRepository {
  Future<WalletTransaction> createRepayment({
    required String ledgerId,
    required String sourceAccountId,
    required String creditAccountId,
    required int amountMinor,
    required String currencyCode,
    DateTime? occurredAt,
    String? note,
    int feeMinor = 0,
  });

  Future<void> deleteRepayment(String transactionId);
}

class RepaymentLocalRepository implements RepaymentRepository {
  RepaymentLocalRepository(this._ledger, this._transactions);

  final LedgerAccountingService _ledger;
  final TransactionRepository _transactions;

  @override
  Future<WalletTransaction> createRepayment({
    required String ledgerId,
    required String sourceAccountId,
    required String creditAccountId,
    required int amountMinor,
    required String currencyCode,
    DateTime? occurredAt,
    String? note,
    int feeMinor = 0,
  }) {
    return _ledger.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.creditRepayment,
        amountMinor: amountMinor,
        currencyCode: currencyCode,
        accountId: sourceAccountId,
        toAccountId: creditAccountId,
        occurredAt: occurredAt ?? DateTime.now(),
        note: note,
        feeMinor: feeMinor,
      ),
    );
  }

  @override
  Future<void> deleteRepayment(String transactionId) async {
    final tx = await _transactions.getById(transactionId);
    if (tx == null || tx.type != TransactionType.creditRepayment) {
      return;
    }
    await _ledger.softDeleteTransaction(transactionId);
  }
}
