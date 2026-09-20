import 'package:wallet/domain/accounting/account_classifier.dart';
import 'package:wallet/domain/accounting/accounting_models.dart';
import 'package:wallet/domain/accounting/transaction_money.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';

/// Pure accounting rules: postings, balances, liability, refunds, statistics.
class AccountingService {
  const AccountingService();

  List<AccountPosting> postingsFor(
    WalletTransaction tx,
    Map<String, AccountNature> natureByAccountId,
  ) {
    if (tx.isDeleted) {
      return const [];
    }
    AccountNature? nature(String? id) =>
        id == null ? null : natureByAccountId[id];

    final paid = TransactionMoney.paidMinor(tx);
    final fee = TransactionMoney.feeMinor(tx);
    final cashOut = TransactionMoney.cashOutflowMinor(tx);

    switch (tx.type) {
      case TransactionType.expense:
        final n = nature(tx.accountId);
        if (n == null) {
          return const [];
        }
        if (n == AccountNature.liability) {
          return [
            AccountPosting(
              accountId: tx.accountId!,
              nature: AccountNature.liability,
              deltaMinor: cashOut,
            ),
          ];
        }
        return [
          AccountPosting(
            accountId: tx.accountId!,
            nature: AccountNature.asset,
            deltaMinor: -cashOut,
          ),
        ];
      case TransactionType.income:
        final n = nature(tx.accountId);
        if (n == null || n == AccountNature.liability) {
          return const [];
        }
        return [
          AccountPosting(
            accountId: tx.accountId!,
            nature: AccountNature.asset,
            deltaMinor: paid,
          ),
        ];
      case TransactionType.transfer:
        final from = tx.accountId;
        final to = tx.toAccountId;
        if (from == null || to == null) {
          return const [];
        }
        final fromNature = nature(from) ?? AccountNature.asset;
        final toNature = nature(to) ?? AccountNature.asset;
        return [
          AccountPosting(
            accountId: from,
            nature: fromNature,
            deltaMinor: fromNature == AccountNature.asset
                ? -(paid + fee)
                : -(paid + fee),
          ),
          AccountPosting(
            accountId: to,
            nature: toNature,
            deltaMinor: toNature == AccountNature.asset ? paid : paid,
          ),
        ];
      case TransactionType.creditRepayment:
        final from = tx.accountId;
        final to = tx.toAccountId;
        if (from == null || to == null) {
          return const [];
        }
        return [
          AccountPosting(
            accountId: from,
            nature: nature(from) ?? AccountNature.asset,
            deltaMinor: -(paid + fee),
          ),
          AccountPosting(
            accountId: to,
            nature: nature(to) ?? AccountNature.liability,
            deltaMinor: -(paid + fee),
          ),
        ];
      case TransactionType.refund:
        final n = nature(tx.accountId);
        if (n == null) {
          return const [];
        }
        if (n == AccountNature.liability) {
          return [
            AccountPosting(
              accountId: tx.accountId!,
              nature: AccountNature.liability,
              deltaMinor: -paid,
            ),
          ];
        }
        return [
          AccountPosting(
            accountId: tx.accountId!,
            nature: AccountNature.asset,
            deltaMinor: paid,
          ),
        ];
    }
  }

  int assetBalanceMinor({
    required int initialBalanceMinor,
    required String accountId,
    required Iterable<WalletTransaction> transactions,
    required Map<String, AccountNature> natureByAccountId,
  }) {
    if (natureByAccountId[accountId] == AccountNature.liability) {
      throw ArgumentError('Use liabilitySnapshot for liability accounts');
    }
    var balance = initialBalanceMinor;
    for (final tx in _sorted(transactions)) {
      for (final p in postingsFor(tx, natureByAccountId)) {
        if (p.accountId == accountId && p.nature == AccountNature.asset) {
          balance += p.deltaMinor;
        }
      }
    }
    return balance;
  }

  LiabilitySnapshot liabilitySnapshot({
    required int initialBalanceMinor,
    required String accountId,
    required Iterable<WalletTransaction> transactions,
    required Map<String, AccountNature> natureByAccountId,
  }) {
    var position = initialBalanceMinor;
    for (final tx in _sorted(transactions)) {
      for (final p in postingsFor(tx, natureByAccountId)) {
        if (p.accountId == accountId &&
            p.nature == AccountNature.liability) {
          position += p.deltaMinor;
        }
      }
    }
    return LiabilitySnapshot(positionMinor: position);
  }

  /// Sum of refund amounts already recorded for [originalTransactionId].
  int refundedTotalMinor({
    required String originalTransactionId,
    required Iterable<WalletTransaction> transactions,
  }) {
    var sum = 0;
    for (final tx in transactions) {
      if (tx.isDeleted) {
        continue;
      }
      if (tx.type == TransactionType.refund &&
          tx.originalTransactionId == originalTransactionId) {
        sum += tx.amountMinor;
      }
    }
    return sum;
  }

  int refundableRemainingMinor({
    required WalletTransaction originalExpense,
    required Iterable<WalletTransaction> allTransactions,
  }) {
    if (originalExpense.type != TransactionType.expense) {
      return 0;
    }
    final already = refundedTotalMinor(
      originalTransactionId: originalExpense.id,
      transactions: allTransactions,
    );
    return originalExpense.amountMinor - already;
  }

  void assertRefundAllowed({
    required WalletTransaction originalExpense,
    required Iterable<WalletTransaction> allTransactions,
    required int refundAmountMinor,
  }) {
    if (refundAmountMinor <= 0) {
      throw AccountingRuleException('退款金额必须大于 0');
    }
    final remaining = refundableRemainingMinor(
      originalExpense: originalExpense,
      allTransactions: allTransactions,
    );
    if (refundAmountMinor > remaining) {
      throw AccountingRuleException('退款金额超过可退金额');
    }
  }

  StatisticalImpact statisticalImpactFor(
    WalletTransaction tx, {
    Set<String> reimbursementIncomeTransactionIds = const {},
  }) {
    if (tx.isDeleted) {
      return const StatisticalImpact();
    }
    final paid = TransactionMoney.paidMinor(tx);
    final fee = TransactionMoney.feeMinor(tx);
    final discount = TransactionMoney.discountMinor(tx);

    switch (tx.type) {
      case TransactionType.expense:
        return StatisticalImpact(
          expenseMinor: paid + fee,
          feeMinor: fee,
          discountMinor: discount,
        );
      case TransactionType.income:
        if (reimbursementIncomeTransactionIds.contains(tx.id)) {
          return StatisticalImpact(reimbursementIncomeMinor: paid);
        }
        return StatisticalImpact(incomeMinor: paid);
      case TransactionType.refund:
        return StatisticalImpact(refundOffsetMinor: paid);
      case TransactionType.transfer:
      case TransactionType.creditRepayment:
        return const StatisticalImpact();
    }
  }

  StatisticalImpact aggregateStatistics(
    Iterable<WalletTransaction> transactions, {
    Set<String> reimbursementIncomeTransactionIds = const {},
  }) {
    var total = const StatisticalImpact();
    for (final tx in transactions) {
      total += statisticalImpactFor(
        tx,
        reimbursementIncomeTransactionIds: reimbursementIncomeTransactionIds,
      );
    }
    return total;
  }

  int effectiveExpenseMinor({
    required WalletTransaction expense,
    required Iterable<WalletTransaction> allTransactions,
  }) {
    if (expense.type != TransactionType.expense || expense.isDeleted) {
      return 0;
    }
    final gross = TransactionMoney.cashOutflowMinor(expense);
    final refunded = refundedTotalMinor(
      originalTransactionId: expense.id,
      transactions: allTransactions,
    );
    return gross - refunded;
  }

  Iterable<WalletTransaction> _sorted(Iterable<WalletTransaction> txs) {
    final list = txs.toList()
      ..sort((a, b) {
        final c = a.occurredAt.compareTo(b.occurredAt);
        if (c != 0) {
          return c;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
    return list;
  }
}

class AccountingRuleException implements Exception {
  AccountingRuleException(this.message);
  final String message;

  @override
  String toString() => message;
}
