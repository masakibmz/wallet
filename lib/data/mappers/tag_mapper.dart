import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/domain/entities/tag.dart';

class TagMapper {
  static Tag fromRow(TagRow row) {
    return Tag(
      id: row.id,
      ledgerId: row.ledgerId,
      name: row.name,
      colorValue: row.colorValue,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  static List<Tag> fromRows(List<TagRow> rows) =>
      rows.map(fromRow).toList(growable: false);
}
