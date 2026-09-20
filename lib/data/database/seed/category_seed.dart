import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/core/constants/default_categories.dart';
import 'package:wallet/data/database/app_database.dart';

class CategorySeed {
  CategorySeed(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<void> ensureForLedger(String ledgerId) async {
    final existing = await (_db.select(_db.categories)
          ..where(
            (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
          )
          ..limit(1))
        .get();
    if (existing.isNotEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      var order = 0;
      for (final spec in DefaultCategories.expenseRoots) {
        order = await _insertTree(
          ledgerId: ledgerId,
          spec: spec,
          isExpense: true,
          sortStart: order,
          now: now,
        );
      }
      order = 0;
      for (final spec in DefaultCategories.incomeRoots) {
        order = await _insertTree(
          ledgerId: ledgerId,
          spec: spec,
          isExpense: false,
          sortStart: order,
          now: now,
        );
      }
    });
  }

  Future<int> _insertTree({
    required String ledgerId,
    required DefaultCategorySpec spec,
    required bool isExpense,
    required int sortStart,
    required DateTime now,
    String? parentId,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            parentId: Value(parentId),
            name: spec.name,
            iconName: Value(spec.iconName),
            isExpense: isExpense,
            isSystem: Value(spec.isSystem),
            isDeletable: Value(spec.isDeletable),
            sortOrder: Value(sortStart),
            createdAt: now,
            updatedAt: now,
          ),
        );

    var childOrder = 0;
    for (final child in spec.children) {
      childOrder = await _insertTree(
        ledgerId: ledgerId,
        spec: child,
        isExpense: isExpense,
        sortStart: childOrder,
        now: now,
        parentId: id,
      );
      childOrder++;
    }
    return sortStart + 1;
  }
}
