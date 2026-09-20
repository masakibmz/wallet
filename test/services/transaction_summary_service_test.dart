import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/transaction_summary_service.dart';

void main() {
  const service = TransactionSummaryService();
  final now = DateTime(2026, 3, 20, 18, 0);

  WalletTransaction tx(TransactionType type, int amount, {DateTime? at}) {
    final t = at ?? now;
    return WalletTransaction(
      id: '$type-$amount-${t.day}',
      ledgerId: 'l1',
      type: type,
      amountMinor: amount,
      currencyCode: 'CNY',
      occurredAt: t,
      createdAt: t,
      updatedAt: t,
    );
  }

  test('monthSummary sums income and expense only', () {
    final summary = service.monthSummary(
      month: DateTime(2026, 3),
      transactions: [
        tx(TransactionType.income, 10000),
        tx(TransactionType.expense, 3200, at: DateTime(2026, 3, 19)),
        tx(TransactionType.transfer, 5000),
        tx(TransactionType.expense, 1000, at: DateTime(2026, 2, 28)),
      ],
    );
    expect(summary.incomeMinor, 10000);
    expect(summary.expenseMinor, 3200);
    expect(summary.balanceMinor, 6800);
  });

  test('groupByDay orders descending with daily totals', () {
    final groups = service.groupByDay([
      tx(TransactionType.expense, 100, at: DateTime(2026, 3, 18)),
      tx(TransactionType.income, 200, at: DateTime(2026, 3, 20)),
      tx(TransactionType.expense, 50, at: DateTime(2026, 3, 20, 12)),
    ]);
    expect(groups.length, 2);
    expect(groups.first.date.day, 20);
    expect(groups.first.incomeMinor, 200);
    expect(groups.first.expenseMinor, 50);
  });
}
