import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/application/services/transaction_recording_service.dart';
import 'package:wallet/application/transaction_recording/transaction_form_kind.dart';
import 'package:wallet/application/transaction_recording/transaction_recording_draft.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/repositories/local/account_local_repository.dart';
import 'package:wallet/data/repositories/local/category_local_repository.dart';
import 'package:wallet/data/repositories/local/attachment_local_repository.dart';
import 'package:wallet/data/repositories/local/ledger_local_repository.dart';
import 'package:wallet/data/repositories/local/refund_local_repository.dart';
import 'package:wallet/data/repositories/local/reimbursement_local_repository.dart';
import 'package:wallet/data/repositories/local/repayment_local_repository.dart';
import 'package:wallet/data/repositories/local/transaction_local_repository.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/accounting/accounting_service.dart';
import 'package:wallet/services/accounting/ledger_accounting_service.dart';
import 'package:wallet/services/ledger_onboarding_service.dart';

void main() {
  late AppDatabase db;
  late TransactionRecordingService recording;
  late TransactionLocalRepository txRepo;
  late String ledgerId;
  late String cashId;
  late String bankId;
  late String creditId;
  late String expenseCategoryId;

  setUp(() async {
    db = AppDatabase.inMemory();
    final accountRepo = AccountLocalRepository(db);
    const accounting = AccountingService();
    final ledger = LedgerAccountingService(db, accountRepo, accounting);
    txRepo = TransactionLocalRepository(db, accountRepo, ledger);
    recording = TransactionRecordingService(
      ledger: ledger,
      transactions: txRepo,
      refunds: RefundLocalRepository(txRepo, ledger, accounting),
      repayments: RepaymentLocalRepository(ledger, txRepo),
      reimbursements: ReimbursementLocalRepository(db, ledger, txRepo),
      attachments: AttachmentLocalRepository(db),
    );

    final ledgerRepo = LedgerLocalRepository(db);
    await ledgerRepo.ensureDefaultLedger();
    ledgerId = (await ledgerRepo.getDefaultLedger())!.id;
    await LedgerOnboardingService(db).onboard(ledgerId);
    cashId = (await accountRepo.getActiveAccounts(ledgerId)).single.id;
    bankId = await accountRepo.createAccount(
      ledgerId: ledgerId,
      name: '银行卡',
      category: AccountCategory.bank,
      currencyCode: 'CNY',
      initialBalanceMinor: 50000,
    ).then((a) => a.id);
    creditId = await accountRepo.createAccount(
      ledgerId: ledgerId,
      name: '信用卡',
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
    ).then((a) => a.id);
    final categories = await CategoryLocalRepository(db)
        .getActiveCategories(ledgerId, isExpense: true);
    expenseCategoryId = categories.firstWhere((c) => c.parentId == null).id;
  });

  tearDown(() async {
    await db.close();
  });

  test('expense with coupon fee tags attachment', () async {
    final tx = await recording.save(
      TransactionRecordingDraft(
        kind: TransactionFormKind.expense,
        ledgerId: ledgerId,
        currencyCode: 'CNY',
        paidAmountMinor: 8000,
        couponMinor: 2000,
        feeMinor: 300,
        occurredAt: DateTime.utc(2026, 2, 1),
        accountId: cashId,
        categoryId: expenseCategoryId,
        tagIds: const [],
        attachmentPaths: const ['/tmp/receipt.jpg'],
      ),
    );
    expect(tx.amountMinor, 8000);
    expect(tx.couponMinor, 2000);
    expect(tx.feeMinor, 300);
    final paths = await AttachmentLocalRepository(db).getLocalPaths(tx.id);
    expect(paths, ['/tmp/receipt.jpg']);
  });

  test('transfer and refund and repayment', () async {
    await recording.save(
      TransactionRecordingDraft(
        kind: TransactionFormKind.transfer,
        ledgerId: ledgerId,
        currencyCode: 'CNY',
        paidAmountMinor: 10000,
        feeMinor: 100,
        occurredAt: DateTime.utc(2026, 2, 1),
        accountId: bankId,
        toAccountId: cashId,
      ),
    );
    final expense = await recording.save(
      TransactionRecordingDraft(
        kind: TransactionFormKind.expense,
        ledgerId: ledgerId,
        currencyCode: 'CNY',
        paidAmountMinor: 5000,
        occurredAt: DateTime.utc(2026, 2, 2),
        accountId: cashId,
        categoryId: expenseCategoryId,
      ),
    );
    await recording.save(
      TransactionRecordingDraft(
        kind: TransactionFormKind.refund,
        ledgerId: ledgerId,
        currencyCode: 'CNY',
        paidAmountMinor: 2000,
        occurredAt: DateTime.utc(2026, 2, 3),
        accountId: cashId,
        originalExpenseId: expense.id,
      ),
    );
    await recording.save(
      TransactionRecordingDraft(
        kind: TransactionFormKind.creditRepayment,
        ledgerId: ledgerId,
        currencyCode: 'CNY',
        paidAmountMinor: 3000,
        occurredAt: DateTime.utc(2026, 2, 4),
        accountId: bankId,
        toAccountId: creditId,
      ),
    );
    expect(await txRepo.watchTransactionCount(ledgerId: ledgerId).first, 4);
  });

  test('reimbursement pending and edit delete', () async {
    final tx = await recording.save(
      TransactionRecordingDraft(
        kind: TransactionFormKind.expense,
        ledgerId: ledgerId,
        currencyCode: 'CNY',
        paidAmountMinor: 10000,
        occurredAt: DateTime.utc(2026, 2, 1),
        accountId: cashId,
        categoryId: expenseCategoryId,
        reimbursementPending: true,
        reimbursementTarget: '公司',
      ),
    );
    expect(tx.reimbursementStatus, ReimbursementStatus.pending);
    final updated = await recording.save(
      TransactionRecordingDraft(
        kind: TransactionFormKind.expense,
        ledgerId: ledgerId,
        currencyCode: 'CNY',
        paidAmountMinor: 12000,
        occurredAt: DateTime.utc(2026, 2, 1),
        accountId: cashId,
        categoryId: expenseCategoryId,
        transactionId: tx.id,
      ),
    );
    expect(updated.amountMinor, 12000);
    await recording.delete(tx.id);
    expect(await txRepo.getById(tx.id), isNull);
  });
}
