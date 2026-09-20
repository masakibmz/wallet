import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/domain/entities/transaction.dart';

class TransactionMapper {
  static WalletTransaction fromRow(
    TransactionRow row, {
    List<String> tagIds = const [],
  }) {
    return WalletTransaction(
      id: row.id,
      ledgerId: row.ledgerId,
      type: row.type,
      amountMinor: row.amountMinor,
      currencyCode: row.currencyCode,
      accountId: row.accountId,
      toAccountId: row.toAccountId,
      categoryId: row.categoryId,
      subCategoryId: row.subCategoryId,
      occurredAt: row.occurredAt,
      note: row.note,
      feeMinor: row.feeMinor,
      couponMinor: row.couponMinor,
      reimbursementStatus: row.reimbursementStatus,
      reimbursementTarget: row.reimbursementTarget,
      originalTransactionId: row.originalTransactionId,
      refundStatus: row.refundStatus,
      tagIds: tagIds,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
