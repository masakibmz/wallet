import 'package:csv/csv.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/presentation/utils/formatters.dart';

class CsvExportService {
  const CsvExportService();

  String exportTransactions(List<WalletTransaction> transactions) {
    final rows = <List<dynamic>>[
      ['id', 'type', 'amount', 'currency', 'occurred_at', 'note'],
      for (final tx in transactions)
        [
          tx.id,
          formatTransactionType(tx.type),
          MoneyAmountExport.minorToMajor(tx.amountMinor, tx.currencyCode),
          tx.currencyCode,
          tx.occurredAt.toIso8601String(),
          tx.note ?? '',
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }
}

/// Avoid importing money in service layer circular - duplicate tiny helper
abstract final class MoneyAmountExport {
  static String minorToMajor(int minor, String code) {
    final scale = code == 'JPY' || code == 'KRW' ? 0 : 2;
    if (scale == 0) {
      return '$minor';
    }
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    final whole = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    return '$sign$whole.$frac';
  }
}
