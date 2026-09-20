import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/ai/transaction_draft.dart';

/// Parses natural language into a draft — never writes to the database.
abstract class AiTransactionParser {
  Future<TransactionDraft?> parse(String input);
}

/// Phase 9 mock — replace with remote AI in a later phase.
class MockAiTransactionParser implements AiTransactionParser {
  @override
  Future<TransactionDraft?> parse(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*$').firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final major = match.group(1)!;
    final amountMinor =
        (double.parse(major) * 100).round(); // CNY 2 decimals
    final note = trimmed.substring(0, match.start).trim();
    return TransactionDraft(
      type: TransactionType.expense,
      amountMinor: amountMinor,
      currencyCode: 'CNY',
      categoryHint: note.contains('麦当') ? '餐饮' : null,
      note: note.isEmpty ? null : note,
      occurredAt: DateTime.now(),
    );
  }
}
