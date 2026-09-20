import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/core/money/money_amount.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/formatters.dart';
import 'package:wallet/presentation/widgets/qianji/qianji_transaction_row.dart';
import 'package:wallet/services/transaction_search_service.dart';

class TransactionSearchPage extends ConsumerStatefulWidget {
  const TransactionSearchPage({super.key});

  @override
  ConsumerState<TransactionSearchPage> createState() =>
      _TransactionSearchPageState();
}

class _TransactionSearchPageState extends ConsumerState<TransactionSearchPage> {
  final _keyword = TextEditingController();
  static const _search = TransactionSearchService();

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(currentLedgerProvider);
    if (ledger == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final txAsync = ref.watch(transactionsForLedgerProvider(ledger.id));
    final expenseCats = ref.watch(expenseCategoriesProvider(ledger.id));
    final incomeCats = ref.watch(incomeCategoriesProvider(ledger.id));
    final accounts = ref.watch(accountsForLedgerProvider(ledger.id));
    final tags = ref.watch(tagsForLedgerProvider(ledger.id));

    return CupertinoPageScaffold(
      backgroundColor: QianjiColors.pageBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchHeader(onBack: () => context.pop()),
            _FilterChipRow(ledgerName: ledger.name),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: QianjiColors.chipBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.search,
                      size: 18,
                      color: QianjiColors.textSecondary,
                    ),
                    Expanded(
                      child: CupertinoTextField(
                        controller: _keyword,
                        placeholder: '输入关键字(分类、备注、金额、标签)',
                        decoration: null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {},
                      child: const Icon(
                        CupertinoIcons.slider_horizontal_3,
                        size: 20,
                        color: QianjiColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: txAsync.when(
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (transactions) {
                  final catMap = <String, String>{};
                  expenseCats.maybeWhen(
                    data: (c) => catMap.addAll({for (final x in c) x.id: x.name}),
                    orElse: () {},
                  );
                  incomeCats.maybeWhen(
                    data: (c) => catMap.addAll({for (final x in c) x.id: x.name}),
                    orElse: () {},
                  );
                  final accMap = accounts.maybeWhen(
                    data: (a) => {for (final x in a) x.id: x.name},
                    orElse: () => <String, String>{},
                  );
                  final tagMap = tags.maybeWhen(
                    data: (t) => {for (final x in t) x.id: x.name},
                    orElse: () => <String, String>{},
                  );

                  final base = _search.filter(
                    transactions,
                    const TransactionSearchQuery(),
                  );
                  final results = _filterByKeyword(
                    base,
                    _keyword.text,
                    catMap: catMap,
                    tagMap: tagMap,
                    currency: ledger.baseCurrencyCode,
                  );
                  results.sort(
                    (a, b) => b.occurredAt.compareTo(a.occurredAt),
                  );

                  final summary = _SearchSummary.from(results);
                  final groups = _groupByMonth(results);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _SummaryCard(
                        summary: summary,
                        count: results.length,
                        currency: ledger.baseCurrencyCode,
                      ),
                      for (final group in groups) ...[
                        _MonthHeader(
                          month: group.month,
                          incomeMinor: group.incomeMinor,
                          expenseMinor: group.expenseMinor,
                          currency: ledger.baseCurrencyCode,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: QianjiColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < group.items.length; i++) ...[
                                if (i > 0)
                                  Container(
                                    height: 0.5,
                                    margin: const EdgeInsets.only(left: 72),
                                    color: QianjiColors.divider,
                                  ),
                                QianjiTransactionRow(
                                  transaction: group.items[i],
                                  categoryName: formatCategoryListLabel(
                                    group.items[i],
                                    catMap,
                                  ),
                                  accountName: accMap[group.items[i].accountId],
                                  detailLine: DateFormat('yyyy-MM-dd').format(
                                    group.items[i].occurredAt.toLocal(),
                                  ),
                                  onTap: () => context.push(
                                    '/transaction/${group.items[i].id}/edit',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (results.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              '无匹配账单',
                              style: TextStyle(
                                color: QianjiColors.textSecondary,
                              ),
                            ),
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

  List<WalletTransaction> _filterByKeyword(
    List<WalletTransaction> source,
    String raw, {
    required Map<String, String> catMap,
    required Map<String, String> tagMap,
    required String currency,
  }) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return source;
    }
    return source.where((tx) {
      if (tx.note?.toLowerCase().contains(q) ?? false) {
        return true;
      }
      final cat = formatCategoryListLabel(tx, catMap).toLowerCase();
      if (cat.contains(q)) {
        return true;
      }
      final amount = formatMinorAmount(tx.amountMinor, tx.currencyCode);
      if (amount.toLowerCase().contains(q) || amount.replaceAll('¥', '').contains(q)) {
        return true;
      }
      for (final tagId in tx.tagIds) {
        final name = tagMap[tagId]?.toLowerCase() ?? '';
        if (name.contains(q)) {
          return true;
        }
      }
      return false;
    }).toList(growable: false);
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: onBack,
            child: const Icon(CupertinoIcons.back),
          ),
          const Expanded(
            child: Text(
              '搜索账单',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.ledgerName});

  final String ledgerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _chip('全部'),
          const SizedBox(width: 8),
          _chip('筛选'),
          const SizedBox(width: 8),
          Expanded(child: _chip(ledgerName)),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            CupertinoIcons.chevron_down,
            size: 12,
            color: QianjiColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _SearchSummary {
  const _SearchSummary({
    required this.expenseMinor,
    required this.incomeMinor,
    required this.transferMinor,
    required this.refundMinor,
    required this.couponMinor,
  });

  final int expenseMinor;
  final int incomeMinor;
  final int transferMinor;
  final int refundMinor;
  final int couponMinor;

  int get balanceMinor => incomeMinor - expenseMinor;

  static _SearchSummary from(List<WalletTransaction> txs) {
    var expense = 0;
    var income = 0;
    var transfer = 0;
    var refund = 0;
    var coupon = 0;
    for (final tx in txs) {
      switch (tx.type) {
        case TransactionType.expense:
          expense += tx.amountMinor + tx.feeMinor;
          coupon += tx.couponMinor;
        case TransactionType.income:
          income += tx.amountMinor;
        case TransactionType.transfer:
        case TransactionType.creditRepayment:
          transfer += tx.amountMinor;
        case TransactionType.refund:
          refund += tx.amountMinor;
      }
    }
    return _SearchSummary(
      expenseMinor: expense,
      incomeMinor: income,
      transferMinor: transfer,
      refundMinor: refund,
      couponMinor: coupon,
    );
  }

  String fmt(int minor, String currency) {
    return MoneyAmount(minorUnits: minor, currencyCode: currency).format();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.count,
    required this.currency,
  });

  final _SearchSummary summary;
  final int count;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '搜索汇总',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '共$count笔',
                style: const TextStyle(
                  fontSize: 13,
                  color: QianjiColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.arrow_up_arrow_down,
                size: 16,
                color: QianjiColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryCell('支出', summary.fmt(summary.expenseMinor, currency)),
              ),
              Expanded(
                child: _summaryCell('收入', summary.fmt(summary.incomeMinor, currency)),
              ),
              Expanded(
                child: _summaryCell('结余', summary.fmt(summary.balanceMinor, currency)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryCell(
                  '转账/还款',
                  summary.fmt(summary.transferMinor, currency),
                ),
              ),
              Expanded(
                child: _summaryCell(
                  '退款',
                  summary.fmt(summary.refundMinor, currency),
                ),
              ),
              Expanded(
                child: _summaryCell(
                  '优惠券',
                  summary.fmt(summary.couponMinor, currency),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCell(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: QianjiColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MonthGroup {
  _MonthGroup({
    required this.month,
    required this.items,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime month;
  final List<WalletTransaction> items;
  final int incomeMinor;
  final int expenseMinor;
}

List<_MonthGroup> _groupByMonth(List<WalletTransaction> txs) {
  final map = <String, List<WalletTransaction>>{};
  for (final tx in txs) {
    final local = tx.occurredAt.toLocal();
    final key = '${local.year}-${local.month}';
    map.putIfAbsent(key, () => []).add(tx);
  }
  final keys = map.keys.toList()
    ..sort((a, b) => b.compareTo(a));
  return [
    for (final key in keys)
      () {
        final parts = key.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final items = map[key]!;
        var income = 0;
        var expense = 0;
        for (final tx in items) {
          if (tx.type == TransactionType.income) {
            income += tx.amountMinor;
          } else if (tx.type == TransactionType.expense) {
            expense += tx.amountMinor + tx.feeMinor;
          }
        }
        return _MonthGroup(
          month: DateTime(year, month),
          items: items,
          incomeMinor: income,
          expenseMinor: expense,
        );
      }(),
  ];
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.currency,
  });

  final DateTime month;
  final int incomeMinor;
  final int expenseMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('yyyy年M月').format(month);
    final parts = <String>[];
    if (incomeMinor > 0) {
      parts.add('收:${formatMinorAmount(incomeMinor, currency)}');
    }
    if (expenseMinor > 0) {
      parts.add('支:${formatMinorAmount(expenseMinor, currency)}');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Text(
            label,
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
