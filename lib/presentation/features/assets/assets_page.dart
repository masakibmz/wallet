import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/presentation/features/assets/account_type_picker_sheet.dart';
import 'package:wallet/application/providers/account_balance_providers.dart';
import 'package:wallet/application/providers/asset_group_providers.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/presentation/features/assets/asset_group_manage_page.dart';
import 'package:wallet/services/asset_group_layout_service.dart';
import 'package:wallet/domain/accounting/account_classifier.dart';
import 'package:wallet/domain/entities/account.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/account_icons.dart';
import 'package:wallet/presentation/utils/formatters.dart';

const _groupOrder = [
  '现金',
  '银行卡',
  '第三方支付',
  '信用卡',
  '其它',
];

Map<String, List<Account>> _groupAccounts(List<Account> accounts) {
  final map = <String, List<Account>>{};
  for (final a in accounts) {
    if (a.isHidden) {
      continue;
    }
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
  for (final list in map.values) {
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
  return map;
}

class _AssetTotals {
  const _AssetTotals({
    required this.netMinor,
    required this.assetMinor,
    required this.liabilityMinor,
    required this.assetCount,
    required this.liabilityCount,
  });

  final int netMinor;
  final int assetMinor;
  final int liabilityMinor;
  final int assetCount;
  final int liabilityCount;

  double get liabilityRatio {
    final denom = assetMinor + liabilityMinor;
    if (denom <= 0) {
      return 0;
    }
    return liabilityMinor / denom;
  }
}

_AssetTotals _computeTotals(
  List<Account> accounts,
  Map<String, int> balances,
) {
  var assets = 0;
  var liabilities = 0;
  var assetCount = 0;
  var liabilityCount = 0;

  for (final a in accounts) {
    if (a.isHidden || !a.includeInTotal) {
      continue;
    }
    final balance = balances[a.id] ?? a.initialBalanceMinor;
    if (AccountClassifier.isLiability(a.category)) {
      final debt = balance < 0 ? -balance : balance;
      liabilities += debt;
      liabilityCount++;
    } else {
      assets += balance;
      assetCount++;
    }
  }

  return _AssetTotals(
    netMinor: assets - liabilities,
    assetMinor: assets,
    liabilityMinor: liabilities,
    assetCount: assetCount,
    liabilityCount: liabilityCount,
  );
}

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  bool _hideAmounts = false;
  final _collapsedGroups = <String>{};

  @override
  Widget build(BuildContext context) {
    ref.watch(appBootstrapProvider);
    final ledger = ref.watch(currentLedgerProvider);
    if (ledger == null) {
      return const CupertinoPageScaffold(
        backgroundColor: QianjiColors.pageBackground,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final accountsAsync = ref.watch(accountsForLedgerProvider(ledger.id));
    final layoutAsync = ref.watch(assetGroupLayoutProvider);
    final balances = ref.watch(accountBalancesForLedgerProvider(ledger.id));
    final currency = ledger.baseCurrencyCode;

    return CupertinoPageScaffold(
      backgroundColor: QianjiColors.pageBackground,
      child: SafeArea(
        bottom: false,
        child: accountsAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (accounts) {
            return layoutAsync.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (layout) {
            final visible = accounts.where((a) => !a.isHidden).toList();
            final totals = _computeTotals(visible, balances);
            final grouped = layout != null
                ? groupAccountsByLayout(accounts, layout)
                : _groupAccounts(accounts);
            final groupNames = _orderedGroupNames(layout, grouped);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _AssetsTopBar(
                  onAdd: () => _onAddAccount(context),
                  onMore: () => _openGroupManage(context),
                ),
                const SizedBox(height: 8),
                _NetWorthCard(
                  totals: totals,
                  currency: currency,
                  hideAmounts: _hideAmounts,
                  onToggleHide: () =>
                      setState(() => _hideAmounts = !_hideAmounts),
                ),
                const SizedBox(height: 12),
                _AssetAnalysisCard(totals: totals),
                const SizedBox(height: 12),
                const _DebtManagementCard(),
                for (final groupName in groupNames)
                  if (grouped.containsKey(groupName) &&
                      grouped[groupName]!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _AccountGroupSection(
                      title: groupName,
                      accounts: grouped[groupName]!,
                      balances: balances,
                      currency: currency,
                      hideAmounts: _hideAmounts,
                      expanded: !_collapsedGroups.contains(groupName),
                      onToggle: () {
                        setState(() {
                          if (_collapsedGroups.contains(groupName)) {
                            _collapsedGroups.remove(groupName);
                          } else {
                            _collapsedGroups.add(groupName);
                          }
                        });
                      },
                    ),
                  ],
              ],
            );
              },
            );
          },
        ),
      ),
    );
  }

  List<String> _orderedGroupNames(
    AssetGroupLayout? layout,
    Map<String, List<Account>> grouped,
  ) {
    if (layout != null) {
      final names = layout.groups.map((g) => g.name).toList();
      for (final key in grouped.keys) {
        if (!names.contains(key)) {
          names.add(key);
        }
      }
      return names;
    }
    final names = [..._groupOrder];
    for (final key in grouped.keys) {
      if (!names.contains(key)) {
        names.add(key);
      }
    }
    return names;
  }

  Future<void> _openGroupManage(BuildContext context) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => const AssetGroupManagePage(),
      ),
    );
    ref.invalidate(assetGroupLayoutProvider);
  }

  Future<void> _onAddAccount(BuildContext context) async {
    final category = await showAccountTypePickerSheet(context);
    if (category == null || !context.mounted) {
      return;
    }
    context.push('/assets/add?type=${category.name}');
  }

}

class _AssetsTopBar extends StatelessWidget {
  const _AssetsTopBar({required this.onAdd, required this.onMore});

  final VoidCallback onAdd;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '资产',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: QianjiColors.textPrimary,
          ),
        ),
        const Spacer(),
        _CircleIconButton(
          icon: CupertinoIcons.add,
          onPressed: onAdd,
        ),
        const SizedBox(width: 8),
        _CircleIconButton(
          icon: CupertinoIcons.ellipsis,
          onPressed: onMore,
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: QianjiColors.divider),
          color: QianjiColors.cardBackground,
        ),
        child: Icon(icon, size: 20, color: QianjiColors.textPrimary),
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.totals,
    required this.currency,
    required this.hideAmounts,
    required this.onToggleHide,
  });

  final _AssetTotals totals;
  final String currency;
  final bool hideAmounts;
  final VoidCallback onToggleHide;

  String _mask(String formatted) => hideAmounts ? '****' : formatted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '净资产',
                style: TextStyle(
                  fontSize: 14,
                  color: QianjiColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onToggleHide,
                child: Icon(
                  hideAmounts
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  size: 16,
                  color: QianjiColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _mask(formatMinorAmount(totals.netMinor, currency)),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: QianjiColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryColumn(
                  label: '总资产',
                  value: _mask(formatMinorAmount(totals.assetMinor, currency)),
                ),
              ),
              Container(width: 1, height: 36, color: QianjiColors.divider),
              Expanded(
                child: _SummaryColumn(
                  label: '总负债',
                  value:
                      _mask(formatMinorAmount(totals.liabilityMinor, currency)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: QianjiColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.info_circle,
              size: 14,
              color: QianjiColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: QianjiColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AssetAnalysisCard extends StatelessWidget {
  const _AssetAnalysisCard({required this.totals});

  final _AssetTotals totals;

  @override
  Widget build(BuildContext context) {
    final ratio = totals.liabilityRatio;
    return _QianjiSectionCard(
      title: '资产分析',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (ratio > 0)
                    Expanded(
                      flex: (ratio * 1000).round().clamp(1, 1000),
                      child: const ColoredBox(color: QianjiColors.expense),
                    ),
                  Expanded(
                    flex: ((1 - ratio) * 1000).round().clamp(1, 1000),
                    child: const ColoredBox(color: QianjiColors.chipBackground),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${totals.assetCount} 项资产 | ${totals.liabilityCount} 项负债',
                style: const TextStyle(
                  fontSize: 13,
                  color: QianjiColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '负债率 ${(ratio * 100).toStringAsFixed(2)}%',
                style: const TextStyle(
                  fontSize: 13,
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

class _DebtManagementCard extends StatelessWidget {
  const _DebtManagementCard();

  @override
  Widget build(BuildContext context) {
    return _QianjiSectionCard(
      title: '债务管理',
      child: Row(
        children: [
          Expanded(
            child: _DebtTile(
              icon: CupertinoIcons.arrow_down,
              label: '总借入',
              amount: '0.00',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DebtTile(
              icon: CupertinoIcons.arrow_up,
              label: '总借出',
              amount: '0.00',
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.icon,
    required this.label,
    required this.amount,
  });

  final IconData icon;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: QianjiColors.pageBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: QianjiColors.cardBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: QianjiColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: QianjiColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: QianjiColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QianjiSectionCard extends StatelessWidget {
  const _QianjiSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: QianjiColors.textPrimary,
                ),
              ),
              const Spacer(),
              const Icon(
                CupertinoIcons.ellipsis,
                color: QianjiColors.textSecondary,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AccountGroupSection extends StatelessWidget {
  const _AccountGroupSection({
    required this.title,
    required this.accounts,
    required this.balances,
    required this.currency,
    required this.hideAmounts,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final List<Account> accounts;
  final Map<String, int> balances;
  final String currency;
  final bool hideAmounts;
  final bool expanded;
  final VoidCallback onToggle;

  int get _groupTotal {
    var sum = 0;
    for (final a in accounts) {
      sum += balances[a.id] ?? a.initialBalanceMinor;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onPressed: onToggle,
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: QianjiColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  hideAmounts
                      ? '****'
                      : formatMinorAmount(_groupTotal, currency),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: QianjiColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded
                      ? CupertinoIcons.chevron_down
                      : CupertinoIcons.chevron_right,
                  size: 16,
                  color: QianjiColors.textSecondary,
                ),
              ],
            ),
          ),
          if (expanded)
            for (var i = 0; i < accounts.length; i++) ...[
              if (i > 0)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(left: 68),
                  color: QianjiColors.divider,
                ),
              _AccountListTile(
                account: accounts[i],
                balanceMinor:
                    balances[accounts[i].id] ?? accounts[i].initialBalanceMinor,
                hideAmounts: hideAmounts,
              ),
            ],
        ],
      ),
    );
  }
}

class _AccountListTile extends StatelessWidget {
  const _AccountListTile({
    required this.account,
    required this.balanceMinor,
    required this.hideAmounts,
  });

  final Account account;
  final int balanceMinor;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    final style = accountIconStyleFor(account.category);
    final amount = hideAmounts
        ? '****'
        : formatMinorAmount(balanceMinor, account.currencyCode);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: () {},
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.bg ?? QianjiColors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(style.icon, color: style.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              account.name,
              style: const TextStyle(
                fontSize: 16,
                color: QianjiColors.textPrimary,
              ),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: QianjiColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
