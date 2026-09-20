import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/repositories/local/local_repository.dart';

abstract class AttachmentRepository {
  Future<List<String>> getLocalPaths(String transactionId);

  Future<void> replaceAttachments({
    required String transactionId,
    required List<String> localPaths,
  });
}

class AttachmentLocalRepository extends LocalRepository
    implements AttachmentRepository {
  AttachmentLocalRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Future<List<String>> getLocalPaths(String transactionId) async {
    final rows = await (_db.select(_db.attachments)
          ..where(
            (a) =>
                a.transactionId.equals(transactionId) & a.deletedAt.isNull(),
          )
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
        .get();
    return rows.map((r) => r.localPath).toList(growable: false);
  }

  @override
  Future<void> replaceAttachments({
    required String transactionId,
    required List<String> localPaths,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.attachments)
            ..where((a) => a.transactionId.equals(transactionId)))
          .write(
        AttachmentsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      if (localPaths.isEmpty) {
        return;
      }
      var order = 0;
      for (final path in localPaths) {
        await _db.into(_db.attachments).insert(
              AttachmentsCompanion.insert(
                id: _uuid.v4(),
                transactionId: transactionId,
                localPath: path,
                sortOrder: Value(order++),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
  }
}
