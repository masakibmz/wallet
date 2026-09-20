import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/services/app_preferences_service.dart';

final appPreferencesProvider = FutureProvider<AppPreferencesService>((ref) {
  return AppPreferencesService.open();
});
