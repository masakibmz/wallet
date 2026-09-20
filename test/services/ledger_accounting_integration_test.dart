import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/repositories/local/account_local_repository.dart';
import 'package:wallet/data/repositories/local/ledger_local_repository.dart';
import 'package:wallet/data/repositories/local/refund_local_repository.dart';
import 'package:wallet/data/repositories/local/reimbursement_local_repository.dart';
import 'package:wallet/data/repositories/local/repayment_local_repository.dart';
import 'package:wallet/data/repositories/local/transaction_input.dart';
import 'package:wallet/data/repositories/local/transaction_local_repository.dart';
import 'package:wallet/data/repositories/local/transfer_local_repository.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/accounting/account_classifier.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/account_balance_service.dart';
import 'package:wallet/services/accounting/accounting_service.dart';
import 'package:wallet/services/accounting/ledger_accounting_service.dart';
import 'package:wallet/services/accounting/ledger_rollback_probe.dart';
import 'package:wallet/services/ledger_onboarding_service.dart';

void main() {
  late AppDatabase db;
  late AccountLocalRepository accountRepo;
  late LedgerAccountingService ledger;
  late TransactionLocalRepository txRepo;
  late TransferLocalRepository transferRepo;
  late RefundLocalRepository refundRepo;
  late RepaymentLocalRepository repaymentRepo;
  late ReimbursementLocalRepository reimbursementRepo;
  late AccountBalanceService balanceService;

  setUp(() async {
    db = AppDatabase.inMemory();
    accountRepo = AccountLocalRepository(db);
    const accounting = AccountingService();
    ledger = LedgerAccountingService(db, accountRepo, accounting);
    txRepo = TransactionLocalRepository(db, accountRepo, ledger);
    transferRepo = TransferLocalRepository(db);
    refundRepo = RefundLocalRepository(txRepo, ledger, accounting);
    repaymentRepo = RepaymentLocalRepository(ledger, txRepo);
    reimbursementRepo = ReimbursementLocalRepository(db, ledger, txRepo);
    balanceService = AccountBalanceService(accounting);
  });

  tearDown(() async {
    await db.close();
  });

  Future<(String ledgerId, String cashId, String bankId, String creditId)>
      setupAccounts() async {
    final ledgerRepo = LedgerLocalRepository(db);
    await ledgerRepo.ensureDefaultLedger();
    final ledgerId = (await ledgerRepo.getDefaultLedger())!.id;
    await LedgerOnboardingService(db).onboard(ledgerId);
    final cash = (await accountRepo.getActiveAccounts(ledgerId)).single;
    final bank = await accountRepo.createAccount(
      ledgerId: ledgerId,
      name: '银行卡',
      category: AccountCategory.bank,
      currencyCode: 'CNY',
      initialBalanceMinor: 100000,
    );
    final credit = await accountRepo.createAccount(
      ledgerId: ledgerId,
      name: '信用卡',
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      initialBalanceMinor: 0,
    );
    return (ledgerId, cash.id, bank.id, credit.id);
  }

  Map<String, AccountNature> natureFor(Map<String, AccountCategory> cats) {
    return {
      for (final e in cats.entries)
        e.key: AccountClassifier.natureOf(e.value),
    };
  }

  int assetBalance(
    String accountId,
    int initial,
    List<WalletTransaction> txs,
    Map<String, AccountNature> natureMap,
  ) {
    return balanceService.balanceMinor(
      initialBalanceMinor: initial,
      accountId: accountId,
      transactions: txs,
      natureByAccountId: natureMap,
    );
  }

  test('transfer writes Transfers row and delete restores balances', () async {
    final (ledgerId, cashId, bankId, _) = await setupAccounts();
    final nature = natureFor({
      cashId: AccountCategory.cash,
      bankId: AccountCategory.bank,
    });
    final transfer = await txRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.transfer,
        amountMinor: 10000,
        feeMinor: 100,
        currencyCode: 'CNY',
        accountId: bankId,
        toAccountId: cashId,
        occurredAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final row = await transferRepo.getByTransactionId(transfer.id);
    expect(row, isNotNull);
    expect(row!.amountMinor, 10000);
    expect(row.feeMinor, 100);

    var txs = await txRepo.getTransactions(ledgerId: ledgerId);
    expect(assetBalance(bankId, 100000, txs, nature), 89900);
    expect(assetBalance(cashId, 0, txs, nature), 10000);

    await txRepo.softDelete(transfer.id);
    txs = await txRepo.getTransactions(ledgerId: ledgerId);
    expect(assetBalance(bankId, 100000, txs, nature), 100000);
    expect(assetBalance(cashId, 0, txs, nature), 0);
    expect(await transferRepo.getByTransactionId(transfer.id), isNull);
  });

  test('update transfer amount reverses old effect', () async {
    final (ledgerId, cashId, bankId, _) = await setupAccounts();
    final nature = natureFor({
      cashId: AccountCategory.cash,
      bankId: AccountCategory.bank,
    });
    final transfer = await txRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.transfer,
        amountMinor: 5000,
        currencyCode: 'CNY',
        accountId: bankId,
        toAccountId: cashId,
        occurredAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await txRepo.updateTransaction(
      UpdateTransactionInput(id: transfer.id, amountMinor: 8000),
    );
    final txs = await txRepo.getTransactions(ledgerId: ledgerId);
    expect(assetBalance(bankId, 100000, txs, nature), 92000);
    expect(assetBalance(cashId, 0, txs, nature), 8000);
  });

  test('refund partial multiple and over limit', () async {
    final (ledgerId, cashId, _, creditUnused) = await setupAccounts();
    expect(creditUnused, isNotEmpty);
    final expense = await txRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.expense,
        amountMinor: 10000,
        currencyCode: 'CNY',
        accountId: cashId,
        occurredAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await refundRepo.createRefund(
      ledgerId: ledgerId,
      originalTransactionId: expense.id,
      refundAmountMinor: 3000,
      currencyCode: 'CNY',
    );
    await refundRepo.createRefund(
      ledgerId: ledgerId,
      originalTransactionId: expense.id,
      refundAmountMinor: 2000,
      currencyCode: 'CNY',
    );
    expect(
      () => refundRepo.createRefund(
        ledgerId: ledgerId,
        originalTransactionId: expense.id,
        refundAmountMinor: 6000,
        currencyCode: 'CNY',
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('credit repayment and overpayment spend', () async {
    final (ledgerId, _, bankId, creditId) = await setupAccounts();
    await txRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.expense,
        amountMinor: 50000,
        currencyCode: 'CNY',
        accountId: creditId,
        occurredAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await repaymentRepo.createRepayment(
      ledgerId: ledgerId,
      sourceAccountId: bankId,
      creditAccountId: creditId,
      amountMinor: 60000,
      currencyCode: 'CNY',
    );
    await txRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.expense,
        amountMinor: 6000,
        currencyCode: 'CNY',
        accountId: creditId,
        occurredAt: DateTime.utc(2026, 1, 2),
      ),
    );
    final txs = await txRepo.getTransactions(ledgerId: ledgerId);
    const accounting = AccountingService();
    final snap = accounting.liabilitySnapshot(
      initialBalanceMinor: 0,
      accountId: creditId,
      transactions: txs,
      natureByAccountId: {
        creditId: AccountNature.liability,
        bankId: AccountNature.asset,
      },
    );
    expect(snap.debtMinor, 0);
    expect(snap.overpaymentMinor, 4000);
  });

  test('delete expense restores balance', () async {
    final (ledgerId, cashId, _, creditUnused) = await setupAccounts();
    expect(creditUnused, isNotEmpty);
    final nature = natureFor({cashId: AccountCategory.cash});
    final expense = await txRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.expense,
        amountMinor: 4500,
        currencyCode: 'CNY',
        accountId: cashId,
        occurredAt: DateTime.utc(2026, 1, 1),
      ),
    );
    var txs = await txRepo.getTransactions(ledgerId: ledgerId);
    expect(assetBalance(cashId, 0, txs, nature), -4500);
    await txRepo.softDelete(expense.id);
    txs = await txRepo.getTransactions(ledgerId: ledgerId);
    expect(assetBalance(cashId, 0, txs, nature), 0);
  });

  test('delete refund restores balance and refundable amount', () async {
    final (ledgerId, cashId, _, creditUnused) = await setupAccounts();
    expect(creditUnused, isNotEmpty);
    final nature = natureFor({cashId: AccountCategory.cash});
    final expense = await txRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.expense,
        amountMinor: 10000,
        currencyCode: 'CNY',
        accountId: cashId,
        occurredAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await refundRepo.createRefund(
      ledgerId: ledgerId,
      originalTransactionId: expense.id,
      refundAmountMinor: 4000,
      currencyCode: 'CNY',
    );
    final refunds = await txRepo.getTransactions(ledgerId: ledgerId);
    final refundTx = refunds.firstWhere((t) => t.type == TransactionType.refund);
    await refundRepo.deleteRefund(refundTx.id);
    final txs = await txRepo.getTransactions(ledgerId: ledgerId);
    expect(assetBalance(cashId, 10000, txs, nature), 0);
    const accounting = AccountingService();
    expect(
      accounting.refundableRemainingMinor(
        originalExpense: expense,
        allTransactions: txs,
      ),
      10000,
    );
  });

  test('database transaction rolls back on failure', () async {
    final (ledgerId, _, _, _) = await setupAccounts();
    expect(
      () => ledger.debugRollbackProbe(ledgerId: ledgerId),
      throwsA(isA<LedgerRollbackProbeException>()),
    );
    final txs = await txRepo.getTransactions(ledgerId: ledgerId);
    expect(txs.where((t) => t.amountMinor == 1), isEmpty);
  });

  test('reimbursement marks expense reimbursed', () async {
    final (ledgerId, cashId, _, creditUnused) = await setupAccounts();
    expect(creditUnused, isNotEmpty);
    final expense = await txRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.expense,
        amountMinor: 10000,
        currencyCode: 'CNY',
        accountId: cashId,
        occurredAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await reimbursementRepo.markExpensePendingReimbursement(
      expenseTransactionId: expense.id,
      amountMinor: 10000,
    );
    final incomeId = await reimbursementRepo.recordReimbursementIncome(
      ledgerId: ledgerId,
      expenseTransactionId: expense.id,
      incomeAccountId: cashId,
      amountMinor: 10000,
      currencyCode: 'CNY',
    );
    expect(incomeId, isNotEmpty);
    final updated = (await txRepo.getById(expense.id))!;
    expect(updated.reimbursementStatus, ReimbursementStatus.reimbursed);
  });
}
