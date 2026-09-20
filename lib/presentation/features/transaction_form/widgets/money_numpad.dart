import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wallet/native/ios/ios_native_bridge.dart';

class MoneyNumpad extends StatelessWidget {
  const MoneyNumpad({
    super.key,
    required this.value,
    required this.onChanged,
    this.currencySymbol = '¥',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            '$currencySymbol${value.isEmpty ? '0.00' : value}',
            style: CupertinoTheme.of(context)
                .textTheme
                .navLargeTitleTextStyle
                .copyWith(fontSize: 44, fontWeight: FontWeight.w300),
          ),
        ),
        _KeyGrid(onKey: _handleKey),
      ],
    );
  }

  Future<void> _handleKey(String key) async {
    await IosNativeBridge.instance.hapticLight();
    var next = value;
    if (key == 'del') {
      if (next.isEmpty) {
        return;
      }
      next = next.substring(0, next.length - 1);
    } else if (key == '.') {
      if (next.contains('.')) {
        return;
      }
      next = next.isEmpty ? '0.' : '$next.';
    } else {
      if (next.contains('.')) {
        final frac = next.split('.').last;
        if (frac.length >= 2) {
          return;
        }
      }
      next = next == '0' && key != '.' ? key : '$next$key';
    }
    onChanged(next);
  }
}

class _KeyGrid extends StatelessWidget {
  const _KeyGrid({required this.onKey});

  final Future<void> Function(String key) onKey;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'del'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (final row in keys)
            Row(
              children: [
                for (final k in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: CupertinoColors.tertiarySystemFill
                            .resolveFrom(context),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onKey(k);
                        },
                        child: Text(
                          k == 'del' ? '⌫' : k,
                          style: const TextStyle(
                            fontSize: 22,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
