import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/domain/entities/account.dart';

class AccountMapper {
  static Account fromRow(AccountRow row) {
    return Account(
      id: row.id,
      ledgerId: row.ledgerId,
      name: row.name,
      category: row.category,
      currencyCode: row.currencyCode,
      initialBalanceMinor: row.initialBalanceMinor,
      includeInTotal: row.includeInTotal,
      isHidden: row.isHidden,
      sortOrder: row.sortOrder,
      note: row.note,
      creditLimitMinor: row.creditLimitMinor,
      billingDay: row.billingDay,
      repaymentDay: row.repaymentDay,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  static List<Account> fromRows(List<AccountRow> rows) =>
      rows.map(fromRow).toList(growable: false);
}
