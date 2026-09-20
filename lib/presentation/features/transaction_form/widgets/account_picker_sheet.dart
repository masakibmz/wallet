import 'package:flutter/cupertino.dart';
import 'package:wallet/domain/accounting/account_classifier.dart';
import 'package:wallet/domain/entities/account.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/utils/formatters.dart';

typedef AccountBalanceLookup = int Function(String accountId);

Future<String?> showAccountPickerSheet({
  required BuildContext context,
  required List<Account> accounts,
  required AccountBalanceLookup balanceMinor,
  String? selectedId,
  String title = '选择账户',
}) {
  final grouped = _groupAccounts(accounts);
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => _AccountSheet(
      title: title,
      grouped: grouped,
      balanceMinor: balanceMinor,
      selectedId: selectedId,
    ),
  );
}

Map<String, List<Account>> _groupAccounts(List<Account> accounts) {
  final map = <String, List<Account>>{};
  for (final a in accounts) {
    final key = switch (a.category) {
      AccountCategory.cash => '现金',
      AccountCategory.bank => '银行卡',
      AccountCategory.alipay ||
      AccountCategory.wechat ||
      AccountCategory.qqWallet =>
        '第三方支付',
      AccountCategory.creditCard ||
      AccountCategory.huabei ||
      AccountCategory.jdBaitiao ||
      AccountCategory.otherCredit =>
        '信用卡',
      _ => '其它',
    };
    map.putIfAbsent(key, () => []).add(a);
  }
  return map;
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({
    required this.title,
    required this.grouped,
    required this.balanceMinor,
    this.selectedId,
  });

  final String title;
  final Map<String, List<Account>> grouped;
  final AccountBalanceLookup balanceMinor;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.55;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  CupertinoListSection.insetGrouped(
                    children: [
                      for (final a in entry.value)
                        CupertinoListTile(
                          title: Text(a.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_balanceLabel(a, balanceMinor(a.id))),
                              if (selectedId == a.id) ...[
                                const SizedBox(width: 6),
                                const Icon(CupertinoIcons.check_mark, size: 18),
                              ],
                            ],
                          ),
                          onTap: () => Navigator.pop(context, a.id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _balanceLabel(Account account, int positionMinor) {
    if (AccountClassifier.isLiability(account.category)) {
      if (positionMinor > 0) {
        return '欠款 ${formatMinorAmount(positionMinor, account.currencyCode)}';
      }
      if (positionMinor < 0) {
        return '溢缴款 ${formatMinorAmount(positionMinor.abs(), account.currencyCode)}';
      }
      return '无欠款';
    }
    return formatMinorAmount(positionMinor, account.currencyCode);
  }
}
