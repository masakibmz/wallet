import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/application/providers/account_balance_providers.dart';
import 'package:wallet/application/providers/app_preferences_provider.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/application/transaction_recording/transaction_form_kind.dart';
import 'package:wallet/application/transaction_recording/transaction_recording_draft.dart';
import 'package:wallet/core/money/money_amount.dart';
import 'package:wallet/domain/accounting/account_classifier.dart';
import 'package:wallet/domain/entities/account.dart';
import 'package:wallet/domain/entities/ledger.dart';
import 'package:wallet/domain/entities/category.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/native/ios/ios_native_bridge.dart';
import 'package:wallet/presentation/features/transaction_form/widgets/account_picker_sheet.dart';
import 'package:wallet/presentation/features/transaction_form/widgets/category_picker_sheet.dart';
import 'package:wallet/presentation/features/transaction_form/widgets/attachment_picker.dart';
import 'package:wallet/presentation/features/transaction_form/widgets/category_icon_grid.dart';
import 'package:wallet/presentation/features/transaction_form/widgets/qianji_keypad.dart';
import 'package:wallet/presentation/features/transaction_form/widgets/transfer_account_cards.dart';
import 'package:wallet/presentation/features/settings/add_sub_category_page.dart';
import 'package:wallet/presentation/features/settings/category_manage_page.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/formatters.dart';
import 'package:intl/intl.dart';
import 'package:wallet/services/accounting/accounting_service.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({
    super.key,
    this.initialKind = TransactionFormKind.expense,
    this.transactionId,
    this.copyFromTransactionId,
  });

  final TransactionFormKind initialKind;
  final String? transactionId;
  final String? copyFromTransactionId;

  bool get isEditing => transactionId != null;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  late TransactionFormKind _kind;
  String _paidText = '';
  String _couponText = '';
  String _feeText = '';
  final _noteController = TextEditingController();
  final _reimbTargetController = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _subCategoryId;
  String? _originalExpenseId;
  final _tagIds = <String>{};
  final _attachmentPaths = <String>[];
  bool _reimbursementPending = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    if (widget.isEditing) {
      _loadTransaction(widget.transactionId!);
    } else if (widget.copyFromTransactionId != null) {
      _loadTransaction(widget.copyFromTransactionId!, asCopy: true);
    } else {
      _loading = false;
    }
  }

  Future<void> _loadTransaction(String id, {bool asCopy = false}) async {
    final tx = await ref.read(transactionRepositoryProvider).getById(id);
    if (tx == null || !mounted) {
      setState(() => _loading = false);
      return;
    }
    final paths = await ref
        .read(attachmentRepositoryProvider)
        .getLocalPaths(widget.transactionId!);
    setState(() {
      _kind = _kindFromType(tx.type);
      _paidText = MoneyAmount(
        minorUnits: tx.amountMinor,
        currencyCode: tx.currencyCode,
      ).format();
      _couponText = tx.couponMinor > 0
          ? MoneyAmount(
              minorUnits: tx.couponMinor,
              currencyCode: tx.currencyCode,
            ).format()
          : '';
      _feeText = tx.feeMinor > 0
          ? MoneyAmount(
              minorUnits: tx.feeMinor,
              currencyCode: tx.currencyCode,
            ).format()
          : '';
      _noteController.text = tx.note ?? '';
      _occurredAt = tx.occurredAt;
      _accountId = tx.accountId;
      _toAccountId = tx.toAccountId;
      _categoryId = tx.categoryId;
      _subCategoryId = tx.subCategoryId;
      _originalExpenseId = tx.originalTransactionId;
      _tagIds.addAll(tx.tagIds);
      _attachmentPaths.addAll(paths);
      _reimbursementPending =
          tx.reimbursementStatus == ReimbursementStatus.pending;
      _reimbTargetController.text = tx.reimbursementTarget ?? '';
      _loading = false;
    });
  }

  TransactionFormKind _kindFromType(TransactionType type) {
    return switch (type) {
      TransactionType.income => TransactionFormKind.income,
      TransactionType.transfer => TransactionFormKind.transfer,
      TransactionType.refund => TransactionFormKind.refund,
      TransactionType.creditRepayment => TransactionFormKind.creditRepayment,
      TransactionType.expense => TransactionFormKind.expense,
    };
  }

  @override
  void dispose() {
    _noteController.dispose();
    _reimbTargetController.dispose();
    super.dispose();
  }

  int _parseMinor(String text, String currency) {
    if (text.trim().isEmpty) {
      return 0;
    }
    return MoneyAmount.fromMajorString(text.trim(), currency).minorUnits;
  }

  void _leaveForm() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _save({bool recordAgain = false}) async {
    await ref.read(appBootstrapProvider.future);
    final ledger = ref.read(currentLedgerProvider);
    if (ledger == null) {
      await _alert('账本尚未就绪，请稍后再试');
      return;
    }
    final paidMinor = _parseMinor(_paidText, ledger.baseCurrencyCode);
    if (paidMinor <= 0) {
      await _alert('请输入金额');
      return;
    }
    if ((_kind == TransactionFormKind.expense ||
            _kind == TransactionFormKind.income) &&
        _categoryId == null) {
      await _alert('请选择分类');
      return;
    }

    setState(() => _saving = true);
    try {
      final draft = TransactionRecordingDraft(
        kind: _kind,
        ledgerId: ledger.id,
        currencyCode: ledger.baseCurrencyCode,
        paidAmountMinor: paidMinor,
        occurredAt: _occurredAt,
        accountId: _accountId,
        toAccountId: _toAccountId,
        categoryId: _categoryId,
        subCategoryId: _subCategoryId,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        feeMinor: _parseMinor(_feeText, ledger.baseCurrencyCode),
        couponMinor: _parseMinor(_couponText, ledger.baseCurrencyCode),
        tagIds: _tagIds.toList(growable: false),
        attachmentPaths: List.of(_attachmentPaths),
        reimbursementPending: _reimbursementPending && _kind == TransactionFormKind.expense,
        reimbursementAmountMinor: _reimbursementPending ? paidMinor : null,
        reimbursementTarget: _reimbTargetController.text.trim().isEmpty
            ? null
            : _reimbTargetController.text.trim(),
        originalExpenseId: _originalExpenseId,
        transactionId: widget.transactionId,
      );
      await ref.read(transactionRecordingServiceProvider).save(draft);
      await _persistCategoryAccountMemory(ledger.id);
      await IosNativeBridge.instance.hapticLight();
      if (!mounted) {
        return;
      }
      if (recordAgain && !widget.isEditing) {
        setState(() => _paidText = '');
      } else {
        _leaveForm();
      }
    } catch (e) {
      await _alert('$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (!widget.isEditing) {
      return;
    }
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('删除账单'),
        message: const Text('删除后余额与统计将恢复'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(transactionRecordingServiceProvider)
                  .delete(widget.transactionId!);
              if (mounted) {
                _leaveForm();
              }
            },
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
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

  Future<void> _pickDateTime() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        var temp = _occurredAt;
        return Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () {
                      setState(() => _occurredAt = DateTime.now());
                      Navigator.pop(ctx);
                    },
                    child: const Text('今天'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      final y = DateTime.now().subtract(const Duration(days: 1));
                      setState(
                        () => _occurredAt = DateTime(
                          y.year,
                          y.month,
                          y.day,
                          _occurredAt.hour,
                          _occurredAt.minute,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('昨天'),
                  ),
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

  int _balance(String accountId, String ledgerId) {
    final balances = ref.read(accountBalancesForLedgerProvider(ledgerId));
    return balances[accountId] ?? 0;
  }

  Color get _accentColor {
    return switch (_kind) {
      TransactionFormKind.income => QianjiColors.income,
      TransactionFormKind.expense ||
      TransactionFormKind.refund =>
        QianjiColors.expense,
      _ => QianjiColors.textPrimary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(currentLedgerProvider);
    if (_loading || ledger == null) {
      return const CupertinoPageScaffold(
        backgroundColor: QianjiColors.pageBackground,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final accounts = ref.watch(accountsForLedgerProvider(ledger.id));
    final txs = ref.watch(transactionsForLedgerProvider(ledger.id));
    final accent = _accentColor;
    final displayAmount = _paidText.isEmpty ? '0.00' : _paidText;

    return CupertinoPageScaffold(
      backgroundColor: QianjiColors.pageBackground,
      child: SafeArea(
        child: Column(
          children: [
            _qianjiTopBar(ledger.name),
            if (!widget.isEditing) _qianjiSegmentedControl(),
            Expanded(
              child: _buildMainBody(ledger, accounts, txs),
            ),
            _buildChipRow(ledger, accounts),
            Container(
              color: QianjiColors.cardBackground,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  const Text('#', style: TextStyle(color: QianjiColors.textSecondary)),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _noteController,
                      placeholder: '点此输入备注...',
                      decoration: null,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  Text(
                    displayAmount,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ledger.baseCurrencyCode} ›',
                    style: const TextStyle(
                      color: QianjiColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            QianjiKeypad(
              value: _paidText,
              onChanged: (v) => setState(() => _paidText = v),
              accentColor: accent,
              saving: _saving,
              onSave: () => _save(),
              onSaveAgain: widget.isEditing ? null : () => _save(recordAgain: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainBody(
    Ledger ledger,
    AsyncValue<List<Account>> accounts,
    AsyncValue<List<WalletTransaction>> txs,
  ) {
    if (_kind == TransactionFormKind.transfer ||
        _kind == TransactionFormKind.creditRepayment) {
      return accounts.when(
        data: (list) {
          Account? from;
          Account? to;
          for (final a in list) {
            if (a.id == _accountId) {
              from = a;
            }
            if (a.id == _toAccountId) {
              to = a;
            }
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                TransferAccountCards(
                  fromAccount: from,
                  toAccount: to,
                  fromBalanceMinor:
                      _accountId == null ? 0 : _balance(_accountId!, ledger.id),
                  toBalanceMinor:
                      _toAccountId == null ? 0 : _balance(_toAccountId!, ledger.id),
                  onPickFrom: () => _pickAccountSheet(list, ledger.id, true),
                  onPickTo: () => _pickAccountSheet(list, ledger.id, false),
                  onSwap: () {
                    setState(() {
                      final t = _accountId;
                      _accountId = _toAccountId;
                      _toAccountId = t;
                    });
                  },
                ),
                if (_kind == TransactionFormKind.creditRepayment)
                  accounts.when(
                    data: (l) => _repaymentPreview(l, ledger.id),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      );
    }

    if (_kind == TransactionFormKind.refund) {
      return txs.when(
        data: (list) => Column(
          children: [
            Expanded(child: _pickExpenseSection(txs)),
            _refundInfo(list, ledger.baseCurrencyCode),
          ],
        ),
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      );
    }

    final catAsync = _kind == TransactionFormKind.expense
        ? ref.watch(expenseCategoriesProvider(ledger.id))
        : ref.watch(incomeCategoriesProvider(ledger.id));

    return catAsync.when(
      data: (cats) {
        final accList = accounts.valueOrNull ?? const <Account>[];
        return CategoryIconGrid(
          categories: cats,
          selectedId: _categoryId,
          accentColor: _accentColor,
          onSelect: (c) =>
              _onCategorySelected(c, cats, ledger.id, accList),
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Widget _qianjiTopBar(String ledgerName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: _leaveForm,
            child: const Icon(CupertinoIcons.xmark, size: 22),
          ),
          Expanded(
            child: widget.isEditing
                ? const Text(
                    '修改账单',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: QianjiColors.textPrimary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: _showMoreKinds,
            child: const Icon(CupertinoIcons.add, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _qianjiSegmentedControl() {
    final segmentKind = _primaryKind;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: QianjiColors.chipBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _segmentTab('支出', TransactionFormKind.expense, segmentKind),
            _segmentTab('收入', TransactionFormKind.income, segmentKind),
            _segmentTab('转账', TransactionFormKind.transfer, segmentKind),
          ],
        ),
      ),
    );
  }

  Widget _segmentTab(String label, TransactionFormKind kind, TransactionFormKind selected) {
    final active = kind == selected;
    Color textColor;
    Color? bg;
    if (active) {
      bg = QianjiColors.cardBackground;
      textColor = kind == TransactionFormKind.income
          ? QianjiColors.income
          : kind == TransactionFormKind.expense
              ? QianjiColors.expense
              : QianjiColors.textPrimary;
    } else {
      textColor = QianjiColors.textSecondary;
    }
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _kind = kind;
          _categoryId = null;
          _subCategoryId = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textColor,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipRow(Ledger ledger, AsyncValue<List<Account>> accounts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          if (_kind != TransactionFormKind.transfer &&
              _kind != TransactionFormKind.creditRepayment)
            _chip(
              accounts.maybeWhen(
                data: (list) => _accountChipLabel(list),
                orElse: () => '选择账户',
              ),
              onTap: () {
                accounts.when(
                  data: (list) => _pickAccountSheet(list, ledger.id, true),
                  loading: () {},
                  error: (_, _) {},
                );
              },
            ),
          _chip(ledger.name, onTap: () {}),
          _chip(_timeChipLabel(), onTap: _pickDateTime),
          if (_kind == TransactionFormKind.expense)
            _chip(
              _reimbursementPending ? '待报销' : '报销',
              active: _reimbursementPending,
              onTap: () => setState(
                () => _reimbursementPending = !_reimbursementPending,
              ),
            ),
          _chip('图片', onTap: () async {
            final paths = await pickAttachmentPaths(context);
            if (paths.isNotEmpty) {
              setState(() => _attachmentPaths.addAll(paths));
            }
          }),
          if (_kind == TransactionFormKind.transfer ||
              _kind == TransactionFormKind.expense)
            _chip('手续费', onTap: () => _promptMinorField('手续费', _feeText, (v) {
              setState(() => _feeText = v);
            })),
          if (_kind == TransactionFormKind.expense)
            _chip('优惠券', onTap: () => _promptMinorField('优惠', _couponText, (v) {
              setState(() => _couponText = v);
            })),
        ],
      ),
    );
  }

  Widget _chip(String label, {VoidCallback? onTap, bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: active ? _accentColor.withValues(alpha: 0.15) : QianjiColors.chipBackground,
        borderRadius: BorderRadius.circular(16),
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? _accentColor : QianjiColors.textPrimary,
          ),
        ),
      ),
    );
  }

  String _accountChipLabel(List<Account> accounts) {
    for (final a in accounts) {
      if (a.id == _accountId) {
        return '${a.name} ${a.currencyCode}';
      }
    }
    return '选择账户';
  }

  String _timeChipLabel() {
    final now = DateTime.now();
    final isToday = _occurredAt.year == now.year &&
        _occurredAt.month == now.month &&
        _occurredAt.day == now.day;
    final time = DateFormat('HH:mm').format(_occurredAt);
    if (isToday) {
      return '今天 $time';
    }
    return DateFormat('M/d HH:mm').format(_occurredAt);
  }

  Future<void> _pickAccountSheet(
    List<Account> accounts,
    String ledgerId,
    bool isFrom,
  ) async {
    final visible = accounts.where((a) => !a.isHidden).toList();
    final id = await showAccountPickerSheet(
      context: context,
      accounts: visible,
      balanceMinor: (accountId) => _balance(accountId, ledgerId),
      selectedId: isFrom ? _accountId : _toAccountId,
      title: isFrom ? _accountLabelText : _toAccountLabel,
    );
    if (id != null) {
      setState(() {
        if (isFrom) {
          _accountId = id;
        } else {
          _toAccountId = id;
        }
      });
      if (isFrom) {
        await _persistCategoryAccountMemory(ledgerId);
      }
    }
  }

  String? get _categoryMemoryKey => _subCategoryId ?? _categoryId;

  Future<void> _applyAccountMemoryForCategory(
    String ledgerId,
    List<Account> accounts,
  ) async {
    if (_kind != TransactionFormKind.expense &&
        _kind != TransactionFormKind.income) {
      return;
    }
    final categoryKey = _categoryMemoryKey;
    if (categoryKey == null) {
      return;
    }
    final prefs = await ref.read(appPreferencesProvider.future);
    final remembered = prefs.getLastAccountForCategory(ledgerId, categoryKey);
    if (remembered == null) {
      return;
    }
    final exists = accounts.any((a) => a.id == remembered && !a.isHidden);
    if (!exists) {
      return;
    }
    if (mounted) {
      setState(() => _accountId = remembered);
    }
  }

  Future<void> _persistCategoryAccountMemory(String ledgerId) async {
    if (_kind != TransactionFormKind.expense &&
        _kind != TransactionFormKind.income) {
      return;
    }
    final categoryKey = _categoryMemoryKey;
    final accountId = _accountId;
    if (categoryKey == null || accountId == null) {
      return;
    }
    final prefs = await ref.read(appPreferencesProvider.future);
    await prefs.setLastAccountForCategory(
      ledgerId: ledgerId,
      categoryId: categoryKey,
      accountId: accountId,
    );
  }

  String get _accountLabelText => switch (_kind) {
        TransactionFormKind.transfer => '转出账户',
        TransactionFormKind.creditRepayment => '还款账户',
        TransactionFormKind.refund => '退款账户',
        _ => '账户',
      };

  Future<void> _onCategorySelected(
    Category c,
    List<Category> all,
    String ledgerId,
    List<Account> accounts,
  ) async {
    final subs = all.where((x) => x.parentId == c.id).toList();
    if (subs.isNotEmpty) {
      final sel = await showCategoryPickerSheet(
        context: context,
        categories: all,
        selectedTopId: c.id,
        selectedSubId: _subCategoryId,
      );
      if (sel != null) {
        setState(() {
          _categoryId = sel.categoryId;
          _subCategoryId = sel.subCategoryId;
        });
        await _applyAccountMemoryForCategory(ledgerId, accounts);
      }
      return;
    }
    setState(() {
      _categoryId = c.id;
      _subCategoryId = null;
    });
    await _applyAccountMemoryForCategory(ledgerId, accounts);
  }

  Future<void> _showMoreKinds() async {
    final ledger = ref.read(currentLedgerProvider);
    Category? parentForSub;
    if (ledger != null &&
        (_kind == TransactionFormKind.expense ||
            _kind == TransactionFormKind.income) &&
        _categoryId != null) {
      final all = await ref.read(categoryRepositoryProvider).getActiveCategories(
            ledger.id,
            isExpense: _kind == TransactionFormKind.expense,
          );
      Category? selected;
      for (final c in all) {
        if (c.id == _categoryId) {
          selected = c;
          break;
        }
      }
      if (selected != null) {
        if (selected.isTopLevel) {
          parentForSub = selected;
        } else {
          for (final p in all) {
            if (p.id == selected.parentId) {
              parentForSub = p;
              break;
            }
          }
        }
      }
    }

    if (!mounted) {
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (widget.isEditing)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDelete();
              },
              child: const Text('删除账单'),
            ),
          if (_kind == TransactionFormKind.expense ||
              _kind == TransactionFormKind.income) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const CategoryManagePage(),
                  ),
                );
              },
              child: const Text('分类管理'),
            ),
            if (parentForSub != null && ledger != null)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => AddSubCategoryPage(
                        ledgerId: ledger.id,
                        parent: parentForSub!,
                        isExpense: _kind == TransactionFormKind.expense,
                      ),
                    ),
                  );
                },
                child: const Text('添加二级分类'),
              ),
          ],
          if (!widget.isEditing) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _kind = TransactionFormKind.refund);
                Navigator.pop(ctx);
              },
              child: const Text('退款'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _kind = TransactionFormKind.creditRepayment);
                Navigator.pop(ctx);
              },
              child: const Text('信用卡还款'),
            ),
          ],
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _promptMinorField(
    String title,
    String current,
    void Function(String) onDone,
  ) async {
    final controller = TextEditingController(text: current);
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: CupertinoTextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: '0.00',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              onDone(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  TransactionFormKind get _primaryKind {
    if (_kind == TransactionFormKind.expense ||
        _kind == TransactionFormKind.income ||
        _kind == TransactionFormKind.transfer) {
      return _kind;
    }
    return TransactionFormKind.expense;
  }

  String get _toAccountLabel {
    return _kind == TransactionFormKind.creditRepayment ? '信用卡' : '转入账户';
  }

  Widget _pickExpenseSection(AsyncValue<List<WalletTransaction>> txs) {
    return txs.when(
      data: (list) {
        final expenses = list
            .where((t) => t.type == TransactionType.expense)
            .take(30)
            .toList();
        WalletTransaction? original;
        for (final t in expenses) {
          if (t.id == _originalExpenseId) {
            original = t;
          }
        }
        return CupertinoFormSection.insetGrouped(
          header: const Text('原支出'),
          children: [
            CupertinoListTile(
              title: const Text('选择原消费'),
              trailing: Text(
                original == null
                    ? '请选择'
                    : formatMinorAmount(
                        original.amountMinor,
                        original.currencyCode,
                      ),
              ),
              onTap: () async {
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (ctx) => CupertinoActionSheet(
                    title: const Text('选择支出账单'),
                    actions: [
                      for (final t in expenses)
                        CupertinoActionSheetAction(
                          onPressed: () {
                            setState(() {
                              _originalExpenseId = t.id;
                              _accountId = t.accountId;
                            });
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            '${formatMinorAmount(t.amountMinor, t.currencyCode)} '
                            '${t.note ?? ''}',
                          ),
                        ),
                    ],
                    cancelButton: CupertinoActionSheetAction(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _refundInfo(List<WalletTransaction> txs, String currency) {
    if (_originalExpenseId == null) {
      return const SizedBox.shrink();
    }
    WalletTransaction? original;
    for (final t in txs) {
      if (t.id == _originalExpenseId) {
        original = t;
      }
    }
    if (original == null) {
      return const SizedBox.shrink();
    }
    const accounting = AccountingService();
    final refunded = accounting.refundedTotalMinor(
      originalTransactionId: original.id,
      transactions: txs,
    );
    final remaining = accounting.refundableRemainingMinor(
      originalExpense: original,
      allTransactions: txs,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        '原消费 ${formatMinorAmount(original.amountMinor, currency)} · '
        '已退款 ${formatMinorAmount(refunded, currency)} · '
        '可退 ${formatMinorAmount(remaining, currency)}',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }

  Widget _repaymentPreview(List<Account> accounts, String ledgerId) {
    if (_toAccountId == null) {
      return const SizedBox.shrink();
    }
    Account? credit;
    for (final a in accounts) {
      if (a.id == _toAccountId) {
        credit = a;
      }
    }
    if (credit == null || !AccountClassifier.isLiability(credit.category)) {
      return const SizedBox.shrink();
    }
    final position = _balance(credit.id, ledgerId);
    final pay = _parseMinor(
      _paidText,
      credit.currencyCode,
    );
    final after = position - pay;
    String afterLabel;
    if (after > 0) {
      afterLabel = '欠款 ${formatMinorAmount(after, credit.currencyCode)}';
    } else if (after < 0) {
      afterLabel = '溢缴款 ${formatMinorAmount(after.abs(), credit.currencyCode)}';
    } else {
      afterLabel = '无欠款';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        '当前 ${_positionLabel(position, credit.currencyCode)} · '
        '本次 ${formatMinorAmount(pay, credit.currencyCode)} · '
        '还款后 $afterLabel',
        style: TextStyle(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }

  String _positionLabel(int positionMinor, String currency) {
    if (positionMinor > 0) {
      return '欠款 ${formatMinorAmount(positionMinor, currency)}';
    }
    if (positionMinor < 0) {
      return '溢缴款 ${formatMinorAmount(positionMinor.abs(), currency)}';
    }
    return '无欠款';
  }
}

String formatDateTime(DateTime time) {
  return '${time.year}-${_two(time.month)}-${_two(time.day)} '
      '${_two(time.hour)}:${_two(time.minute)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
