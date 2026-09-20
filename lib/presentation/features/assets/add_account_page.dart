import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/core/money/money_amount.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/features/assets/account_type_catalog.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/account_icons.dart';

class AddAccountPage extends ConsumerStatefulWidget {
  const AddAccountPage({super.key, required this.category});

  final AccountCategory category;

  @override
  ConsumerState<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends ConsumerState<AddAccountPage> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _balanceController = TextEditingController(text: '0.00');
  bool _includeInTotal = true;
  String _currency = 'CNY';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ledger = ref.read(currentLedgerProvider);
    if (ledger == null) {
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await _alert('请输入账户名称');
      return;
    }
    final balanceMinor = MoneyAmount.fromMajorString(
      _balanceController.text.trim().isEmpty
          ? '0'
          : _balanceController.text.trim(),
      _currency,
    ).minorUnits;

    setState(() => _saving = true);
    try {
      await ref.read(accountRepositoryProvider).createAccount(
            ledgerId: ledger.id,
            name: name,
            category: widget.category,
            currencyCode: _currency,
            initialBalanceMinor: balanceMinor,
            includeInTotal: _includeInTotal,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
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

  Future<void> _alert(String msg) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(msg),
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
    final label = accountCategoryLabel(widget.category);
    final style = accountIconStyleFor(widget.category);

    return CupertinoPageScaffold(
      backgroundColor: QianjiColors.pageBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text('添加资产-$label'),
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
                  _card(
                    children: [
                      _row(
                        label: '账户类型',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: style.bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                style.icon,
                                size: 16,
                                color: style.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(label),
                            const Icon(CupertinoIcons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                      _divider(),
                      _inputRow(
                        label: '名称',
                        controller: _nameController,
                        placeholder: '点此输入...',
                      ),
                      _divider(),
                      _inputRow(
                        label: '备注（可不填）',
                        controller: _noteController,
                        placeholder: '点此输入...',
                      ),
                      _divider(),
                      _row(
                        label: '所属分组',
                        trailing: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('默认'),
                            Icon(CupertinoIcons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _card(
                    children: [
                      _inputRow(
                        label: '账户余额',
                        controller: _balanceController,
                        placeholder: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        alignRight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _card(
                    children: [
                      _row(
                        label: '币种',
                        subtitle: '此账户下的账单，将会以此币种来记录',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_currency),
                            const Icon(CupertinoIcons.chevron_right, size: 16),
                          ],
                        ),
                        onTap: () {},
                      ),
                      _divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('是否计入总资产'),
                                  SizedBox(height: 4),
                                  Text(
                                    '开启后，账户余额将计入总资产',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: QianjiColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: _includeInTotal,
                              onChanged: (v) =>
                                  setState(() => _includeInTotal = v),
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

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 16),
      color: QianjiColors.divider,
    );
  }

  Widget _row({
    required String label,
    String? subtitle,
    required Widget trailing,
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
                Text(label),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: QianjiColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _inputRow({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    bool alignRight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              decoration: null,
              keyboardType: keyboardType,
              textAlign: alignRight ? TextAlign.right : TextAlign.start,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
