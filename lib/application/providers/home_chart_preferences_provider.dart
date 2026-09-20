import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/app_preferences_provider.dart';
import 'package:wallet/services/app_preferences_service.dart';

final homeWeeklyChartPrefsProvider =
    StateProvider<HomeWeeklyChartPrefs>((ref) {
  return ref.watch(appPreferencesProvider).maybeWhen(
        data: (prefs) => prefs.homeWeeklyChartPrefs,
        orElse: () => const HomeWeeklyChartPrefs(),
      );
});

Future<void> persistHomeWeeklyChartPrefs(
  WidgetRef ref,
  HomeWeeklyChartPrefs prefs,
) async {
  ref.read(homeWeeklyChartPrefsProvider.notifier).state = prefs;
  final service = await ref.read(appPreferencesProvider.future);
  await service.setHomeWeeklyChartPrefs(prefs);
}
