import 'package:wallet/core/money/money_amount.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';

/// 列表展示用：有二级分类时为「父-子」，否则为分类名。
String formatCategoryListLabel(
  WalletTransaction tx,
  Map<String, String> categoryNamesById,
) {
  final parentId = tx.categoryId;
  final subId = tx.subCategoryId;
  final parent =
      parentId == null ? null : categoryNamesById[parentId];
  final sub = subId == null ? null : categoryNamesById[subId];
  if (sub != null && parent != null) {
    return '$parent-$sub';
  }
  if (sub != null) {
    return sub;
  }
  if (parent != null) {
    return parent;
  }
  return formatTransactionType(tx.type);
}

String formatTransactionType(TransactionType type) {
  return switch (type) {
    TransactionType.expense => '支出',
    TransactionType.income => '收入',
    TransactionType.transfer => '转账',
    TransactionType.creditRepayment => '还款',
    TransactionType.refund => '退款',
  };
}

String formatMinorAmount(int minorUnits, String currencyCode) {
  final prefix = currencyCode == 'CNY' ? '¥' : '$currencyCode ';
  final text = MoneyAmount(
    minorUnits: minorUnits,
    currencyCode: currencyCode,
  ).format();
  return currencyCode == 'CNY' ? '$prefix$text' : '$prefix$text';
}
