import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/core/constants/default_categories.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/mappers/category_mapper.dart';
import 'package:wallet/data/repositories/local/local_repository.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/entities/category.dart';

abstract class CategoryRepository {
  Stream<List<Category>> watchActiveCategories(
    String ledgerId, {
    bool? isExpense,
  });

  Future<List<Category>> getActiveCategories(
    String ledgerId, {
    bool? isExpense,
  });

  Future<Category?> getById(String id);

  Future<Category> createCategory({
    required String ledgerId,
    required String name,
    required bool isExpense,
    String? parentId,
    String? iconName,
  });

  Future<Category> updateCategory({
    required String id,
    String? name,
    String? iconName,
    int? sortOrder,
  });

  Future<void> updateSortOrders(Map<String, int> idToSortOrder);

  Future<void> deleteCategory(String id);

  Future<Category> getFallbackCategory({
    required String ledgerId,
    required bool isExpense,
  });
}

class CategoryLocalRepository extends LocalRepository
    implements CategoryRepository {
  CategoryLocalRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Stream<List<Category>> watchActiveCategories(
    String ledgerId, {
    bool? isExpense,
  }) {
    return _baseQuery(ledgerId, isExpense: isExpense).watch().map(
          (List<CategoryRow> rows) => CategoryMapper.fromRows(rows),
        );
  }

  @override
  Future<List<Category>> getActiveCategories(
    String ledgerId, {
    bool? isExpense,
  }) async {
    return CategoryMapper.fromRows(
      await _baseQuery(ledgerId, isExpense: isExpense).get(),
    );
  }

  SimpleSelectStatement<$CategoriesTable, CategoryRow> _baseQuery(
    String ledgerId, {
    bool? isExpense,
  }) {
    final query = _db.select(_db.categories)
      ..where(
        (t) {
          Expression<bool> expr =
              t.ledgerId.equals(ledgerId) & t.deletedAt.isNull();
          if (isExpense != null) {
            expr = expr & t.isExpense.equals(isExpense);
          }
          return expr;
        },
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.parentId),
        (t) => OrderingTerm.asc(t.sortOrder),
      ]);
    return query;
  }

  @override
  Future<Category?> getById(String id) async {
    final row = await (_db.select(_db.categories)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : CategoryMapper.fromRow(row);
  }

  @override
  Future<Category> createCategory({
    required String ledgerId,
    required String name,
    required bool isExpense,
    String? parentId,
    String? iconName,
  }) async {
    if (parentId != null) {
      final parent = await getById(parentId);
      if (parent == null || parent.ledgerId != ledgerId) {
        throw RepositoryException('父分类无效');
      }
      if (parent.parentId != null) {
        throw RepositoryException('仅支持二级分类');
      }
    }

    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final sort = await _nextSortOrder(ledgerId, parentId);

    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            parentId: Value(parentId),
            name: name,
            iconName: Value(iconName),
            isExpense: isExpense,
            createdAt: now,
            updatedAt: now,
            sortOrder: Value(sort),
          ),
        );

    return (await getById(id))!;
  }

  @override
  Future<Category> updateCategory({
    required String id,
    String? name,
    String? iconName,
    int? sortOrder,
  }) async {
    if (await getById(id) == null) {
      throw RepositoryException('分类不存在');
    }
    final now = DateTime.now().toUtc();
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
          CategoriesCompanion(
            name: name == null ? const Value.absent() : Value(name),
            iconName: iconName == null ? const Value.absent() : Value(iconName),
            sortOrder:
                sortOrder == null ? const Value.absent() : Value(sortOrder),
            updatedAt: Value(now),
          ),
        );
    return (await getById(id))!;
  }

  @override
  Future<void> updateSortOrders(Map<String, int> idToSortOrder) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      for (final entry in idToSortOrder.entries) {
        await (_db.update(_db.categories)..where((t) => t.id.equals(entry.key)))
            .write(
          CategoriesCompanion(
            sortOrder: Value(entry.value),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  @override
  Future<void> deleteCategory(String id) async {
    final category = await getById(id);
    if (category == null) {
      throw RepositoryException('分类不存在');
    }
    if (!category.isDeletable) {
      throw RepositoryException('系统分类「其他」不可删除');
    }

    final now = DateTime.now().toUtc();
    final fallback = await getFallbackCategory(
      ledgerId: category.ledgerId,
      isExpense: category.isExpense,
    );

    await _db.transaction(() async {
      if (category.isTopLevel) {
        await (_db.update(_db.transactions)
              ..where((t) => t.categoryId.equals(id)))
            .write(
          TransactionsCompanion(
            categoryId: Value(fallback.id),
            subCategoryId: const Value(null),
            updatedAt: Value(now),
          ),
        );
        final children = await (_db.select(_db.categories)
              ..where(
                (t) => t.parentId.equals(id) & t.deletedAt.isNull(),
              ))
            .get();
        for (final child in children) {
          await (_db.update(_db.categories)
                ..where((t) => t.id.equals(child.id)))
              .write(
            CategoriesCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      } else {
        await (_db.update(_db.transactions)
              ..where((t) => t.subCategoryId.equals(id)))
            .write(
          TransactionsCompanion(
            subCategoryId: const Value(null),
            updatedAt: Value(now),
          ),
        );
      }

      await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
            CategoriesCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });
  }

  @override
  Future<Category> getFallbackCategory({
    required String ledgerId,
    required bool isExpense,
  }) async {
    final name = isExpense
        ? DefaultCategories.otherExpenseName
        : DefaultCategories.otherIncomeName;
    final row = await (_db.select(_db.categories)
          ..where(
            (t) =>
                t.ledgerId.equals(ledgerId) &
                t.isExpense.equals(isExpense) &
                t.name.equals(name) &
                t.isSystem.equals(true) &
                t.deletedAt.isNull(),
          )
          ..limit(1))
        .getSingleOrNull();
    if (row == null) {
      throw RepositoryException('缺少系统分类「其他」');
    }
    return CategoryMapper.fromRow(row);
  }

  Future<int> _nextSortOrder(String ledgerId, String? parentId) async {
    final query = _db.select(_db.categories)
      ..where(
        (t) {
          var expr =
              t.ledgerId.equals(ledgerId) & t.deletedAt.isNull();
          if (parentId == null) {
            expr = expr & t.parentId.isNull();
          } else {
            expr = expr & t.parentId.equals(parentId);
          }
          return expr;
        },
      )
      ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
      ..limit(1);
    final rows = await query.get();
    if (rows.isEmpty) {
      return 0;
    }
    return rows.first.sortOrder + 1;
  }
}
