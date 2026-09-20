import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/app_preferences_provider.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/application/providers/ledger_data_providers.dart';
import 'package:wallet/services/asset_group_layout_service.dart';

final assetGroupLayoutServiceProvider =
    FutureProvider<AssetGroupLayoutService>((ref) async {
  await ref.watch(appPreferencesProvider.future);
  return AssetGroupLayoutService.open();
});

final assetGroupLayoutProvider =
    FutureProvider<AssetGroupLayout?>((ref) async {
  final ledger = ref.watch(currentLedgerProvider);
  if (ledger == null) {
    return null;
  }
  final accounts =
      ref.watch(accountsForLedgerProvider(ledger.id)).valueOrNull ?? [];
  final service = await ref.watch(assetGroupLayoutServiceProvider.future);
  return service.loadOrDefault(ledgerId: ledger.id, accounts: accounts);
});

Future<void> persistAssetGroupLayout(
  WidgetRef ref,
  String ledgerId,
  AssetGroupLayout layout,
) async {
  final service = await ref.read(assetGroupLayoutServiceProvider.future);
  await service.save(ledgerId, layout);
  ref.invalidate(assetGroupLayoutProvider);
}
