import 'package:flutter/cupertino.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/utils/formatters.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
    this.categoryName,
    this.accountName,
    this.onTap,
  });

  final WalletTransaction transaction;
  final String? categoryName;
  final String? accountName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amount = _formatAmount(transaction);
    final subtitle = [
      if (categoryName != null) categoryName,
      if (accountName != null) accountName,
      if (transaction.note != null && transaction.note!.isNotEmpty)
        transaction.note,
    ].whereType<String>().join(' · ');

    return CupertinoListTile(
      title: Text(formatTransactionType(transaction.type)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Text(
        amount,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: _amountColor(context, transaction.type),
        ),
      ),
      onTap: onTap,
    );
  }

  Color _amountColor(BuildContext context, TransactionType type) {
    return switch (type) {
      TransactionType.income => CupertinoColors.systemGreen.resolveFrom(context),
      TransactionType.expense => CupertinoColors.label.resolveFrom(context),
      _ => CupertinoColors.activeBlue.resolveFrom(context),
    };
  }

  String _formatAmount(WalletTransaction tx) {
    final base = formatMinorAmount(tx.amountMinor, tx.currencyCode);
    return switch (tx.type) {
      TransactionType.expense => '-$base',
      TransactionType.income => '+$base',
      _ => base,
    };
  }
}
