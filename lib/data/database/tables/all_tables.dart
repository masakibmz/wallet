import 'package:drift/drift.dart';
import 'package:wallet/core/database/datetime_converter.dart';
import 'package:wallet/data/database/converters/enum_converters.dart';
@DataClassName('LedgerRow')
class Ledgers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get kind => integer().map(const LedgerKindConverter())();
  TextColumn get iconName => text().nullable()();
  IntColumn get colorValue => integer().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get baseCurrencyCode =>
      text().withDefault(const Constant('CNY'))();
  TextColumn get sharedLedgerId => text().nullable()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get baseCurrencyCode =>
      text().withDefault(const Constant('CNY'))();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CurrencyRow')
class Currencies extends Table {
  TextColumn get code => text()();
  TextColumn get name => text()();
  IntColumn get minorUnitScale => integer()();
  TextColumn get symbol => text().nullable()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {code};
}

@DataClassName('ExchangeRateRow')
class ExchangeRates extends Table {
  TextColumn get id => text()();
  TextColumn get fromCurrencyCode => text()();
  TextColumn get toCurrencyCode => text()();
  TextColumn get rateNumerator => text()();
  TextColumn get rateDenominator => text()();
  IntColumn get effectiveAt => integer().map(const DateTimeConverter())();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  TextColumn get name => text()();
  IntColumn get category => integer().map(const AccountCategoryConverter())();
  TextColumn get currencyCode => text()();
  IntColumn get initialBalanceMinor => integer()();
  BoolColumn get includeInTotal => boolean().withDefault(const Constant(true))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  IntColumn get creditLimitMinor => integer().nullable()();
  IntColumn get billingDay => integer().nullable()();
  IntColumn get repaymentDay => integer().nullable()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CategoryGroupRow')
class CategoryGroups extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  TextColumn get name => text()();
  BoolColumn get isExpense => boolean()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  TextColumn get groupId => text().nullable()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get iconName => text().nullable()();
  BoolColumn get isExpense => boolean()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeletable => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer().nullable()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  IntColumn get type => integer().map(const TransactionTypeConverter())();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text()();
  TextColumn get accountId => text().nullable()();
  TextColumn get toAccountId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get subCategoryId => text().nullable()();
  IntColumn get occurredAt => integer().map(const DateTimeConverter())();
  TextColumn get note => text().nullable()();
  IntColumn get feeMinor => integer().withDefault(const Constant(0))();
  IntColumn get couponMinor => integer().withDefault(const Constant(0))();
  IntColumn get reimbursementStatus =>
      integer().map(const ReimbursementStatusConverter()).withDefault(
            const Constant(0),
          )();
  TextColumn get reimbursementTarget => text().nullable()();
  TextColumn get originalTransactionId => text().nullable()();
  IntColumn get refundStatus =>
      integer().map(const RefundStatusConverter()).nullable()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TransactionItemRow')
class TransactionItems extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get name => text()();
  IntColumn get amountMinor => integer()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TransactionTagRow')
class TransactionTags extends Table {
  TextColumn get transactionId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column<Object>> get primaryKey => {transactionId, tagId};
}

@DataClassName('TransferRow')
class Transfers extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get fromAccountId => text()();
  TextColumn get toAccountId => text()();
  IntColumn get amountMinor => integer().withDefault(const Constant(0))();
  IntColumn get feeMinor => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().nullable()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RefundRow')
class Refunds extends Table {
  TextColumn get id => text()();
  TextColumn get originalTransactionId => text()();
  TextColumn get refundTransactionId => text()();
  IntColumn get amountMinor => integer()();
  IntColumn get status => integer().map(const RefundStatusConverter())();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  IntColumn get period => integer().map(const BudgetPeriodConverter())();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text()();
  IntColumn get startAt => integer().map(const DateTimeConverter())();
  IntColumn get endAt =>
      integer().map(const DateTimeConverter()).nullable()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BudgetItemRow')
class BudgetItems extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get amountMinor => integer()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RecurringTransactionRow')
class RecurringTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  TextColumn get templateJson => text()();
  IntColumn get frequency =>
      integer().map(const RecurringFrequencyConverter())();
  IntColumn get customIntervalDays => integer().nullable()();
  IntColumn get startAt => integer().map(const DateTimeConverter())();
  IntColumn get endAt =>
      integer().map(const DateTimeConverter()).nullable()();
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
  IntColumn get nextRunAt => integer().map(const DateTimeConverter())();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('InstallmentRow')
class Installments extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  TextColumn get sourceTransactionId => text().nullable()();
  IntColumn get totalAmountMinor => integer()();
  IntColumn get periodCount => integer()();
  IntColumn get completedPeriods =>
      integer().withDefault(const Constant(0))();
  IntColumn get startAt => integer().map(const DateTimeConverter())();
  TextColumn get currencyCode => text()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DebtRow')
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  TextColumn get counterparty => text()();
  IntColumn get direction => integer().map(const DebtDirectionConverter())();
  IntColumn get principalMinor => integer()();
  IntColumn get remainingMinor => integer()();
  IntColumn get status => integer().map(const DebtStatusConverter())();
  TextColumn get currencyCode => text()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ReimbursementRow')
class Reimbursements extends Table {
  TextColumn get id => text()();
  /// Expense transaction awaiting or receiving reimbursement.
  TextColumn get transactionId => text()();
  TextColumn get incomeTransactionId => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get target => text().nullable()();
  IntColumn get reimbursedAt =>
      integer().map(const DateTimeConverter()).nullable()();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AttachmentRow')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get localPath => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();
  IntColumn get updatedAt => integer().map(const DateTimeConverter())();
  IntColumn get deletedAt =>
      integer().map(const DateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncRecordRow')
class SyncRecords extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get operation => integer().map(const SyncOperationConverter())();
  IntColumn get changedAt => integer().map(const DateTimeConverter())();
  TextColumn get payloadJson => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().map(const DateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
