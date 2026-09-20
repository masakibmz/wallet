import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/domain/entities/category.dart';
import 'package:wallet/presentation/features/settings/add_sub_category_page.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/category_icons.dart';

class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});

  @override
  ConsumerState<CategoryManagePage> createState() =>
      _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  bool _isExpense = true;
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(currentLedgerProvider);
    if (ledger == null) {
      return const CupertinoPageScaffold(
        child: Center(child: Text('无账本')),
      );
    }

    final catsAsync = _isExpense
        ? ref.watch(expenseCategoriesProvider(ledger.id))
        : ref.watch(incomeCategoriesProvider(ledger.id));

    return CupertinoPageScaffold(
      backgroundColor: QianjiColors.pageBackground,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: _segmentedHeader(),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {},
          child: const Icon(CupertinoIcons.question_circle),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: catsAsync.when(
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (list) {
                  final tops = list.where((c) => c.isTopLevel).toList()
                    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: tops.length,
                    itemBuilder: (context, i) {
                      final top = tops[i];
                      final subs = list
                          .where((c) => c.parentId == top.id)
                          .toList()
                        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                      final expanded = _expanded.contains(top.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CategoryCard(
                          category: top,
                          subCategories: subs,
                          expanded: expanded,
                          onToggle: () {
                            setState(() {
                              if (expanded) {
                                _expanded.remove(top.id);
                              } else {
                                _expanded.add(top.id);
                              }
                            });
                          },
                          onAddSub: () => _openAddSub(
                            context,
                            ledger.id,
                            top,
                          ),
                          onMore: () => _categoryActions(context, top),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () => _addTopCategory(context, ledger.id),
                  child: const Text('+ 添加分类'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentedHeader() {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: QianjiColors.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _segTab('支出', true),
          _segTab('收入', false),
        ],
      ),
    );
  }

  Widget _segTab(String label, bool expense) {
    final selected = _isExpense == expense;
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 6),
        color: selected ? QianjiColors.cardBackground : null,
        borderRadius: BorderRadius.circular(6),
        onPressed: () => setState(() => _isExpense = expense),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: selected
                ? QianjiColors.textPrimary
                : QianjiColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _openAddSub(
    BuildContext context,
    String ledgerId,
    Category parent,
  ) async {
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => AddSubCategoryPage(
          ledgerId: ledgerId,
          parent: parent,
          isExpense: _isExpense,
        ),
      ),
    );
  }

  Future<void> _addTopCategory(BuildContext context, String ledgerId) async {
    final controller = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('添加分类'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '分类名称',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (ok != true) {
      controller.dispose();
      return;
    }
    final name = controller.text.trim();
    controller.dispose();
    if (name.isEmpty) {
      return;
    }
    try {
      await ref.read(categoryRepositoryProvider).createCategory(
            ledgerId: ledgerId,
            name: name,
            isExpense: _isExpense,
          );
    } catch (e) {
      if (context.mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _categoryActions(BuildContext context, Category c) async {
    if (!c.isDeletable) {
      return;
    }
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(categoryRepositoryProvider).deleteCategory(c.id);
              } catch (e) {
                if (context.mounted) {
                  await showCupertinoDialog<void>(
                    context: context,
                    builder: (d) => CupertinoAlertDialog(content: Text('$e')),
                  );
                }
              }
            },
            child: const Text('删除分类'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.subCategories,
    required this.expanded,
    required this.onToggle,
    required this.onAddSub,
    required this.onMore,
  });

  final Category category;
  final List<Category> subCategories;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAddSub;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onPressed: onToggle,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: QianjiColors.chipBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(categoryIconFor(category.name)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 16,
                      color: QianjiColors.textPrimary,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onMore,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: QianjiColors.tabActiveBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.ellipsis,
                      size: 16,
                      color: QianjiColors.fabBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded
                      ? CupertinoIcons.chevron_down
                      : CupertinoIcons.chevron_right,
                  size: 18,
                  color: QianjiColors.textSecondary,
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: QianjiColors.pageBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: QianjiColors.divider,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sub in subCategories)
                      ChipTag(label: sub.name),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      color: QianjiColors.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: onAddSub,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.add, size: 16),
                          SizedBox(width: 4),
                          Text('添加子类'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChipTag extends StatelessWidget {
  const ChipTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
