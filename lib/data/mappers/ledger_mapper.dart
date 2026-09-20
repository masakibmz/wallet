import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/domain/entities/ledger.dart';

class LedgerMapper {
  static Ledger fromRow(LedgerRow row) {
    return Ledger(
      id: row.id,
      name: row.name,
      kind: row.kind,
      iconName: row.iconName,
      colorValue: row.colorValue,
      isDefault: row.isDefault,
      sortOrder: row.sortOrder,
      baseCurrencyCode: row.baseCurrencyCode,
      sharedLedgerId: row.sharedLedgerId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  static List<Ledger> fromRows(List<LedgerRow> rows) =>
      rows.map(fromRow).toList(growable: false);
}
