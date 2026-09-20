import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/repositories/local/account_local_repository.dart';
import 'package:wallet/data/repositories/local/category_local_repository.dart';
import 'package:wallet/data/repositories/local/ledger_local_repository.dart';
import 'package:wallet/data/repositories/local/tag_local_repository.dart';
import 'package:wallet/data/repositories/local/transaction_input.dart';
import 'package:wallet/data/repositories/local/transaction_local_repository.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/ledger_onboarding_service.dart';

void main() {
  late AppDatabase db;
  late LedgerLocalRepository ledgerRepo;
  late CategoryLocalRepository categoryRepo;
  late AccountLocalRepository accountRepo;
  late TagLocalRepository tagRepo;
  late TransactionLocalRepository transactionRepo;

  setUp(() async {
    db = AppDatabase.inMemory();
    ledgerRepo = LedgerLocalRepository(db);
    categoryRepo = CategoryLocalRepository(db);
    accountRepo = AccountLocalRepository(db);
    tagRepo = TagLocalRepository(db);
    transactionRepo = TransactionLocalRepository(db, accountRepo);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> setupLedger() async {
    await ledgerRepo.ensureDefaultLedger();
    final ledger = (await ledgerRepo.getDefaultLedger())!;
    await LedgerOnboardingService(db).onboard(ledger.id);
    return ledger.id;
  }

  test('onboarding creates categories and cash account', () async {
    final ledgerId = await setupLedger();
    final categories = await categoryRepo.getActiveCategories(ledgerId);
    final accounts = await accountRepo.getActiveAccounts(ledgerId);
    expect(categories.any((c) => c.name == '餐饮' && c.isTopLevel), isTrue);
    expect(categories.any((c) => c.name == '其他' && !c.isDeletable), isTrue);
    expect(accounts.single.name, '现金');
  });

  test('create expense transaction with tags', () async {
    final ledgerId = await setupLedger();
    final account = (await accountRepo.getActiveAccounts(ledgerId)).single;
    final food = (await categoryRepo.getActiveCategories(
      ledgerId,
      isExpense: true,
    ))
        .firstWhere((c) => c.name == '餐饮');
    final tag = await tagRepo.createTag(ledgerId: ledgerId, name: '工作');

    final tx = await transactionRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.expense,
        amountMinor: 3200,
        currencyCode: 'CNY',
        accountId: account.id,
        categoryId: food.id,
        occurredAt: DateTime(2026, 3, 20, 12, 30),
        note: '午饭',
        tagIds: [tag.id],
      ),
    );

    expect(tx.amountMinor, 3200);
    expect(tx.tagIds, [tag.id]);
    expect(await transactionRepo.watchTransactionCount(ledgerId: ledgerId).first,
        1);
  });

  test('cannot use hidden account for new transaction', () async {
    final ledgerId = await setupLedger();
    final account = (await accountRepo.getActiveAccounts(ledgerId)).single;
    await accountRepo.updateAccount(id: account.id, isHidden: true);

    expect(
      () => transactionRepo.createTransaction(
        CreateTransactionInput(
          ledgerId: ledgerId,
          type: TransactionType.expense,
          amountMinor: 100,
          currencyCode: 'CNY',
          accountId: account.id,
          occurredAt: DateTime.now(),
        ),
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('delete category reassigns transactions to 其他', () async {
    final ledgerId = await setupLedger();
    final account = (await accountRepo.getActiveAccounts(ledgerId)).single;
    final custom = await categoryRepo.createCategory(
      ledgerId: ledgerId,
      name: '临时分类',
      isExpense: true,
    );
    final tx = await transactionRepo.createTransaction(
      CreateTransactionInput(
        ledgerId: ledgerId,
        type: TransactionType.expense,
        amountMinor: 500,
        currencyCode: 'CNY',
        accountId: account.id,
        categoryId: custom.id,
        occurredAt: DateTime.now(),
      ),
    );

    await categoryRepo.deleteCategory(custom.id);
    final updated = (await transactionRepo.getById(tx.id))!;
    final fallback = await categoryRepo.getFallbackCategory(
      ledgerId: ledgerId,
      isExpense: true,
    );
    expect(updated.categoryId, fallback.id);
  });

  test('cannot delete system 其他 category', () async {
    final ledgerId = await setupLedger();
    final other = await categoryRepo.getFallbackCategory(
      ledgerId: ledgerId,
      isExpense: true,
    );
    expect(
      () => categoryRepo.deleteCategory(other.id),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('ledger setDefault and soft delete', () async {
    final firstId = await setupLedger();
    final second = await ledgerRepo.createLedger(name: '旅行账本');
    await ledgerRepo.setDefaultLedger(second.id);
    expect((await ledgerRepo.getDefaultLedger())!.id, second.id);

    await ledgerRepo.softDeleteLedger(firstId);
    final active = await ledgerRepo.getActiveLedgers();
    expect(active.length, 1);
    expect(active.single.id, second.id);
  });
}
