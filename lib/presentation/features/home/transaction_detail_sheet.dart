import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/formatters.dart';

Future<void> showTransactionDetailSheet(
  BuildContext context, {
  required WalletTransaction transaction,
  required String? categoryName,
  required String? accountName,
  required VoidCallback onCopy,
  VoidCallback? onRefund,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _TransactionDetailSheet(
      transaction: transaction,
      categoryName: categoryName,
      accountName: accountName,
      onCopy: () {
        Navigator.pop(ctx);
        onCopy();
      },
      onRefund: onRefund == null
          ? null
          : () {
              Navigator.pop(ctx);
              onRefund();
            },
      onEdit: () {
        Navigator.pop(ctx);
        onEdit();
      },
      onDelete: () {
        Navigator.pop(ctx);
        onDelete();
      },
    ),
  );
}

class _TransactionDetailSheet extends StatelessWidget {
  const _TransactionDetailSheet({
    required this.transaction,
    required this.categoryName,
    required this.accountName,
    required this.onCopy,
    required this.onRefund,
    required this.onEdit,
    required this.onDelete,
  });

  final WalletTransaction transaction;
  final String? categoryName;
  final String? accountName;
  final VoidCallback onCopy;
  final VoidCallback? onRefund;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome
        ? QianjiColors.income
        : isExpense
            ? QianjiColors.expense
            : QianjiColors.textPrimary;
    final prefix = isIncome ? '+' : isExpense ? '-' : '';
    final amountText =
        '$prefix${formatMinorAmount(transaction.amountMinor, transaction.currencyCode)}';
    final occurred = transaction.occurredAt.toLocal();
    final timeFmt = DateFormat('yyyy-MM-dd HH:mm');
    final recorded = transaction.createdAt.toLocal();

    return Container(
      decoration: const BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: QianjiColors.chipBackground,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '账单详情',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: QianjiColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(label: '复制', onTap: onCopy),
              if (onRefund != null)
                _ActionChip(label: '退款', onTap: onRefund!),
              _ActionChip(label: '修改', onTap: onEdit),
              _ActionChip(
                label: '删除',
                destructive: true,
                onTap: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: '金额',
            value: amountText,
            valueStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: amountColor,
            ),
          ),
          _DetailRow(
            label: '分类',
            value: categoryName ?? formatTransactionType(transaction.type),
            trailing: const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: QianjiColors.textSecondary,
            ),
          ),
          if (accountName != null)
            _DetailRow(
              label: isIncome ? '收入账户' : '支出账户',
              value: accountName!,
              trailing: const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: QianjiColors.textSecondary,
              ),
            ),
          _DetailRow(
            label: '时间',
            value: timeFmt.format(occurred),
            subtitle: '记录于 ${timeFmt.format(recorded)}',
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minSize: 0,
      color: destructive
          ? const Color(0xFFFFEBEE)
          : QianjiColors.chipBackground,
      borderRadius: BorderRadius.circular(8),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: destructive ? QianjiColors.expense : QianjiColors.textPrimary,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueStyle,
    this.trailing,
  });

  final String label;
  final String value;
  final String? subtitle;
  final TextStyle? valueStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: QianjiColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: valueStyle ??
                      const TextStyle(
                        fontSize: 15,
                        color: QianjiColors.textPrimary,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: QianjiColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
