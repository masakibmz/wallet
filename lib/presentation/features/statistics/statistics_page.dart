import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/utils/formatters.dart';
import 'package:wallet/application/providers/summary_providers.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(currentLedgerProvider);
    if (ledger == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final txAsync = ref.watch(transactionsForLedgerProvider(ledger.id));
    final categories = ref.watch(expenseCategoriesProvider(ledger.id));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('统计'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => const _CalendarPage(),
            ),
          ),
          child: const Icon(CupertinoIcons.calendar),
        ),
      ),
      child: SafeArea(
        child: txAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (transactions) {
            final month = DateTime.now();
            final reimbIds = ref
                .watch(reimbursementIncomeTransactionIdsProvider(ledger.id))
                .maybeWhen(data: (v) => v, orElse: () => const <String>{});
            final summary = ref.watch(transactionSummaryServiceProvider).monthSummary(
                  transactions: transactions,
                  month: month,
                  reimbursementIncomeTransactionIds: reimbIds,
                );
            final catMap = categories.maybeWhen(
              data: (c) => {for (final x in c) x.id: x.name},
              orElse: () => <String, String>{},
            );
            final byCategory = <String, int>{};
            for (final tx in transactions) {
              if (tx.type != TransactionType.expense) {
                continue;
              }
              if (tx.occurredAt.year != month.year ||
                  tx.occurredAt.month != month.month) {
                continue;
              }
              final key = catMap[tx.subCategoryId ?? tx.categoryId] ?? '未分类';
              byCategory[key] = (byCategory[key] ?? 0) + tx.amountMinor;
            }
            final entries = byCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '本月支出 ${formatMinorAmount(summary.expenseMinor, ledger.baseCurrencyCode)}',
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: entries.isEmpty
                      ? const Center(child: Text('暂无支出数据'))
                      : PieChart(
                          PieChartData(
                            sections: [
                              for (var i = 0; i < entries.length && i < 6; i++)
                                PieChartSectionData(
                                  value: entries[i].value.toDouble(),
                                  title: entries[i].key,
                                  radius: 48,
                                ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      barGroups: [
                        BarChartGroupData(
                          x: 0,
                          barRods: [
                            BarChartRodData(
                              toY: summary.incomeMinor / 100.0,
                              color: CupertinoColors.systemGreen,
                            ),
                          ],
                        ),
                        BarChartGroupData(
                          x: 1,
                          barRods: [
                            BarChartRodData(
                              toY: summary.expenseMinor / 100.0,
                              color: CupertinoColors.systemRed,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CalendarPage extends ConsumerWidget {
  const _CalendarPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(currentLedgerProvider);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('日历')),
      child: SafeArea(
        child: ledger == null
            ? const Center(child: Text('无账本'))
            : Consumer(
                builder: (context, ref, _) {
                  final txAsync =
                      ref.watch(transactionsForLedgerProvider(ledger.id));
                  return txAsync.when(
                    data: (txs) {
                      final reimbIds = ref
                          .watch(
                            reimbursementIncomeTransactionIdsProvider(ledger.id),
                          )
                          .maybeWhen(data: (v) => v, orElse: () => const <String>{});
                      final groups = ref
                          .watch(transactionSummaryServiceProvider)
                          .groupByDay(
                            txs,
                            reimbursementIncomeTransactionIds: reimbIds,
                          );
                      return ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (_, i) {
                          final g = groups[i];
                          return CupertinoListTile(
                            title: Text('${g.date.month}/${g.date.day}'),
                            trailing: Text(
                              '支 ${g.expenseMinor} 收 ${g.incomeMinor}',
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CupertinoActivityIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                  );
                },
              ),
      ),
    );
  }
}
