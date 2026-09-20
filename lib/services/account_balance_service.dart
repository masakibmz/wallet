import 'package:wallet/domain/accounting/account_classifier.dart';

import 'package:wallet/domain/accounting/accounting_models.dart';

import 'package:wallet/domain/entities/account.dart';

import 'package:wallet/domain/entities/transaction.dart';

import 'package:wallet/domain/enums/app_enums.dart';

import 'package:wallet/services/accounting/accounting_service.dart';



/// Computes balances from ledger transactions via [AccountingService].

class AccountBalanceService {

  const AccountBalanceService([this._accounting = const AccountingService()]);



  final AccountingService _accounting;



  int balanceMinor({

    required int initialBalanceMinor,

    required String accountId,

    required Iterable<WalletTransaction> transactions,

    AccountCategory? accountCategory,

    Map<String, AccountNature>? natureByAccountId,

  }) {

    final natureMap = natureByAccountId ??

        {

          if (accountCategory != null)

            accountId: AccountClassifier.natureOf(accountCategory),

        };

    final nature = natureMap[accountId] ?? AccountNature.asset;

    if (nature == AccountNature.liability) {

      return _accounting

          .liabilitySnapshot(

            initialBalanceMinor: initialBalanceMinor,

            accountId: accountId,

            transactions: transactions,

            natureByAccountId: natureMap,

          )

          .positionMinor;

    }

    return _accounting.assetBalanceMinor(

      initialBalanceMinor: initialBalanceMinor,

      accountId: accountId,

      transactions: transactions,

      natureByAccountId: natureMap,

    );

  }



  LiabilitySnapshot liabilitySnapshot({

    required Account account,

    required Iterable<WalletTransaction> transactions,

    required Map<String, AccountNature> natureByAccountId,

  }) {

    return _accounting.liabilitySnapshot(

      initialBalanceMinor: account.initialBalanceMinor,

      accountId: account.id,

      transactions: transactions,

      natureByAccountId: natureByAccountId,

    );

  }



  Map<String, AccountNature> natureMapForAccounts(Iterable<Account> accounts) {

    return {

      for (final a in accounts)

        a.id: AccountClassifier.natureOf(a.category),

    };

  }

}


