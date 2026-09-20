import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/repositories/local/ledger_local_repository.dart';
import 'package:wallet/services/ledger_onboarding_service.dart';

class AppBootstrapService {
  AppBootstrapService({
    required this._db,
    required this._ledgerRepository,
    required this._onboarding,
  });

  final AppDatabase _db;
  final LedgerRepository _ledgerRepository;
  final LedgerOnboardingService _onboarding;

  Future<void> initialize() async {
    await _ledgerRepository.ensureDefaultLedger();
    final ledgers = await _ledgerRepository.getActiveLedgers();
    for (final ledger in ledgers) {
      await _onboarding.onboard(
        ledger.id,
        currencyCode: ledger.baseCurrencyCode,
      );
    }
    await _db.customSelect('SELECT 1').get();
  }
}
