import 'package:flutter/cupertino.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class AccountIconStyle {
  const AccountIconStyle({required this.icon, required this.color, this.bg});

  final IconData icon;
  final Color color;
  final Color? bg;
}

AccountIconStyle accountIconStyleFor(AccountCategory category) {
  return switch (category) {
    AccountCategory.cash => const AccountIconStyle(
        icon: CupertinoIcons.money_dollar_circle,
        color: Color(0xFF34C759),
        bg: Color(0xFFE8F7EE),
      ),
    AccountCategory.bank => const AccountIconStyle(
        icon: CupertinoIcons.building_2_fill,
        color: Color(0xFF007AFF),
        bg: Color(0xFFEAF2FD),
      ),
    AccountCategory.alipay => const AccountIconStyle(
        icon: CupertinoIcons.creditcard,
        color: Color(0xFF1677FF),
        bg: Color(0xFFEAF2FD),
      ),
    AccountCategory.wechat => const AccountIconStyle(
        icon: CupertinoIcons.chat_bubble_2_fill,
        color: Color(0xFF07C160),
        bg: Color(0xFFE8F7EE),
      ),
    AccountCategory.qqWallet => const AccountIconStyle(
        icon: CupertinoIcons.person_2_fill,
        color: Color(0xFF12B7F5),
        bg: Color(0xFFEAF2FD),
      ),
    AccountCategory.creditCard ||
    AccountCategory.huabei ||
    AccountCategory.jdBaitiao ||
    AccountCategory.otherCredit =>
      const AccountIconStyle(
        icon: CupertinoIcons.creditcard_fill,
        color: Color(0xFFFF9500),
        bg: Color(0xFFFFF4E5),
      ),
    _ => const AccountIconStyle(
        icon: CupertinoIcons.square_grid_2x2,
        color: Color(0xFF8E8E93),
        bg: Color(0xFFF0F1F3),
      ),
  };
}
