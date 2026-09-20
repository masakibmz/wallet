import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wallet/core/database/datetime_converter.dart';
import 'package:wallet/data/database/converters/enum_converters.dart';
import 'package:wallet/data/database/seed/currency_seed.dart';
import 'package:wallet/data/database/tables/all_tables.dart';
import 'package:wallet/domain/enums/app_enums.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Ledgers,
    Users,
    Currencies,
    ExchangeRates,
    Accounts,
    CategoryGroups,
    Categories,
    Tags,
    Transactions,
    TransactionItems,
    TransactionTags,
    Transfers,
    Refunds,
    Budgets,
    BudgetItems,
    RecurringTransactions,
    Installments,
    Debts,
    Reimbursements,
    Attachments,
    SyncRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await CurrencySeed.seed(this);
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(
              transfers,
              transfers.amountMinor,
            );
            await m.addColumn(transfers, transfers.feeMinor);
            await m.addColumn(transfers, transfers.currencyCode);
            await m.addColumn(transfers, transfers.deletedAt);
            await m.addColumn(
              reimbursements,
              reimbursements.incomeTransactionId,
            );
          }
        },
      );

  static AppDatabase? _instance;

  static Future<AppDatabase> openPersistent() async {
    if (_instance != null) {
      return _instance!;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'wallet.sqlite'));
    _instance = AppDatabase(NativeDatabase(file));
    return _instance!;
  }

  static void closeInstance() {
    _instance?.close();
    _instance = null;
  }
}

Future<AppDatabase> openAppDatabase() => AppDatabase.openPersistent();
