import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/csv_export_service.dart';

void main() {
  test('exportTransactions includes header and row', () {
    final now = DateTime.utc(2026, 1, 1);
    const service = CsvExportService();
    final csv = service.exportTransactions([
      WalletTransaction(
        id: 'abc',
        ledgerId: 'l',
        type: TransactionType.expense,
        amountMinor: 3200,
        currencyCode: 'CNY',
        occurredAt: now,
        note: '午饭',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    expect(csv.contains('id,type,amount'), isTrue);
    expect(csv.contains('abc'), isTrue);
    expect(csv.contains('32.00'), isTrue);
  });
}
