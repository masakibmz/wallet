import 'package:flutter/cupertino.dart';

abstract final class WalletTheme {
  static CupertinoThemeData cupertino(Brightness brightness) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: CupertinoColors.activeBlue,
      scaffoldBackgroundColor: const Color(0xFFF5F6F8),
    );
  }
}
