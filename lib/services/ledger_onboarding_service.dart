import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/database/seed/account_seed.dart';
import 'package:wallet/data/database/seed/category_seed.dart';

/// Seeds per-ledger defaults (categories, primary cash account).
class LedgerOnboardingService {
  LedgerOnboardingService(this._db);

  final AppDatabase _db;

  Future<void> onboard(String ledgerId, {String currencyCode = 'CNY'}) async {
    await CategorySeed(_db).ensureForLedger(ledgerId);
    await AccountSeed(_db).ensureForLedger(
      ledgerId,
      currencyCode: currencyCode,
    );
  }
}
