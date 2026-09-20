import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/presentation/routing/app_router.dart';
import 'package:wallet/presentation/theme/wallet_theme.dart';

class WalletApp extends ConsumerWidget {
  const WalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    return CupertinoApp.router(
      title: 'Wallet',
      theme: WalletTheme.cupertino(brightness),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      routerConfig: router,
    );
  }
}
