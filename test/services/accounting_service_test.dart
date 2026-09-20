import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/domain/accounting/account_classifier.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/account_balance_service.dart';
import 'package:wallet/services/accounting/accounting_service.dart';
import 'package:wallet/services/transaction_summary_service.dart';

void main() {
  const accounting = AccountingService();
  const balances = AccountBalanceService(accounting);
  const summary = TransactionSummaryService(accounting);

  const assetA = 'asset-a';
  const assetB = 'asset-b';
  const credit = 'credit-1';

  final nature = {
    assetA: AccountNature.asset,
    assetB: AccountNature.asset,
    credit: AccountNature.liability,
  };

  WalletTransaction tx({
    required String id,
    required TransactionType type,
    required int amount,
    String? accountId,
    String? toAccountId,
    int fee = 0,
    int coupon = 0,
    String? originalTransactionId,
    DateTime? at,
  }) {
    final t = at ?? DateTime.utc(2026, 1, 1);
    return WalletTransaction(
      id: id,
      ledgerId: 'l1',
      type: type,
      amountMinor: amount,
      currencyCode: 'CNY',
      accountId: accountId ?? assetA,
      toAccountId: toAccountId,
      occurredAt: t,
      feeMinor: fee,
      couponMinor: coupon,
      originalTransactionId: originalTransactionId,
      createdAt: t,
      updatedAt: t,
    );
  }

  group('asset accounts', () {
    test('expense income update balance', () {
      final txs = [
        tx(id: 'e1', type: TransactionType.expense, amount: 3200),
        tx(id: 'i1', type: TransactionType.income, amount: 5000),
      ];
      final b = balances.balanceMinor(
        initialBalanceMinor: 10000,
        accountId: assetA,
        transactions: txs,
        natureByAccountId: nature,
      );
      expect(b, 11800);
    });

    test('expense includes fee', () {
      final b = balances.balanceMinor(
        initialBalanceMinor: 1000,
        accountId: assetA,
        transactions: [
          tx(id: 'e1', type: TransactionType.expense, amount: 100, fee: 50),
        ],
        natureByAccountId: nature,
      );
      expect(b, 850);
    });

    test('coupon does not increase cash outflow', () {
      final b = balances.balanceMinor(
        initialBalanceMinor: 10000,
        accountId: assetA,
        transactions: [
          tx(
            id: 'e1',
            type: TransactionType.expense,
            amount: 8000,
            coupon: 2000,
          ),
        ],
        natureByAccountId: nature,
      );
      expect(b, 2000);
    });
  });

  group('transfer', () {
    test('transfer with fee splits amount and fee', () {
      final transfer = tx(
        id: 't1',
        type: TransactionType.transfer,
        amount: 10000,
        accountId: assetA,
        toAccountId: assetB,
        fee: 100,
      );
      final from = balances.balanceMinor(
        initialBalanceMinor: 50000,
        accountId: assetA,
        transactions: [transfer],
        natureByAccountId: nature,
      );
      final to = balances.balanceMinor(
        initialBalanceMinor: 0,
        accountId: assetB,
        transactions: [transfer],
        natureByAccountId: nature,
      );
      expect(from, 39900);
      expect(to, 10000);
    });
  });

  group('refund', () {
    test('partial and multiple refunds reduce effective expense', () {
      final expense = tx(
        id: 'exp',
        type: TransactionType.expense,
        amount: 10000,
      );
      final txs = [
        expense,
        tx(
          id: 'r1',
          type: TransactionType.refund,
          amount: 3000,
          originalTransactionId: 'exp',
        ),
        tx(
          id: 'r2',
          type: TransactionType.refund,
          amount: 2000,
          originalTransactionId: 'exp',
        ),
      ];
      expect(
        accounting.refundableRemainingMinor(
          originalExpense: expense,
          allTransactions: txs,
        ),
        5000,
      );
      expect(
        accounting.effectiveExpenseMinor(
          expense: expense,
          allTransactions: txs,
        ),
        5000,
      );
      final b = balances.balanceMinor(
        initialBalanceMinor: 10000,
        accountId: assetA,
        transactions: txs,
        natureByAccountId: nature,
      );
      expect(b, 5000);
    });

    test('over refund rejected', () {
      final expense = tx(
        id: 'exp',
        type: TransactionType.expense,
        amount: 10000,
      );
      expect(
        () => accounting.assertRefundAllowed(
          originalExpense: expense,
          allTransactions: [expense],
          refundAmountMinor: 10001,
        ),
        throwsA(isA<AccountingRuleException>()),
      );
    });
  });

  group('credit card', () {
    test('expense increases liability position', () {
      final snap = accounting.liabilitySnapshot(
        initialBalanceMinor: 0,
        accountId: credit,
        transactions: [
          tx(
            id: 'c1',
            type: TransactionType.expense,
            amount: 10000,
            accountId: credit,
          ),
        ],
        natureByAccountId: nature,
      );
      expect(snap.debtMinor, 10000);
      expect(snap.overpaymentMinor, 0);
    });

    test('repayment reduces debt', () {
      final txs = [
        tx(
          id: 'c1',
          type: TransactionType.expense,
          amount: 100000,
          accountId: credit,
        ),
        tx(
          id: 'p1',
          type: TransactionType.creditRepayment,
          amount: 30000,
          accountId: assetA,
          toAccountId: credit,
        ),
      ];
      final snap = accounting.liabilitySnapshot(
        initialBalanceMinor: 0,
        accountId: credit,
        transactions: txs,
        natureByAccountId: nature,
      );
      expect(snap.debtMinor, 70000);
      final bank = balances.balanceMinor(
        initialBalanceMinor: 500000,
        accountId: assetA,
        transactions: txs,
        natureByAccountId: nature,
      );
      expect(bank, 470000);
    });

    test('overpayment and spend against overpayment', () {
      final txs = [
        tx(
          id: 'c1',
          type: TransactionType.expense,
          amount: 50000,
          accountId: credit,
        ),
        tx(
          id: 'p1',
          type: TransactionType.creditRepayment,
          amount: 60000,
          accountId: assetA,
          toAccountId: credit,
        ),
        tx(
          id: 'c2',
          type: TransactionType.expense,
          amount: 6000,
          accountId: credit,
        ),
      ];
      final snap = accounting.liabilitySnapshot(
        initialBalanceMinor: 0,
        accountId: credit,
        transactions: txs,
        natureByAccountId: nature,
      );
      expect(snap.debtMinor, 0);
      expect(snap.overpaymentMinor, 4000);
    });
  });

  group('statistics', () {
    test('transfer and repayment excluded from expense', () {
      final month = DateTime(2026, 1);
      final s = summary.monthSummary(
        month: month,
        transactions: [
          tx(
            id: 'e1',
            type: TransactionType.expense,
            amount: 1000,
            at: DateTime.utc(2026, 1, 5),
          ),
          tx(
            id: 't1',
            type: TransactionType.transfer,
            amount: 5000,
            accountId: assetA,
            toAccountId: assetB,
            at: DateTime.utc(2026, 1, 6),
          ),
          tx(
            id: 'r1',
            type: TransactionType.creditRepayment,
            amount: 1000,
            accountId: assetA,
            toAccountId: credit,
            at: DateTime.utc(2026, 1, 7),
          ),
        ],
      );
      expect(s.expenseMinor, 1000);
      expect(s.incomeMinor, 0);
    });

    test('refund reduces net expense', () {
      final month = DateTime(2026, 1);
      final s = summary.monthSummary(
        month: month,
        transactions: [
          tx(
            id: 'e1',
            type: TransactionType.expense,
            amount: 10000,
            at: DateTime.utc(2026, 1, 5),
          ),
          tx(
            id: 'rf1',
            type: TransactionType.refund,
            amount: 3000,
            originalTransactionId: 'e1',
            at: DateTime.utc(2026, 1, 8),
          ),
        ],
      );
      expect(s.expenseMinor, 7000);
    });

    test('reimbursement income excluded from net income', () {
      final month = DateTime(2026, 1);
      final s = summary.monthSummary(
        month: month,
        transactions: [
          tx(
            id: 'inc1',
            type: TransactionType.income,
            amount: 8000,
            at: DateTime.utc(2026, 1, 10),
          ),
          tx(
            id: 'reimb',
            type: TransactionType.income,
            amount: 10000,
            at: DateTime.utc(2026, 1, 11),
          ),
        ],
        reimbursementIncomeTransactionIds: {'reimb'},
      );
      expect(s.incomeMinor, 8000);
    });
  });
}
