import 'package:flutter/cupertino.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/presentation/features/assets/account_type_catalog.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/utils/account_icons.dart';

Future<AccountCategory?> showAccountTypePickerSheet(BuildContext context) {
  return showCupertinoModalPopup<AccountCategory>(
    context: context,
    builder: (ctx) => _AccountTypePickerSheet(
      onClose: () => Navigator.pop(ctx),
      onSelect: (c) => Navigator.pop(ctx, c),
    ),
  );
}

class _AccountTypePickerSheet extends StatelessWidget {
  const _AccountTypePickerSheet({
    required this.onClose,
    required this.onSelect,
  });

  final VoidCallback onClose;
  final ValueChanged<AccountCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.82;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: QianjiColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '选择资产类型',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onClose,
                  child: const Icon(CupertinoIcons.xmark),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                for (final section in accountTypeSections) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: QianjiColors.textPrimary,
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: section.options.length,
                    itemBuilder: (context, i) {
                      final opt = section.options[i];
                      final style = accountIconStyleFor(opt.category);
                      return CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => onSelect(opt.category),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: style.bg ?? QianjiColors.chipBackground,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                style.icon,
                                color: style.color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              opt.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
