import 'package:flutter/cupertino.dart';
import 'package:wallet/domain/entities/category.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/category_icons.dart';

class CategoryIconGrid extends StatelessWidget {
  const CategoryIconGrid({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.accentColor,
    required this.onSelect,
  });

  final List<Category> categories;
  final String? selectedId;
  final Color accentColor;
  final ValueChanged<Category> onSelect;

  @override
  Widget build(BuildContext context) {
    final tops = categories.where((c) => c.isTopLevel).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: tops.length,
      itemBuilder: (context, i) {
        final c = tops[i];
        final selected = c.id == selectedId;
        final hasChild = categories.any((x) => x.parentId == c.id);
        return GestureDetector(
          onTap: () => onSelect(c),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? accentColor : QianjiColors.chipBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      categoryIconFor(c.name, iconName: c.iconName),
                      color: selected
                          ? CupertinoColors.white
                          : QianjiColors.textSecondary,
                      size: 24,
                    ),
                  ),
                  if (hasChild)
                    const Positioned(
                      right: -2,
                      bottom: -2,
                      child: Icon(
                        CupertinoIcons.ellipsis,
                        size: 14,
                        color: QianjiColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? accentColor : QianjiColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
