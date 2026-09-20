import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/core/money/money_amount.dart';
import 'package:wallet/data/repositories/local/transaction_input.dart';
import 'package:wallet/services/ai/ai_transaction_parser.dart';
import 'package:wallet/services/ai/transaction_draft.dart';

final aiParserProvider = Provider<AiTransactionParser>(
  (_) => MockAiTransactionParser(),
);

class AiDraftSheet extends ConsumerStatefulWidget {
  const AiDraftSheet({super.key});

  @override
  ConsumerState<AiDraftSheet> createState() => _AiDraftSheetState();
}

class _AiDraftSheetState extends ConsumerState<AiDraftSheet> {
  final _input = TextEditingController(text: '午饭麦当劳32');
  TransactionDraft? _draft;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final draft = await ref.read(aiParserProvider).parse(_input.text);
    setState(() => _draft = draft);
  }

  Future<void> _confirm() async {
    final draft = _draft;
    final ledger = ref.read(currentLedgerProvider);
    if (draft == null || ledger == null) {
      return;
    }
    final accounts =
        await ref.read(accountRepositoryProvider).getActiveAccounts(ledger.id);
    final cats = await ref
        .read(categoryRepositoryProvider)
        .getActiveCategories(ledger.id, isExpense: true);
    final food = cats.firstWhere(
      (c) => c.name == '餐饮' && c.isTopLevel,
      orElse: () => cats.firstWhere((c) => c.isTopLevel),
    );
    await ref.read(transactionRepositoryProvider).createTransaction(
          CreateTransactionInput(
            ledgerId: ledger.id,
            type: draft.type,
            amountMinor: draft.amountMinor,
            currencyCode: draft.currencyCode,
            accountId: accounts.first.id,
            categoryId: food.id,
            occurredAt: draft.occurredAt ?? DateTime.now(),
            note: draft.note,
          ),
        );
    if (mounted) {
      Navigator.pop(context);
      context.go('/transactions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('AI 记账（Mock）'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _parse,
          child: const Text('解析'),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoTextField(
                controller: _input,
                placeholder: '午饭麦当劳32',
              ),
              const SizedBox(height: 16),
              if (_draft != null) ...[
                Text(
                  '金额 ${MoneyAmount(minorUnits: _draft!.amountMinor, currencyCode: _draft!.currencyCode).format()}',
                ),
                Text('类型 ${_draft!.type.name}'),
                Text('备注 ${_draft!.note ?? ''}'),
                const SizedBox(height: 12),
                CupertinoButton.filled(
                  onPressed: _confirm,
                  child: const Text('确认写入数据库'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
