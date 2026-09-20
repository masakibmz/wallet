import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/application/transaction_recording/transaction_form_kind.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/features/assets/add_account_page.dart';
import 'package:wallet/presentation/features/assets/assets_page.dart';
import 'package:wallet/presentation/features/home/home_page.dart';
import 'package:wallet/presentation/features/settings/settings_page.dart';
import 'package:wallet/presentation/features/statistics/statistics_page.dart';
import 'package:wallet/presentation/features/refund/refund_form_page.dart';
import 'package:wallet/presentation/features/transaction_form/transaction_form_page.dart';
import 'package:wallet/presentation/features/search/transaction_search_page.dart';
import 'package:wallet/presentation/features/transactions/transactions_page.dart';
import 'package:wallet/application/providers/app_preferences_provider.dart';
import 'package:wallet/presentation/shell/main_tab_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorHomeKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorTransactionsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellTransactions');
final _shellNavigatorStatisticsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellStatistics');
final _shellNavigatorAssetsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellAssets');
final _shellNavigatorSettingsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellSettings');

AccountCategory _parseAccountCategory(String? raw) {
  return AccountCategory.values.asNameMap()[raw] ??
      AccountCategory.otherFund;
}

TransactionFormKind _parseKind(String? raw) {
  return switch (raw) {
    'income' => TransactionFormKind.income,
    'transfer' => TransactionFormKind.transfer,
    'refund' => TransactionFormKind.refund,
    'repayment' => TransactionFormKind.creditRepayment,
    _ => TransactionFormKind.expense,
  };
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // 秒启动在 MainTabShell 中 push 记账页，保证栈底有 /home，返回/保存才能 pop。
  ref.watch(appPreferencesProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainTabShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorTransactionsKey,
            routes: [
              GoRoute(
                path: '/transactions',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: TransactionsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorStatisticsKey,
            routes: [
              GoRoute(
                path: '/statistics',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: StatisticsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorAssetsKey,
            routes: [
              GoRoute(
                path: '/assets',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AssetsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsPage(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const TransactionSearchPage(),
        ),
      ),
      GoRoute(
        path: '/assets/add',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final category = _parseAccountCategory(
            state.uri.queryParameters['type'],
          );
          return CupertinoPage(
            key: state.pageKey,
            child: AddAccountPage(category: category),
          );
        },
      ),
      GoRoute(
        path: '/add-transaction',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final kind = _parseKind(state.uri.queryParameters['type']);
          final copyFrom = state.uri.queryParameters['copyFrom'];
          return CupertinoPage(
            key: state.pageKey,
            child: TransactionFormPage(
              initialKind: kind,
              copyFromTransactionId: copyFrom,
            ),
          );
        },
      ),
      GoRoute(
        path: '/refund/:expenseId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final expenseId = state.pathParameters['expenseId']!;
          return CupertinoPage(
            key: state.pageKey,
            child: RefundFormPage(expenseId: expenseId),
          );
        },
      ),
      GoRoute(
        path: '/transaction/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return CupertinoPage(
            key: state.pageKey,
            child: TransactionFormPage(transactionId: id),
          );
        },
      ),
    ],
  );
});
