import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/widgets/qianji/qianji_transaction_row.dart';

class QianjiSlidableTransactionRow extends StatelessWidget {
  const QianjiSlidableTransactionRow({
    super.key,
    required this.transaction,
    this.categoryName,
    this.accountName,
    this.onTap,
    this.onRefund,
    this.onEdit,
    this.onDelete,
  });

  final WalletTransaction transaction;
  final String? categoryName;
  final String? accountName;
  final VoidCallback? onTap;
  final VoidCallback? onRefund;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  bool get _showRefund =>
      transaction.type == TransactionType.expense && onRefund != null;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (_showRefund)
        SlidableAction(
          onPressed: (_) => onRefund!(),
          backgroundColor: const Color(0xFF1C1C1E),
          foregroundColor: CupertinoColors.white,
          label: '退款',
        ),
      if (onEdit != null)
        SlidableAction(
          onPressed: (_) => onEdit!(),
          backgroundColor: const Color(0xFFFF9500),
          foregroundColor: CupertinoColors.white,
          label: '修改',
        ),
      if (onDelete != null)
        SlidableAction(
          onPressed: (_) => onDelete!(),
          backgroundColor: const Color(0xFFFF3B30),
          foregroundColor: CupertinoColors.white,
          label: '删除',
        ),
    ];

    if (actions.isEmpty) {
      return QianjiTransactionRow(
        transaction: transaction,
        categoryName: categoryName,
        accountName: accountName,
        onTap: onTap,
      );
    }

    return Slidable(
      key: ValueKey(transaction.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: _showRefund ? 0.55 : 0.38,
        children: actions,
      ),
      child: QianjiTransactionRow(
        transaction: transaction,
        categoryName: categoryName,
        accountName: accountName,
        onTap: onTap,
      ),
    );
  }
}
