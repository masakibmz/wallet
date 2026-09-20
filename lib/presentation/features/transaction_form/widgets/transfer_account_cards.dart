import 'package:flutter/cupertino.dart';
import 'package:wallet/domain/entities/account.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/formatters.dart';

class TransferAccountCards extends StatelessWidget {
  const TransferAccountCards({
    super.key,
    required this.fromAccount,
    required this.toAccount,
    required this.fromBalanceMinor,
    required this.toBalanceMinor,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSwap,
  });

  final Account? fromAccount;
  final Account? toAccount;
  final int fromBalanceMinor;
  final int toBalanceMinor;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _Card(
            account: fromAccount,
            balanceMinor: fromBalanceMinor,
            placeholder: '转出账户',
            onTap: onPickFrom,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onSwap,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: QianjiColors.chipBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.arrow_up_arrow_down,
                size: 18,
                color: QianjiColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            account: toAccount,
            balanceMinor: toBalanceMinor,
            placeholder: '转入账户',
            onTap: onPickTo,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.account,
    required this.balanceMinor,
    required this.placeholder,
    required this.onTap,
  });

  final Account? account;
  final int balanceMinor;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: QianjiColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: QianjiColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: QianjiColors.chipBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                account == null
                    ? CupertinoIcons.creditcard
                    : CupertinoIcons.building_2_fill,
                color: QianjiColors.expense,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                account?.name ?? placeholder,
                style: TextStyle(
                  fontSize: 16,
                  color: account == null
                      ? QianjiColors.textSecondary
                      : QianjiColors.textPrimary,
                ),
              ),
            ),
            Text(
              account == null
                  ? '0.00'
                  : formatMinorAmount(balanceMinor, account!.currencyCode),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
