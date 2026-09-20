import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/domain/entities/account.dart';
import 'package:wallet/domain/entities/category.dart';
import 'package:wallet/domain/entities/tag.dart';
import 'package:wallet/domain/entities/transaction.dart';

final accountsForLedgerProvider =
    StreamProvider.family<List<Account>, String>((ref, ledgerId) {
  ref.watch(appBootstrapProvider);
  return ref.watch(accountRepositoryProvider).watchActiveAccounts(ledgerId);
});

final expenseCategoriesProvider =
    StreamProvider.family<List<Category>, String>((ref, ledgerId) {
  ref.watch(appBootstrapProvider);
  return ref
      .watch(categoryRepositoryProvider)
      .watchActiveCategories(ledgerId, isExpense: true);
});

final incomeCategoriesProvider =
    StreamProvider.family<List<Category>, String>((ref, ledgerId) {
  ref.watch(appBootstrapProvider);
  return ref
      .watch(categoryRepositoryProvider)
      .watchActiveCategories(ledgerId, isExpense: false);
});

final tagsForLedgerProvider =
    StreamProvider.family<List<Tag>, String>((ref, ledgerId) {
  ref.watch(appBootstrapProvider);
  return ref.watch(tagRepositoryProvider).watchActiveTags(ledgerId);
});

final transactionsForLedgerProvider =
    StreamProvider.family<List<WalletTransaction>, String>((ref, ledgerId) {
  ref.watch(appBootstrapProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactions(ledgerId: ledgerId);
});
