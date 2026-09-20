import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/mappers/tag_mapper.dart';
import 'package:wallet/data/repositories/local/local_repository.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/entities/tag.dart';

abstract class TagRepository {
  Stream<List<Tag>> watchActiveTags(String ledgerId);

  Future<List<Tag>> getActiveTags(String ledgerId);

  Future<Tag?> getById(String id);

  Future<Tag> createTag({
    required String ledgerId,
    required String name,
    int? colorValue,
  });

  Future<Tag> updateTag({
    required String id,
    String? name,
    int? colorValue,
  });

  Future<void> softDelete(String id);
}

class TagLocalRepository extends LocalRepository implements TagRepository {
  TagLocalRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Stream<List<Tag>> watchActiveTags(String ledgerId) {
    final query = _db.select(_db.tags)
      ..where(
        (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch().map(TagMapper.fromRows);
  }

  @override
  Future<List<Tag>> getActiveTags(String ledgerId) async {
    final query = _db.select(_db.tags)
      ..where(
        (t) => t.ledgerId.equals(ledgerId) & t.deletedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return TagMapper.fromRows(await query.get());
  }

  @override
  Future<Tag?> getById(String id) async {
    final row = await (_db.select(_db.tags)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : TagMapper.fromRow(row);
  }

  @override
  Future<Tag> createTag({
    required String ledgerId,
    required String name,
    int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw RepositoryException('标签名不能为空');
    }

    final duplicate = await (_db.select(_db.tags)
          ..where(
            (t) =>
                t.ledgerId.equals(ledgerId) &
                t.name.equals(trimmed) &
                t.deletedAt.isNull(),
          )
          ..limit(1))
        .getSingleOrNull();
    if (duplicate != null) {
      throw RepositoryException('标签已存在');
    }

    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db.into(_db.tags).insert(
          TagsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            name: trimmed,
            colorValue: Value(colorValue),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getById(id))!;
  }

  @override
  Future<Tag> updateTag({
    required String id,
    String? name,
    int? colorValue,
  }) async {
    if (await getById(id) == null) {
      throw RepositoryException('标签不存在');
    }
    final now = DateTime.now().toUtc();
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
          TagsCompanion(
            name: name == null ? const Value.absent() : Value(name.trim()),
            colorValue:
                colorValue == null ? const Value.absent() : Value(colorValue),
            updatedAt: Value(now),
          ),
        );
    return (await getById(id))!;
  }

  @override
  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.delete(_db.transactionTags)
            ..where((t) => t.tagId.equals(id)))
          .go();
      await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
            TagsCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });
  }
}
