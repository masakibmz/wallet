import 'package:flutter/cupertino.dart';
import 'package:wallet/domain/entities/category.dart';

class CategorySelection {
  const CategorySelection({required this.categoryId, this.subCategoryId});

  final String categoryId;
  final String? subCategoryId;
}

Future<CategorySelection?> showCategoryPickerSheet({
  required BuildContext context,
  required List<Category> categories,
  String? selectedTopId,
  String? selectedSubId,
}) {
  return showCupertinoModalPopup<CategorySelection>(
    context: context,
    builder: (ctx) => _CategorySheet(
      categories: categories,
      selectedTopId: selectedTopId,
      selectedSubId: selectedSubId,
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.categories,
    this.selectedTopId,
    this.selectedSubId,
  });

  final List<Category> categories;
  final String? selectedTopId;
  final String? selectedSubId;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late String? _topId;
  late String? _subId;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _topId = widget.selectedTopId;
    _subId = widget.selectedSubId;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final tops = widget.categories.where((c) => c.isTopLevel).toList();
    final filteredTops = q.isEmpty
        ? tops
        : widget.categories
            .where((c) => c.name.toLowerCase().contains(q))
            .toList();
    final subs = _topId == null
        ? <Category>[]
        : widget.categories.where((c) => c.parentId == _topId).toList();

    final height = MediaQuery.sizeOf(context).height * 0.65;
    return Container(
      height: height,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: CupertinoSearchTextField(
              controller: _search,
              placeholder: '搜索分类',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text('一级分类'),
                  children: [
                    for (final c in (q.isEmpty ? tops : filteredTops))
                      CupertinoListTile(
                        title: Text(c.name),
                        trailing: _topId == c.id
                            ? const Icon(CupertinoIcons.check_mark, size: 18)
                            : null,
                        onTap: () => setState(() {
                          _topId = c.id;
                          _subId = null;
                        }),
                      ),
                  ],
                ),
                if (subs.isNotEmpty)
                  CupertinoListSection.insetGrouped(
                    header: const Text('二级分类'),
                    children: [
                      for (final c in subs)
                        CupertinoListTile(
                          title: Text(c.name),
                          trailing: _subId == c.id
                              ? const Icon(CupertinoIcons.check_mark, size: 18)
                              : null,
                          onTap: () => setState(() => _subId = c.id),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _topId == null
                      ? null
                      : () => Navigator.pop(
                            context,
                            CategorySelection(
                              categoryId: _topId!,
                              subCategoryId: _subId,
                            ),
                          ),
                  child: const Text('确定'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
