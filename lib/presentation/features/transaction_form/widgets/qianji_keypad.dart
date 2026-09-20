import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';

class QianjiKeypad extends StatelessWidget {
  const QianjiKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accentColor,
    required this.onSave,
    this.onSaveAgain,
    this.saving = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final Color accentColor;
  final VoidCallback onSave;
  final VoidCallback? onSaveAgain;
  final bool saving;

  void _tap(String key) {
    HapticFeedback.lightImpact();
    var next = value;
    if (key == 'del') {
      if (next.isEmpty) {
        return;
      }
      onChanged(next.substring(0, next.length - 1));
      return;
    }
    if (key == '+' || key == '-') {
      return;
    }
    if (key == '.') {
      if (next.contains('.')) {
        return;
      }
      onChanged(next.isEmpty ? '0.' : '$next.');
      return;
    }
    if (next.contains('.')) {
      final frac = next.split('.').last;
      if (frac.length >= 2) {
        return;
      }
    }
    next = next == '0' ? key : '$next$key';
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: QianjiColors.chipBackground,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: Column(
        children: [
          _row(['1', '2', '3', 'del']),
          _row(['4', '5', '6', '-']),
          _row(['7', '8', '9', '+']),
          Row(
            children: [
              _key(
                label: '再记',
                flex: 1,
                onTap: saving ? null : onSaveAgain ?? onSave,
                textStyle: const TextStyle(fontSize: 15),
              ),
              _key(label: '.', flex: 1, onTap: () => _tap('.')),
              _key(label: '0', flex: 1, onTap: () => _tap('0')),
              _key(
                label: '保存',
                flex: 1,
                onTap: saving ? null : onSave,
                textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> keys) {
    return Row(
      children: [
        for (final k in keys)
          _key(
            label: k == 'del' ? '⌫' : k,
            flex: 1,
            onTap: () => _tap(k),
          ),
      ],
    );
  }

  Widget _key({
    required String label,
    required int flex,
    VoidCallback? onTap,
    TextStyle? textStyle,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: QianjiColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          onPressed: onTap,
          child: saving && label == '保存'
              ? const CupertinoActivityIndicator(radius: 10)
              : Text(
                  label,
                  style: textStyle ??
                      const TextStyle(
                        fontSize: 22,
                        color: QianjiColors.textPrimary,
                      ),
                ),
        ),
      ),
    );
  }
}
