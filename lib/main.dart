import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/application/providers/database_providers.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/presentation/app/wallet_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await AppDatabase.openPersistent();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const WalletApp(),
    ),
  );
}
