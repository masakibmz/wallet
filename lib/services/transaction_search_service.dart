import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class TransactionSearchQuery {
  const TransactionSearchQuery({
    this.keyword,
    this.minAmountMinor,
    this.maxAmountMinor,
    this.types = const [],
    this.accountId,
    this.categoryId,
    this.tagId,
    this.from,
    this.to,
  });

  final String? keyword;
  final int? minAmountMinor;
  final int? maxAmountMinor;
  final List<TransactionType> types;
  final String? accountId;
  final String? categoryId;
  final String? tagId;
  final DateTime? from;
  final DateTime? to;
}

class TransactionSearchService {
  const TransactionSearchService();

  List<WalletTransaction> filter(
    List<WalletTransaction> source,
    TransactionSearchQuery query,
  ) {
    return source.where((tx) {
      if (query.types.isNotEmpty && !query.types.contains(tx.type)) {
        return false;
      }
      if (query.minAmountMinor != null &&
          tx.amountMinor < query.minAmountMinor!) {
        return false;
      }
      if (query.maxAmountMinor != null &&
          tx.amountMinor > query.maxAmountMinor!) {
        return false;
      }
      if (query.accountId != null && tx.accountId != query.accountId) {
        return false;
      }
      if (query.categoryId != null &&
          tx.categoryId != query.categoryId &&
          tx.subCategoryId != query.categoryId) {
        return false;
      }
      if (query.tagId != null && !tx.tagIds.contains(query.tagId)) {
        return false;
      }
      if (query.from != null && tx.occurredAt.isBefore(query.from!)) {
        return false;
      }
      if (query.to != null && tx.occurredAt.isAfter(query.to!)) {
        return false;
      }
      if (query.keyword != null && query.keyword!.trim().isNotEmpty) {
        final k = query.keyword!.toLowerCase();
        final note = tx.note?.toLowerCase() ?? '';
        if (!note.contains(k)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }
}
