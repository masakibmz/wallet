import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/presentation/utils/formatters.dart';
import 'package:wallet/presentation/widgets/transaction/transaction_list_tile.dart';
import 'package:wallet/application/providers/summary_providers.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  static final _dayFormat = DateFormat('M月d日 EEEE', 'zh_CN');
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
    final incomeCategories = ref.watch(incomeCategoriesProvider(ledger.id));
    final accounts = ref.watch(accountsForLedgerProvider(ledger.id));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('账单'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.push('/add-transaction?type=expense'),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: txAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (transactions) {
            final reimbIds = ref
                .watch(reimbursementIncomeTransactionIdsProvider(ledger.id))
                .maybeWhen(data: (v) => v, orElse: () => const <String>{});
            final groups = ref
                .watch(transactionSummaryServiceProvider)
                .groupByDay(
                  transactions,
                  reimbursementIncomeTransactionIds: reimbIds,
                );
            final catMap = <String, String>{};
            categories.maybeWhen(
              data: (c) => catMap.addAll({for (final x in c) x.id: x.name}),
              orElse: () {},
            );
            incomeCategories.maybeWhen(
              data: (c) => catMap.addAll({for (final x in c) x.id: x.name}),
              orElse: () {},
            );
            final accMap = accounts.maybeWhen(
              data: (a) => {for (final x in a) x.id: x.name},
              orElse: () => <String, String>{},
            );

            if (groups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('还没有账单'),
                    CupertinoButton(
                      onPressed: () =>
                          context.push('/add-transaction?type=expense'),
                      child: const Text('记第一笔'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dayFormat.format(group.date),
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .navTitleTextStyle
                                  .copyWith(fontSize: 16),
                            ),
                          ),
                          Text(
                            '支 ${formatMinorAmount(group.expenseMinor, ledger.baseCurrencyCode)}'
                            ' · 收 ${formatMinorAmount(group.incomeMinor, ledger.baseCurrencyCode)}',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .tabLabelTextStyle,
                          ),
                        ],
                      ),
                    ),
                    CupertinoListSection.insetGrouped(
                      children: [
                        for (final tx in group.transactions)
                          _TransactionRow(
                            transaction: tx,
                            categoryName:
                                catMap[tx.subCategoryId ?? tx.categoryId],
                            accountName: accMap[tx.accountId],
                            onEdit: () =>
                                context.push('/transaction/${tx.id}/edit'),
                            onDelete: () => _confirmDelete(context, ref, tx.id),
                          ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除账单'),
        content: const Text('确定删除这条账单？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(transactionRepositoryProvider).softDelete(id);
    }
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    this.categoryName,
    this.accountName,
    required this.onEdit,
    required this.onDelete,
  });

  final WalletTransaction transaction;
  final String? categoryName;
  final String? accountName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () async {
        await showCupertinoModalPopup<void>(
          context: context,
          builder: (ctx) => CupertinoActionSheet(
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  onEdit();
                },
                child: const Text('编辑'),
              ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  onDelete();
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
      },
      child: TransactionListTile(
        transaction: transaction,
        categoryName: categoryName,
        accountName: accountName,
        onTap: onEdit,
      ),
    );
  }
}
