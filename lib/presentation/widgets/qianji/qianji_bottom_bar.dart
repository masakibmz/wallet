import 'package:flutter/cupertino.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';

class QianjiBottomBar extends StatelessWidget {
  const QianjiBottomBar({
    super.key,
    required this.billsActive,
    required this.onBills,
    required this.onAdd,
    required this.onAssets,
  });

  final bool billsActive;
  final VoidCallback onBills;
  final VoidCallback onAdd;
  final VoidCallback onAssets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: QianjiColors.cardBackground,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabItem(
                active: billsActive,
                icon: CupertinoIcons.doc_text_fill,
                label: '账单',
                onTap: onBills,
              ),
            ),
            _Fab(onTap: onAdd),
            Expanded(
              child: _TabItem(
                active: !billsActive,
                icon: CupertinoIcons.creditcard_fill,
                label: '资产',
                onTap: onAssets,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: QianjiColors.fabBlue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x404A8FE7),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.add,
          color: CupertinoColors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? QianjiColors.tabActiveBg : null,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? QianjiColors.fabBlue : QianjiColors.textSecondary,
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: QianjiColors.fabBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
