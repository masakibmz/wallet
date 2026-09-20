import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/services/transaction_summary_service.dart';

final transactionSummaryServiceProvider = Provider(
  (_) => const TransactionSummaryService(),
);

final reimbursementIncomeTransactionIdsProvider =
    FutureProvider.family<Set<String>, String>((ref, ledgerId) async {
  ref.watch(transactionsForLedgerProvider(ledgerId));
  return ref
      .read(reimbursementRepositoryProvider)
      .getIncomeTransactionIdsForLedger(ledgerId);
});
