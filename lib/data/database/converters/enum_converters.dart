import 'package:drift/drift.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class LedgerKindConverter extends TypeConverter<LedgerKind, int> {
  const LedgerKindConverter();

  @override
  LedgerKind fromSql(int fromDb) => LedgerKind.values[fromDb];

  @override
  int toSql(LedgerKind value) => value.index;
}

class AccountCategoryConverter extends TypeConverter<AccountCategory, int> {
  const AccountCategoryConverter();

  @override
  AccountCategory fromSql(int fromDb) => AccountCategory.values[fromDb];

  @override
  int toSql(AccountCategory value) => value.index;
}

class TransactionTypeConverter extends TypeConverter<TransactionType, int> {
  const TransactionTypeConverter();

  @override
  TransactionType fromSql(int fromDb) => TransactionType.values[fromDb];

  @override
  int toSql(TransactionType value) => value.index;
}

class ReimbursementStatusConverter
    extends TypeConverter<ReimbursementStatus, int> {
  const ReimbursementStatusConverter();

  @override
  ReimbursementStatus fromSql(int fromDb) =>
      ReimbursementStatus.values[fromDb];

  @override
  int toSql(ReimbursementStatus value) => value.index;
}

class RefundStatusConverter extends TypeConverter<RefundStatus, int> {
  const RefundStatusConverter();

  @override
  RefundStatus fromSql(int fromDb) => RefundStatus.values[fromDb];

  @override
  int toSql(RefundStatus value) => value.index;
}

class RecurringFrequencyConverter
    extends TypeConverter<RecurringFrequency, int> {
  const RecurringFrequencyConverter();

  @override
  RecurringFrequency fromSql(int fromDb) =>
      RecurringFrequency.values[fromDb];

  @override
  int toSql(RecurringFrequency value) => value.index;
}

class DebtDirectionConverter extends TypeConverter<DebtDirection, int> {
  const DebtDirectionConverter();

  @override
  DebtDirection fromSql(int fromDb) => DebtDirection.values[fromDb];

  @override
  int toSql(DebtDirection value) => value.index;
}

class DebtStatusConverter extends TypeConverter<DebtStatus, int> {
  const DebtStatusConverter();

  @override
  DebtStatus fromSql(int fromDb) => DebtStatus.values[fromDb];

  @override
  int toSql(DebtStatus value) => value.index;
}

class SyncOperationConverter extends TypeConverter<SyncOperation, int> {
  const SyncOperationConverter();

  @override
  SyncOperation fromSql(int fromDb) => SyncOperation.values[fromDb];

  @override
  int toSql(SyncOperation value) => value.index;
}

class BudgetPeriodConverter extends TypeConverter<BudgetPeriod, int> {
  const BudgetPeriodConverter();

  @override
  BudgetPeriod fromSql(int fromDb) => BudgetPeriod.values[fromDb];

  @override
  int toSql(BudgetPeriod value) => value.index;
}
