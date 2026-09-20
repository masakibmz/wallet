import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/application/services/transaction_recording_service.dart';
import 'package:wallet/data/repositories/local/account_local_repository.dart';
import 'package:wallet/data/repositories/local/attachment_local_repository.dart';
import 'package:wallet/data/repositories/local/category_local_repository.dart';
import 'package:wallet/data/repositories/local/ledger_local_repository.dart';
import 'package:wallet/data/repositories/local/tag_local_repository.dart';
import 'package:wallet/data/repositories/local/refund_local_repository.dart';
import 'package:wallet/data/repositories/local/reimbursement_local_repository.dart';
import 'package:wallet/data/repositories/local/repayment_local_repository.dart';
import 'package:wallet/data/repositories/local/transfer_local_repository.dart';
import 'package:wallet/data/repositories/local/transaction_local_repository.dart';
import 'package:wallet/services/accounting/accounting_service.dart';
import 'package:wallet/services/accounting/ledger_accounting_service.dart';
import 'package:wallet/data/repositories/sync/sync_repository.dart';
import 'package:wallet/domain/entities/ledger.dart';
import 'package:wallet/services/app_bootstrap_service.dart';
import 'package:wallet/services/ledger_onboarding_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be overridden at startup');
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return NoOpSyncRepository();
});

final ledgerOnboardingServiceProvider = Provider<LedgerOnboardingService>((ref) {
  return LedgerOnboardingService(ref.watch(appDatabaseProvider));
});

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final onboarding = ref.watch(ledgerOnboardingServiceProvider);
  return LedgerLocalRepository(
    db,
    onLedgerCreated: (id, currency) =>
        onboarding.onboard(id, currencyCode: currency),
  );
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountLocalRepository(ref.watch(appDatabaseProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryLocalRepository(ref.watch(appDatabaseProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagLocalRepository(ref.watch(appDatabaseProvider));
});

final accountingServiceProvider = Provider(
  (_) => const AccountingService(),
);

final ledgerAccountingServiceProvider = Provider<LedgerAccountingService>((ref) {
  return LedgerAccountingService(
    ref.watch(appDatabaseProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(accountingServiceProvider),
  );
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionLocalRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(accountRepositoryProvider),
    ref.watch(ledgerAccountingServiceProvider),
  );
});

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferLocalRepository(ref.watch(appDatabaseProvider));
});

final refundRepositoryProvider = Provider<RefundRepository>((ref) {
  return RefundLocalRepository(
    ref.watch(transactionRepositoryProvider),
    ref.watch(ledgerAccountingServiceProvider),
    ref.watch(accountingServiceProvider),
  );
});

final repaymentRepositoryProvider = Provider<RepaymentRepository>((ref) {
  return RepaymentLocalRepository(
    ref.watch(ledgerAccountingServiceProvider),
    ref.watch(transactionRepositoryProvider),
  );
});

final reimbursementRepositoryProvider = Provider<ReimbursementRepository>((ref) {
  return ReimbursementLocalRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(ledgerAccountingServiceProvider),
    ref.watch(transactionRepositoryProvider),
  );
});

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return AttachmentLocalRepository(ref.watch(appDatabaseProvider));
});

final transactionRecordingServiceProvider =
    Provider<TransactionRecordingService>((ref) {
  return TransactionRecordingService(
    ledger: ref.watch(ledgerAccountingServiceProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    refunds: ref.watch(refundRepositoryProvider),
    repayments: ref.watch(repaymentRepositoryProvider),
    reimbursements: ref.watch(reimbursementRepositoryProvider),
    attachments: ref.watch(attachmentRepositoryProvider),
  );
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final bootstrap = AppBootstrapService(
    db: ref.watch(appDatabaseProvider),
    ledgerRepository: ref.watch(ledgerRepositoryProvider),
    onboarding: ref.watch(ledgerOnboardingServiceProvider),
  );
  await bootstrap.initialize();
});

/// User-selected ledger; falls back to default ledger.
final selectedLedgerIdProvider = StateProvider<String?>((ref) => null);

final activeLedgersProvider = StreamProvider<List<Ledger>>((ref) {
  ref.watch(appBootstrapProvider);
  return ref.watch(ledgerRepositoryProvider).watchActiveLedgers();
});

final currentLedgerProvider = Provider<Ledger?>((ref) {
  final asyncLedgers = ref.watch(activeLedgersProvider);
  final selectedId = ref.watch(selectedLedgerIdProvider);
  return asyncLedgers.maybeWhen(
    data: (ledgers) {
      if (ledgers.isEmpty) {
        return null;
      }
      if (selectedId != null) {
        for (final ledger in ledgers) {
          if (ledger.id == selectedId) {
            return ledger;
          }
        }
      }
      return ledgers.firstWhere(
        (l) => l.isDefault,
        orElse: () => ledgers.first,
      );
    },
    orElse: () => null,
  );
});

void selectLedger(WidgetRef ref, String ledgerId) {
  ref.read(selectedLedgerIdProvider.notifier).state = ledgerId;
}
