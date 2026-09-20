import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/services/account_balance_service.dart';

final accountBalanceServiceProvider = Provider(
  (_) => const AccountBalanceService(),
);

final accountBalancesForLedgerProvider =
    Provider.family<Map<String, int>, String>((ref, ledgerId) {
  final accounts = ref.watch(accountsForLedgerProvider(ledgerId)).valueOrNull;
  final txs = ref.watch(transactionsForLedgerProvider(ledgerId)).valueOrNull;
  if (accounts == null || txs == null) {
    return const {};
  }
  final service = ref.watch(accountBalanceServiceProvider);
  final natureMap = service.natureMapForAccounts(accounts);
  return {
    for (final a in accounts)
      a.id: service.balanceMinor(
        initialBalanceMinor: a.initialBalanceMinor,
        accountId: a.id,
        transactions: txs,
        natureByAccountId: natureMap,
      ),
  };
});
