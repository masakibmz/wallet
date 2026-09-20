import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet/application/providers/asset_group_providers.dart';
import 'package:wallet/application/providers/account_balance_providers.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/domain/entities/account.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/account_icons.dart';
import 'package:wallet/presentation/utils/formatters.dart';
import 'package:wallet/services/asset_group_layout_service.dart';

class AssetGroupManagePage extends ConsumerStatefulWidget {
  const AssetGroupManagePage({super.key});

  @override
  ConsumerState<AssetGroupManagePage> createState() =>
      _AssetGroupManagePageState();
}

class _AssetGroupManagePageState extends ConsumerState<AssetGroupManagePage> {
  AssetGroupLayout? _layout;
  bool _loading = true;
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ledger = ref.read(currentLedgerProvider);
    if (ledger == null) {
      setState(() => _loading = false);
      return;
    }
    final accounts =
        ref.read(accountsForLedgerProvider(ledger.id)).valueOrNull ?? [];
    final service = await ref.read(assetGroupLayoutServiceProvider.future);
    final layout =
        await service.loadOrDefault(ledgerId: ledger.id, accounts: accounts);
    if (mounted) {
      setState(() {
        _layout = layout;
        _loading = false;
      });
    }
  }

  Future<void> _persist() async {
    final ledger = ref.read(currentLedgerProvider);
    final layout = _layout;
    if (ledger == null || layout == null) {
      return;
    }
    await persistAssetGroupLayout(ref, ledger.id, layout);
  }

  Future<void> _addGroup() async {
    final controller = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('添加分组'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '请输入分组名称',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (ok != true) {
      controller.dispose();
      return;
    }
    final name = controller.text.trim();
    controller.dispose();
    if (name.isEmpty) {
      return;
    }
    setState(() {
      _layout = _layout!.copyWith(
        groups: [
          ..._layout!.groups,
          AssetGroupEntry(id: _uuid.v4(), name: name),
        ],
      );
    });
    await _persist();
  }

  Future<void> _renameGroup(AssetGroupEntry group) async {
    final controller = TextEditingController(text: group.name);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('重命名分组'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(controller: controller),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (ok != true) {
      controller.dispose();
      return;
    }
    final name = controller.text.trim();
    controller.dispose();
    if (name.isEmpty) {
      return;
    }
    setState(() {
      _layout = _layout!.copyWith(
        groups: [
          for (final g in _layout!.groups)
            if (g.id == group.id) AssetGroupEntry(id: g.id, name: name) else g,
        ],
      );
    });
    await _persist();
  }

  Future<void> _groupMenu(AssetGroupEntry group) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _renameGroup(group);
            },
            child: const Text('重命名'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                final nextAssign = Map<String, String>.from(
                  _layout!.accountToGroupId,
                )..removeWhere((_, gid) => gid == group.id);
                _layout = _layout!.copyWith(
                  groups: _layout!.groups.where((g) => g.id != group.id).toList(),
                  accountToGroupId: nextAssign,
                );
              });
              await _persist();
            },
            child: const Text('删除分组'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _assignAccount(AssetGroupEntry group) async {
    final ledger = ref.read(currentLedgerProvider);
    if (ledger == null) {
      return;
    }
    final accounts =
        ref.read(accountsForLedgerProvider(ledger.id)).valueOrNull ?? [];
    final visible = accounts.where((a) => !a.isHidden).toList();
    if (visible.isEmpty) {
      return;
    }

    final picked = await showCupertinoModalPopup<Account>(
      context: context,
      builder: (ctx) {
        return Container(
          height: 360,
          color: QianjiColors.cardBackground,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('选择账户加入分组'),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final a in visible)
                      CupertinoButton(
                        onPressed: () => Navigator.pop(ctx, a),
                        child: Row(
                          children: [
                            Expanded(child: Text(a.name)),
                            Text(
                              formatMinorAmount(
                                a.initialBalanceMinor,
                                a.currencyCode,
                              ),
                              style: const TextStyle(
                                color: QianjiColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked == null) {
      return;
    }
    setState(() {
      final next = Map<String, String>.from(_layout!.accountToGroupId);
      next[picked.id] = group.id;
      _layout = _layout!.copyWith(accountToGroupId: next);
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(currentLedgerProvider);
    if (_loading || ledger == null || _layout == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final accounts =
        ref.watch(accountsForLedgerProvider(ledger.id)).valueOrNull ?? [];
    final balances = ref.watch(accountBalancesForLedgerProvider(ledger.id));

    return CupertinoPageScaffold(
      backgroundColor: QianjiColors.pageBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('资产分组管理'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _addGroup,
              child: const Icon(CupertinoIcons.add),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              child: const Icon(CupertinoIcons.question_circle),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final group in _layout!.groups) ...[
              _GroupCard(
                title: group.name,
                accounts: accounts
                    .where(
                      (a) => _layout!.accountToGroupId[a.id] == group.id,
                    )
                    .toList(),
                balances: balances,
                onMenu: () => _groupMenu(group),
                onAdd: () => _assignAccount(group),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.accounts,
    required this.balances,
    required this.onMenu,
    required this.onAdd,
  });

  final String title;
  final List<Account> accounts;
  final Map<String, int> balances;
  final VoidCallback onMenu;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
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
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onMenu,
                child: const Icon(CupertinoIcons.ellipsis, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final a in accounts)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accountIconStyleFor(a.category).bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            accountIconStyleFor(a.category).icon,
                            color: accountIconStyleFor(a.category).color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 56,
                          child: Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onAdd,
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: QianjiColors.chipBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(CupertinoIcons.add),
                      ),
                      const SizedBox(height: 6),
                      const Text('添加', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
