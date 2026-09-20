import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/data/repositories/local/budget_local_repository.dart';
import 'package:wallet/domain/entities/ledger.dart';
import 'package:wallet/native/ios/ios_native_bridge.dart';
import 'package:wallet/presentation/features/settings/category_manage_page.dart';
import 'package:wallet/presentation/features/settings/tag_manage_page.dart';
import 'package:wallet/application/providers/app_preferences_provider.dart';
import 'package:wallet/presentation/features/ai/ai_draft_sheet.dart';
import 'package:wallet/services/app_preferences_service.dart';
import 'package:wallet/services/csv_export_service.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetLocalRepository(ref.watch(appDatabaseProvider));
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(appPreferencesProvider);
    final ledgersAsync = ref.watch(activeLedgersProvider);
    final ledger = ref.watch(currentLedgerProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('设置')),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('账本'),
              children: [
                ledgersAsync.when(
                  data: (ledgers) => CupertinoListTile(
                    title: const Text('切换账本'),
                    trailing: Text(ledger?.name ?? ''),
                    onTap: () => _pickLedger(context, ref, ledgers),
                  ),
                  loading: () => const CupertinoListTile(
                    title: Text('加载账本…'),
                  ),
                  error: (e, _) => CupertinoListTile(title: Text('$e')),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('管理'),
              children: [
                CupertinoListTile(
                  title: const Text('分类管理'),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const CategoryManagePage(),
                    ),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('标签管理'),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const TagManagePage(),
                    ),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('搜索账单'),
                  onTap: () => context.push('/search'),
                ),
                CupertinoListTile(
                  title: const Text('AI 记账（Mock）'),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const AiDraftSheet(),
                    ),
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('数据'),
              children: [
                CupertinoListTile(
                  title: const Text('导出 CSV'),
                  onTap: () async {
                    final l = ref.read(currentLedgerProvider);
                    if (l == null) {
                      return;
                    }
                    final txs = await ref
                        .read(transactionRepositoryProvider)
                        .getTransactions(ledgerId: l.id);
                    final csv =
                        const CsvExportService().exportTransactions(txs);
                    if (!context.mounted) {
                      return;
                    }
                    await showCupertinoDialog<void>(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text('CSV 预览'),
                        content: SingleChildScrollView(
                          child: Text(
                            csv.length > 500
                                ? '${csv.substring(0, 500)}…'
                                : csv,
                          ),
                        ),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            prefsAsync.when(
              data: (prefs) => CupertinoListSection.insetGrouped(
                header: const Text('隐私与启动'),
                children: [
                  CupertinoListTile(
                    title: const Text('App 锁（Face ID / Touch ID）'),
                    trailing: CupertinoSwitch(
                      value: prefs.appLockEnabled,
                      onChanged: (v) async {
                        if (v) {
                          final ok = await IosNativeBridge.instance
                              .authenticateWithBiometrics();
                          if (!ok) {
                            return;
                          }
                        }
                        await prefs.setAppLockEnabled(v);
                        ref.invalidate(appPreferencesProvider);
                      },
                    ),
                  ),
                  CupertinoListTile(
                    title: const Text('秒开模式（进入记账）'),
                    trailing: CupertinoSwitch(
                      value: prefs.launchMode == AppLaunchMode.addTransaction,
                      onChanged: (v) async {
                        await prefs.setLaunchMode(
                          v
                              ? AppLaunchMode.addTransaction
                              : AppLaunchMode.home,
                        );
                        ref.invalidate(appPreferencesProvider);
                      },
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLedger(
    BuildContext context,
    WidgetRef ref,
    List<Ledger> ledgers,
  ) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择账本'),
        actions: [
          for (final l in ledgers)
            CupertinoActionSheetAction(
              onPressed: () {
                selectLedger(ref, l.id);
                Navigator.pop(ctx);
              },
              child: Text(l.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }
}
