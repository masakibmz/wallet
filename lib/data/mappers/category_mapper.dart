import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/domain/entities/category.dart';

class CategoryMapper {
  static Category fromRow(CategoryRow row) {
    return Category(
      id: row.id,
      ledgerId: row.ledgerId,
      groupId: row.groupId,
      parentId: row.parentId,
      name: row.name,
      iconName: row.iconName,
      isExpense: row.isExpense,
      isSystem: row.isSystem,
      isDeletable: row.isDeletable,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  static List<Category> fromRows(List<CategoryRow> rows) =>
      rows.map(fromRow).toList(growable: false);
}
