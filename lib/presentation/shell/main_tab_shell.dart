import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wallet/application/providers/app_preferences_provider.dart';
import 'package:wallet/native/ios/ios_native_bridge.dart';
import 'package:wallet/presentation/theme/qianji_colors.dart';
import 'package:wallet/presentation/widgets/qianji/qianji_bottom_bar.dart';
import 'package:wallet/services/app_preferences_service.dart';

class MainTabShell extends ConsumerStatefulWidget {
  const MainTabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends ConsumerState<MainTabShell> {
  static var _quickLaunchDoneThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openQuickLaunchAdd());
  }

  void _openQuickLaunchAdd() {
    if (_quickLaunchDoneThisSession) {
      return;
    }
    final prefs = ref.read(appPreferencesProvider).valueOrNull;
    if (prefs?.launchMode != AppLaunchMode.addTransaction) {
      return;
    }
    _quickLaunchDoneThisSession = true;
    if (!mounted) {
      return;
    }
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/add-transaction')) {
      return;
    }
    context.push('/add-transaction?type=expense');
  }

  void _goBills() {
    IosNativeBridge.instance.hapticSelection();
    widget.navigationShell.goBranch(0, initialLocation: true);
  }

  void _goAssets() {
    IosNativeBridge.instance.hapticSelection();
    widget.navigationShell.goBranch(3, initialLocation: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appPreferencesProvider, (previous, next) {
      next.whenData((_) => _openQuickLaunchAdd());
    });

    final onAssets = widget.navigationShell.currentIndex == 3;

    return CupertinoPageScaffold(
      backgroundColor: QianjiColors.pageBackground,
      child: Stack(
        children: [
          Positioned.fill(child: widget.navigationShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: QianjiBottomBar(
              billsActive: !onAssets,
              onBills: _goBills,
              onAdd: () {
                IosNativeBridge.instance.hapticLight();
                context.push('/add-transaction?type=expense');
              },
              onAssets: _goAssets,
            ),
          ),
        ],
      ),
    );
  }
}
