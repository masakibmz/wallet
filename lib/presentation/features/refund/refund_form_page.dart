import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wallet/application/providers/account_balance_providers.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/domain/entities/account.dart';
import 'package:wallet/application/transaction_recording/transaction_recording_draft.dart';
import 'package:wallet/application/transaction_recording/transaction_form_kind.dart';
import 'package:wallet/core/money/money_amount.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/native/ios/ios_native_bridge.dart';
import 'package:wallet/presentation/features/transaction_form/widgets/account_picker_sheet.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/category_icons.dart';
import 'package:wallet/presentation/utils/formatters.dart';
import 'package:wallet/services/accounting/accounting_service.dart';

class RefundFormPage extends ConsumerStatefulWidget {
  const RefundFormPage({super.key, required this.expenseId});

  final String expenseId;

  @override
  ConsumerState<RefundFormPage> createState() => _RefundFormPageState();
}

class _RefundFormPageState extends ConsumerState<RefundFormPage> {
  WalletTransaction? _original;
  String? _accountId;
  DateTime _occurredAt = DateTime.now();
  String _amountText = '';
  final _noteController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tx = await ref
        .read(transactionRepositoryProvider)
        .getById(widget.expenseId);
    if (!mounted) {
      return;
    }
    if (tx == null || tx.type != TransactionType.expense) {
      setState(() => _loading = false);
      return;
    }
    final accounting = const AccountingService();
    final all = await ref
        .read(transactionRepositoryProvider)
        .getTransactions(ledgerId: tx.ledgerId);
    final remaining = accounting.refundableRemainingMinor(
      originalExpense: tx,
      allTransactions: all,
    );
    setState(() {
      _original = tx;
      _accountId = tx.accountId;
      _amountText = MoneyAmount(
        minorUnits: remaining,
        currencyCode: tx.currencyCode,
      ).format();
      _loading = false;
    });
  }

  Future<void> _pickAccount(String ledgerId, List<Account> accounts) async {
    final balances = ref.read(accountBalancesForLedgerProvider(ledgerId));
    final id = await showAccountPickerSheet(
      context: context,
      accounts: accounts,
      selectedId: _accountId,
      balanceMinor: (accountId) => balances[accountId] ?? 0,
    );
    if (id != null && mounted) {
      setState(() => _accountId = id);
    }
  }

  Future<void> _pickDateTime() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        var temp = _occurredAt;
        return Container(
          height: 280,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () {
                      setState(() => _occurredAt = temp);
                      Navigator.pop(ctx);
                    },
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _occurredAt,
                  onDateTimeChanged: (v) => temp = v,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final original = _original;
    final ledger = ref.read(currentLedgerProvider);
    if (original == null || ledger == null) {
      return;
    }
    final minor = MoneyAmount.fromMajorString(
      _amountText.trim().isEmpty ? '0' : _amountText.trim(),
      original.currencyCode,
    ).minorUnits;
    if (minor <= 0) {
      await _alert('请输入退款金额');
      return;
    }

    setState(() => _saving = true);
    try {
      final draft = TransactionRecordingDraft(
        kind: TransactionFormKind.refund,
        ledgerId: ledger.id,
        currencyCode: original.currencyCode,
        paidAmountMinor: minor,
        occurredAt: _occurredAt,
        accountId: _accountId,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        originalExpenseId: original.id,
      );
      await ref.read(transactionRecordingServiceProvider).save(draft);
      await IosNativeBridge.instance.hapticLight();
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      await _alert('$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _alert(String message) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    final original = _original;
    if (original == null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('添加退款'),
        ),
        child: const Center(child: Text('原账单不存在或不可退款')),
      );
    }

    final categories = ref.watch(expenseCategoriesProvider(original.ledgerId));
    final accounts = ref.watch(accountsForLedgerProvider(original.ledgerId));
    final catName = categories.maybeWhen(
      data: (c) {
        for (final x in c) {
          if (x.id == (original.subCategoryId ?? original.categoryId)) {
            return x.name;
          }
        }
        return null;
      },
      orElse: () => null,
    );
    final accName = accounts.maybeWhen(
      data: (a) {
        for (final x in a) {
          if (x.id == original.accountId) {
            return x.name;
          }
        }
        return null;
      },
      orElse: () => null,
    );
    final refundAccName = accounts.maybeWhen(
      data: (a) {
        for (final x in a) {
          if (x.id == _accountId) {
            return x.name;
          }
        }
        return '选择账户';
      },
      orElse: () => '选择账户',
    );

    return CupertinoPageScaffold(
      backgroundColor: QianjiColors.pageBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('添加退款'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('原账单'),
                  _card(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: QianjiColors.expenseSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            categoryIconFor(catName ?? '其他'),
                            color: QianjiColors.expense,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            catName ?? '支出',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '-${formatMinorAmount(original.amountMinor, original.currencyCode)}',
                              style: const TextStyle(
                                color: QianjiColors.expense,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (accName != null)
                              Text(
                                accName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: QianjiColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('退款信息'),
                  _card(
                    children: [
                      _tappableRow(
                        title: '入账账户',
                        subtitle: '金额退入哪个账户',
                        value: refundAccName,
                        onTap: accounts.maybeWhen(
                          data: (list) =>
                              () => _pickAccount(original.ledgerId, list),
                          orElse: () => null,
                        ),
                      ),
                      _divider(),
                      _tappableRow(
                        title: '退款时间',
                        value: DateFormat('yyyy-MM-dd HH:mm')
                            .format(_occurredAt.toLocal()),
                        onTap: _pickDateTime,
                      ),
                      _divider(),
                      _tappableRow(
                        title: '退款金额',
                        value: _amountText,
                        onTap: () => _editAmount(original.currencyCode),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _card(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 72,
                              child: Text(
                                '备注',
                                style: TextStyle(
                                  color: QianjiColors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: CupertinoTextField(
                                controller: _noteController,
                                placeholder: '点此输入备注...',
                                decoration: null,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CupertinoActivityIndicator()
                      : const Text('保存'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAmount(String currency) async {
    final controller = TextEditingController(text: _amountText);
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('退款金额'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              setState(() => _amountText = controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: QianjiColors.textSecondary,
        ),
      ),
    );
  }

  Widget _card({Widget? child, List<Widget>? children}) {
    return Container(
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child ?? Column(children: children!),
    );
  }

  Widget _divider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 16),
      color: QianjiColors.chipBackground,
    );
  }

  Widget _tappableRow({
    required String title,
    String? subtitle,
    required String value,
    VoidCallback? onTap,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: QianjiColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: QianjiColors.textSecondary),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: QianjiColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
