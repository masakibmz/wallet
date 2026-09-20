import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/domain/accounting/account_classifier.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/account_balance_service.dart';

void main() {
  const service = AccountBalanceService();
  const accountId = 'acc-1';
  const otherAccount = 'acc-2';

  WalletTransaction tx({
    required TransactionType type,
    required int amount,
    String? to,
    int fee = 0,
  }) {
    final now = DateTime.utc(2026, 1, 1);
    return WalletTransaction(
      id: 't-$amount-$type',
      ledgerId: 'l1',
      type: type,
      amountMinor: amount,
      currencyCode: 'CNY',
      accountId: accountId,
      toAccountId: to,
      occurredAt: now,
      feeMinor: fee,
      createdAt: now,
      updatedAt: now,
    );
  }

  final nature = {accountId: AccountNature.asset, otherAccount: AccountNature.asset};

  test('expense and income adjust balance', () {
    final balance = service.balanceMinor(
      initialBalanceMinor: 10000,
      accountId: accountId,
      transactions: [
        tx(type: TransactionType.expense, amount: 3200),
        tx(type: TransactionType.income, amount: 5000),
      ],
      natureByAccountId: nature,
    );
    expect(balance, 11800);
  });

  test('transfer moves balance between accounts', () {
    final fromBalance = service.balanceMinor(
      initialBalanceMinor: 10000,
      accountId: accountId,
      transactions: [
        tx(type: TransactionType.transfer, amount: 3000, to: otherAccount),
      ],
      natureByAccountId: nature,
    );
    final toBalance = service.balanceMinor(
      initialBalanceMinor: 0,
      accountId: otherAccount,
      transactions: [
        WalletTransaction(
          id: 't2',
          ledgerId: 'l1',
          type: TransactionType.transfer,
          amountMinor: 3000,
          currencyCode: 'CNY',
          accountId: accountId,
          toAccountId: otherAccount,
          occurredAt: DateTime.utc(2026, 1, 1),
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      natureByAccountId: nature,
    );
    expect(fromBalance, 7000);
    expect(toBalance, 3000);
  });

  test('expense includes fee in minor units', () {
    final balance = service.balanceMinor(
      initialBalanceMinor: 1000,
      accountId: accountId,
      transactions: [
        tx(type: TransactionType.expense, amount: 100, fee: 50),
      ],
      natureByAccountId: nature,
    );
    expect(balance, 850);
  });
}
