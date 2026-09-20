import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/home_chart_preferences_provider.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/application/providers/summary_providers.dart';
import 'package:wallet/presentation/features/home/home_weekly_chart_settings_sheet.dart';
import 'package:wallet/presentation/features/home/transaction_detail_sheet.dart';
import 'package:wallet/presentation/widgets/qianji/qianji_slidable_transaction_row.dart';
import 'package:wallet/services/app_preferences_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/formatters.dart';
import 'package:wallet/services/transaction_summary_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final ledger = ref.watch(currentLedgerProvider);

    return bootstrap.when(
      loading: () => const CupertinoPageScaffold(
        backgroundColor: QianjiColors.pageBackground,
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (e, _) => CupertinoPageScaffold(
        backgroundColor: QianjiColors.pageBackground,
        child: Center(child: Text('初始化失败：$e')),
      ),
      data: (_) {
        if (ledger == null) {
          return const CupertinoPageScaffold(
            backgroundColor: QianjiColors.pageBackground,
            child: Center(child: Text('暂无账本')),
          );
        }

        final txAsync = ref.watch(transactionsForLedgerProvider(ledger.id));
        final categories = ref.watch(expenseCategoriesProvider(ledger.id));
        final accounts = ref.watch(accountsForLedgerProvider(ledger.id));

        return CupertinoPageScaffold(
          backgroundColor: QianjiColors.pageBackground,
          child: txAsync.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (transactions) {
              final reimbIds = ref
                  .watch(reimbursementIncomeTransactionIdsProvider(ledger.id))
                  .maybeWhen(data: (v) => v, orElse: () => const <String>{});
              final summary = ref
                  .watch(transactionSummaryServiceProvider)
                  .monthSummary(
                    transactions: transactions,
                    month: _month,
                    reimbursementIncomeTransactionIds: reimbIds,
                  );
              final catMap = categories.maybeWhen(
                data: (c) => {for (final x in c) x.id: x.name},
                orElse: () => <String, String>{},
              );
              final accMap = accounts.maybeWhen(
                data: (a) => {for (final x in a) x.id: x.name},
                orElse: () => <String, String>{},
              );
              final groups = ref
                  .watch(transactionSummaryServiceProvider)
                  .groupByDay(
                    transactions,
                    reimbursementIncomeTransactionIds: reimbIds,
                  );

              return SlidableAutoCloseBehavior(
                child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Header(month: _month, onMonthTap: () {})),
                  SliverToBoxAdapter(
                    child: _HeroCard(
                      ledgerName: ledger.name,
                      balanceMinor: summary.balanceMinor,
                      incomeMinor: summary.incomeMinor,
                      expenseMinor: summary.expenseMinor,
                      currency: ledger.baseCurrencyCode,
                    ),
                  ),
                  const SliverToBoxAdapter(child: _BudgetCard()),
                  SliverToBoxAdapter(
                    child: _WeeklyChartSection(
                      transactions: transactions,
                      currency: ledger.baseCurrencyCode,
                      reimbursementIncomeIds: reimbIds,
                    ),
                  ),
                  for (final day in groups.take(14)) ...[
                    SliverToBoxAdapter(
                      child: _DayHeader(
                        date: day.date,
                        daySummary: day,
                        currency: ledger.baseCurrencyCode,
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final tx = day.transactions[i];
                          final categoryName =
                              formatCategoryListLabel(tx, catMap);
                          final accountName = accMap[tx.accountId];
                          return QianjiSlidableTransactionRow(
                            transaction: tx,
                            categoryName: categoryName,
                            accountName: accountName,
                            onTap: () => _showTransactionDetail(
                              context,
                              ref,
                              tx,
                              categoryName: categoryName,
                              accountName: accountName,
                            ),
                            onRefund: tx.type == TransactionType.expense
                                ? () => context.push('/refund/${tx.id}')
                                : null,
                            onEdit: () =>
                                context.push('/transaction/${tx.id}/edit'),
                            onDelete: () => _confirmDeleteTransaction(
                              context,
                              ref,
                              tx,
                            ),
                          );
                        },
                        childCount: day.transactions.length,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
              );
            },
          ),
        );
      },
    );
  }
}

Future<void> _showTransactionDetail(
  BuildContext context,
  WidgetRef ref,
  WalletTransaction tx, {
  required String? categoryName,
  required String? accountName,
}) {
  return showTransactionDetailSheet(
    context,
    transaction: tx,
    categoryName: categoryName,
    accountName: accountName,
    onCopy: () => context.push('/add-transaction?copyFrom=${tx.id}'),
    onRefund: tx.type == TransactionType.expense
        ? () => context.push('/refund/${tx.id}')
        : null,
    onEdit: () => context.push('/transaction/${tx.id}/edit'),
    onDelete: () => _confirmDeleteTransaction(context, ref, tx),
  );
}

Future<void> _confirmDeleteTransaction(
  BuildContext context,
  WidgetRef ref,
  WalletTransaction tx,
) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('删除账单'),
      message: const Text('删除后余额与统计将恢复'),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () async {
            Navigator.pop(ctx);
            await ref.read(transactionRecordingServiceProvider).delete(tx.id);
          },
          child: const Text('删除'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('取消'),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.month, required this.onMonthTap});

  final DateTime month;
  final VoidCallback onMonthTap;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('yyyy年M月').format(month);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: QianjiColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              onPressed: onMonthTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: QianjiColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    size: 14,
                    color: QianjiColors.textSecondary,
                  ),
                ],
              ),
            ),
            const Spacer(),
            _HeaderIcon(
              icon: CupertinoIcons.search,
              onTap: () => context.push('/search'),
            ),
            _HeaderIcon(
              icon: CupertinoIcons.calendar,
              onTap: () => context.push('/statistics'),
            ),
            _HeaderIcon(
              icon: CupertinoIcons.chart_bar,
              onTap: () => context.push('/statistics'),
            ),
            _HeaderIcon(
              icon: CupertinoIcons.person,
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.all(8),
      onPressed: onTap,
      child: Icon(icon, color: QianjiColors.textPrimary, size: 22),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.ledgerName,
    required this.balanceMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.currency,
  });

  final String ledgerName;
  final int balanceMinor;
  final int incomeMinor;
  final int expenseMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 160,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6B8DD6),
                Color(0xFF8E54E9),
                Color(0xFFE78B5A),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '月结余',
                          style: TextStyle(color: CupertinoColors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatMinorAmount(balanceMinor, currency),
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ledgerName,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 13,
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 12,
                          color: CupertinoColors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    '月收入: ${formatMinorAmount(incomeMinor, currency)}',
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '月支出: ${formatMinorAmount(expenseMinor, currency)}',
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QianjiColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '月预算',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: QianjiColors.textPrimary,
                  ),
                ),
                Icon(CupertinoIcons.ellipsis, color: QianjiColors.textSecondary),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: QianjiColors.chipBackground,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('未设置', style: TextStyle(color: QianjiColors.textSecondary)),
                Text('未设置', style: TextStyle(color: QianjiColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyChartSection extends ConsumerWidget {
  const _WeeklyChartSection({
    required this.transactions,
    required this.currency,
    required this.reimbursementIncomeIds,
  });

  final List<WalletTransaction> transactions;
  final String currency;
  final Set<String> reimbursementIncomeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(homeWeeklyChartPrefsProvider);
    if (prefs.range == HomeChartRange.hidden) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final days = prefs.range == HomeChartRange.thisWeek
        ? _weekDays(now)
        : _last7Days(now);
    final incomeAmounts = <int>[];
    final expenseAmounts = <int>[];
    var totalIncome = 0;
    var totalExpense = 0;

    for (final d in days) {
      var income = 0;
      var expense = 0;
      for (final tx in transactions) {
        final t = tx.occurredAt.toLocal();
        if (t.year != d.year || t.month != d.month || t.day != d.day) {
          continue;
        }
        if (tx.type == TransactionType.income ||
            reimbursementIncomeIds.contains(tx.id)) {
          income += tx.amountMinor;
        } else if (tx.type == TransactionType.expense) {
          expense += tx.amountMinor + tx.feeMinor;
        }
      }
      incomeAmounts.add(income);
      expenseAmounts.add(expense);
      totalIncome += income;
      totalExpense += expense;
    }

    final maxVal = [
      ...incomeAmounts,
      ...expenseAmounts,
      if (prefs.dataType == HomeChartDataType.balance)
        ...List.generate(days.length, (i) => incomeAmounts[i] - expenseAmounts[i]).map((v) => v.abs()),
    ].fold<int>(0, (a, b) => a > b ? a : b);
    final max = maxVal < 1 ? 1 : maxVal;

    final title = prefs.range == HomeChartRange.thisWeek ? '本周收支' : '最近七日收支';
    final subtitle = switch (prefs.dataType) {
      HomeChartDataType.expense =>
        '共计 ${formatMinorAmount(totalExpense, currency)}',
      HomeChartDataType.income =>
        '共计 ${formatMinorAmount(totalIncome, currency)}',
      HomeChartDataType.balance =>
        '共计 ${formatMinorAmount(totalIncome - totalExpense, currency)}',
      HomeChartDataType.expenseAndIncome =>
        '共计 收入 ${formatMinorAmount(totalIncome, currency)}，支出 ${formatMinorAmount(totalExpense, currency)}',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QianjiColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () async {
                    final next = await showHomeWeeklyChartSettingsSheet(
                      context,
                      initial: prefs,
                    );
                    if (next != null) {
                      await persistHomeWeeklyChartPrefs(ref, next);
                    }
                  },
                  child: const Icon(
                    CupertinoIcons.ellipsis,
                    color: QianjiColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: QianjiColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 148,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const axisLabelHeight = 16.0;
                  const axisGap = 4.0;
                  final plotMaxHeight =
                      constraints.maxHeight - axisLabelHeight - axisGap;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < days.length; i++)
                        Expanded(
                          child: _DayBars(
                            label: _dayLabel(days[i], prefs.range, i),
                            incomeMinor: incomeAmounts[i],
                            expenseMinor: expenseAmounts[i],
                            dataType: prefs.dataType,
                            maxMinor: max,
                            plotMaxHeight: plotMaxHeight,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DateTime> _weekDays(DateTime now) {
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(
      7,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );
  }

  List<DateTime> _last7Days(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );
  }

  String _dayLabel(DateTime d, HomeChartRange range, int index) {
    if (range == HomeChartRange.thisWeek) {
      const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return labels[index];
    }
    return DateFormat('M/d').format(d);
  }
}

class _DayBars extends StatelessWidget {
  const _DayBars({
    required this.label,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.dataType,
    required this.maxMinor,
    required this.plotMaxHeight,
  });

  final String label;
  final int incomeMinor;
  final int expenseMinor;
  final HomeChartDataType dataType;
  final int maxMinor;
  final double plotMaxHeight;

  static const _valueFontSize = 10.0;
  static const _valueLineHeight = 16.0;
  static const _valueGap = 2.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: plotMaxHeight,
              width: cellWidth,
              child: _buildBarCluster(cellWidth),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: QianjiColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBarCluster(double cellWidth) {
    if (dataType == HomeChartDataType.expenseAndIncome) {
      return _buildDualBars(cellWidth);
    }
    final amount = _primaryAmount.abs();
    return _labeledBar(
      amount,
      _primaryColor,
      barWidth: 20,
      cellWidth: cellWidth,
    );
  }

  Widget _buildDualBars(double cellWidth) {
    final maxBarHeight = plotMaxHeight - _valueLineHeight - _valueGap;
    final expenseBarHeight = expenseMinor <= 0 || maxMinor <= 0
        ? 0.0
        : maxBarHeight * expenseMinor / maxMinor;
    final incomeBarHeight = incomeMinor <= 0 || maxMinor <= 0
        ? 0.0
        : maxBarHeight * incomeMinor / maxMinor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: _valueLineHeight,
          width: cellWidth,
          child: Row(
            children: [
              Expanded(
                child: _chartValueText(expenseMinor, QianjiColors.expense),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _chartValueText(incomeMinor, QianjiColors.income),
              ),
            ],
          ),
        ),
        const SizedBox(height: _valueGap),
        SizedBox(
          height: maxBarHeight,
          width: cellWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _barShape(expenseBarHeight, QianjiColors.expense, 10),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _barShape(incomeBarHeight, QianjiColors.income, 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chartValueText(int minor, Color color) {
    if (minor <= 0) {
      return const SizedBox.shrink();
    }
    return Text(
      _chartAmountLabel(minor),
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: _valueFontSize,
        height: 1.2,
        color: color,
      ),
    );
  }

  Widget _barShape(double height, Color color, double width) {
    if (height <= 0) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _labeledBar(
    int minor,
    Color color, {
    required double barWidth,
    required double cellWidth,
  }) {
    final maxBarHeight = plotMaxHeight - _valueLineHeight - _valueGap;
    final barHeight =
        minor <= 0 || maxMinor <= 0 ? 0.0 : maxBarHeight * minor / maxMinor;

    return SizedBox(
      width: cellWidth,
      height: plotMaxHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (minor > 0)
            SizedBox(
              width: cellWidth,
              height: _valueLineHeight,
              child: _chartValueText(minor, color),
            ),
          if (minor > 0) const SizedBox(height: _valueGap),
          if (barHeight > 0)
            _barShape(barHeight, color, barWidth),
        ],
      ),
    );
  }

  int get _primaryAmount {
    return switch (dataType) {
      HomeChartDataType.income => incomeMinor,
      HomeChartDataType.expense => expenseMinor,
      HomeChartDataType.balance => incomeMinor - expenseMinor,
      HomeChartDataType.expenseAndIncome => 0,
    };
  }

  Color get _primaryColor {
    return switch (dataType) {
      HomeChartDataType.income => QianjiColors.income,
      HomeChartDataType.expense => QianjiColors.expense,
      HomeChartDataType.balance =>
        _primaryAmount >= 0 ? QianjiColors.income : QianjiColors.expense,
      HomeChartDataType.expenseAndIncome => QianjiColors.textSecondary,
    };
  }

  String _chartAmountLabel(int minor) {
    final major = minor / 100;
    if (major >= 1000) {
      final k = major / 1000;
      if (k >= 100) {
        return '${k.toStringAsFixed(0)}K';
      }
      if (k >= 10) {
        return '${k.toStringAsFixed(1)}K';
      }
      return '${k.toStringAsFixed(2)}K';
    }
    if (major >= 100) {
      return major.toStringAsFixed(1);
    }
    return major.toStringAsFixed(2);
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.daySummary,
    required this.currency,
  });

  final DateTime date;
  final DaySummary daySummary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final isYesterday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;
    final md = DateFormat('MM.dd').format(date);
    final suffix = isToday
        ? ' 今天'
        : isYesterday
            ? ' 昨天'
            : '';
    final parts = <String>[];
    if (daySummary.incomeMinor > 0) {
      parts.add('收:${formatMinorAmount(daySummary.incomeMinor, currency)}');
    }
    if (daySummary.expenseMinor > 0) {
      parts.add('支:${formatMinorAmount(daySummary.expenseMinor, currency)}');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            '$md$suffix',
            style: const TextStyle(
              fontSize: 14,
              color: QianjiColors.textSecondary,
            ),
          ),
          const Spacer(),
          if (parts.isNotEmpty)
            Text(
              parts.join(' '),
              style: const TextStyle(
                fontSize: 13,
                color: QianjiColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
