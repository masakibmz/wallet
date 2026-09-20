import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/domain/entities/category.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/category_icons.dart';

class AddSubCategoryPage extends ConsumerStatefulWidget {
  const AddSubCategoryPage({
    super.key,
    required this.ledgerId,
    required this.parent,
    required this.isExpense,
  });

  final String ledgerId;
  final Category parent;
  final bool isExpense;

  @override
  ConsumerState<AddSubCategoryPage> createState() =>
      _AddSubCategoryPageState();
}

class _AddSubCategoryPageState extends ConsumerState<AddSubCategoryPage> {
  final _nameController = TextEditingController();
  late String _iconName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _iconName = widget.parent.iconName ?? _iconChoices.first.$1;
  }

  static const _iconChoices = [
    ('餐饮', '餐饮'),
    ('交通', '交通'),
    ('购物', '购物'),
    ('娱乐', '娱乐'),
    ('医疗', '医疗'),
    ('工资', '工资'),
    ('奖金', '奖金'),
    ('理财', '理财'),
    ('其它', '其它'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await _alert('请输入分类名称');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(categoryRepositoryProvider).createCategory(
            ledgerId: widget.ledgerId,
            name: name,
            isExpense: widget.isExpense,
            parentId: widget.parent.id,
            iconName: _iconName,
          );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      await _alert('$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _alert(String msg) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: QianjiColors.pageBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('添加二级分类'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.checkmark),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('一级分类'),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: QianjiColors.chipBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              categoryIconFor(widget.parent.name),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(widget.parent.name),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Text('二级分类名称'),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _nameController,
                          placeholder: '请输入分类名称',
                          decoration: null,
                          textAlign: TextAlign.right,
                          padding: const EdgeInsets.only(left: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '分类图标',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            _card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _iconChoices.length,
                  itemBuilder: (context, i) {
                    final (key, label) = _iconChoices[i];
                    final selected = _iconName == key;
                    final accent = widget.isExpense
                        ? QianjiColors.expense
                        : QianjiColors.income;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _iconName = key),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: selected
                                  ? accent
                                  : QianjiColors.chipBackground,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              categoryIconFor(label),
                              color: selected
                                  ? CupertinoColors.white
                                  : QianjiColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? accent
                                  : QianjiColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({List<Widget>? children, Widget? child}) {
    return Container(
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child ?? Column(children: children!),
    );
  }

  Widget _divider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 16),
      color: QianjiColors.divider,
    );
  }
}
