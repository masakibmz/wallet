import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/services/accounting/accounting_service.dart';

class MonthSummary {
  const MonthSummary({
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final int incomeMinor;
  final int expenseMinor;

  int get balanceMinor => incomeMinor - expenseMinor;
}

class DaySummary {
  const DaySummary({
    required this.date,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.transactions,
  });

  final DateTime date;
  final int incomeMinor;
  final int expenseMinor;
  final List<WalletTransaction> transactions;

  int get balanceMinor => incomeMinor - expenseMinor;
}

class TransactionSummaryService {
  const TransactionSummaryService([
    this._accounting = const AccountingService(),
  ]);

  final AccountingService _accounting;

  MonthSummary monthSummary({
    required List<WalletTransaction> transactions,
    required DateTime month,
    Set<String> reimbursementIncomeTransactionIds = const {},
  }) {
    var income = 0;
    var expense = 0;
    for (final tx in transactions) {
      if (!_inMonth(tx.occurredAt, month)) {
        continue;
      }
      final impact = _accounting.statisticalImpactFor(
        tx,
        reimbursementIncomeTransactionIds: reimbursementIncomeTransactionIds,
      );
      income += impact.netIncomeMinor;
      expense += impact.netExpenseMinor;
    }
    return MonthSummary(incomeMinor: income, expenseMinor: expense);
  }

  List<DaySummary> groupByDay(
    List<WalletTransaction> transactions, {
    Set<String> reimbursementIncomeTransactionIds = const {},
  }) {
    final map = <DateTime, List<WalletTransaction>>{};
    for (final tx in transactions) {
      final day = DateTime(
        tx.occurredAt.year,
        tx.occurredAt.month,
        tx.occurredAt.day,
      );
      map.putIfAbsent(day, () => []).add(tx);
    }
    final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return days.map((day) {
      final list = map[day]!..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      var income = 0;
      var expense = 0;
      for (final tx in list) {
        final impact = _accounting.statisticalImpactFor(
          tx,
          reimbursementIncomeTransactionIds: reimbursementIncomeTransactionIds,
        );
        income += impact.netIncomeMinor;
        expense += impact.netExpenseMinor;
      }
      return DaySummary(
        date: day,
        incomeMinor: income,
        expenseMinor: expense,
        transactions: list,
      );
    }).toList(growable: false);
  }

  bool _inMonth(DateTime time, DateTime month) {
    return time.year == month.year && time.month == month.month;
  }
}
