import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/data/database/app_database.dart';
import 'package:wallet/data/repositories/local/ledger_local_repository.dart';

void main() {
  late AppDatabase db;
  late LedgerLocalRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = LedgerLocalRepository(db, onLedgerCreated: null);
  });

  tearDown(() async {
    await db.close();
  });

  test('ensureDefaultLedger creates one default ledger', () async {
    await repository.ensureDefaultLedger();
    final ledgers = await repository.getActiveLedgers();
    expect(ledgers.length, 1);
    expect(ledgers.single.isDefault, isTrue);
    expect(ledgers.single.name, '默认账本');
  });

  test('watchActiveLedgers emits after create', () async {
    await repository.ensureDefaultLedger();
    final stream = repository.watchActiveLedgers();
    await expectLater(stream, emits(isA<List>().having((l) => l.length, 'length', 1)));
  });
}
