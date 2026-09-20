import 'package:flutter/cupertino.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/category_icons.dart';
import 'package:wallet/presentation/utils/formatters.dart';

class QianjiTransactionRow extends StatelessWidget {
  const QianjiTransactionRow({
    super.key,
    required this.transaction,
    this.categoryName,
    this.accountName,
    this.detailLine,
    this.onTap,
  });

  final WalletTransaction transaction;
  final String? categoryName;
  final String? accountName;
  /// 分类标题下方一行（搜索页用日期；默认用备注）
  final String? detailLine;
  final VoidCallback? onTap;

  String? get _secondLine {
    if (detailLine != null && detailLine!.isNotEmpty) {
      return detailLine;
    }
    final note = transaction.note?.trim();
    if (note == null || note.isEmpty) {
      return null;
    }
    return note;
  }

  @override
  Widget build(BuildContext context) {
    final title = categoryName ?? formatTransactionType(transaction.type);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome
        ? QianjiColors.income
        : isExpense
            ? QianjiColors.expense
            : QianjiColors.textPrimary;
    final prefix = isIncome ? '+' : isExpense ? '-' : '';
    final amount = '$prefix${formatMinorAmount(transaction.amountMinor, transaction.currencyCode)}';

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isIncome
                  ? QianjiColors.incomeSoft
                  : QianjiColors.expenseSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              categoryIconFor(title),
              color: amountColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    color: QianjiColors.textPrimary,
                  ),
                ),
                if (_secondLine != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _secondLine!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: QianjiColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                ),
              ),
              if (accountName != null)
                Text(
                  accountName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: QianjiColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
