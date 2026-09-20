import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/transaction_search_service.dart';

void main() {
  const service = TransactionSearchService();
  final now = DateTime(2026, 8, 15);

  WalletTransaction tx({
    int amount = 100,
    String? note,
    TransactionType type = TransactionType.expense,
  }) {
    return WalletTransaction(
      id: '1',
      ledgerId: 'l',
      type: type,
      amountMinor: amount,
      currencyCode: 'CNY',
      occurredAt: now,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('filters by amount range and keyword', () {
    final result = service.filter(
      [
        tx(amount: 100, note: '麦当劳'),
        tx(amount: 400, note: '超市'),
      ],
      const TransactionSearchQuery(
        minAmountMinor: 100,
        maxAmountMinor: 300,
        keyword: '麦当',
      ),
    );
    expect(result.length, 1);
    expect(result.first.note, '麦当劳');
  });
}
