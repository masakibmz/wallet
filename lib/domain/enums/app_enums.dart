enum LedgerKind {
  life,
  business,
  travel,
  renovation,
  baby,
  custom,
}

enum AccountCategory {
  cash,
  bank,
  alipay,
  wechat,
  qqWallet,
  otherFund,
  creditCard,
  huabei,
  jdBaitiao,
  otherCredit,
  phoneTopUp,
  transitCard,
  mealCard,
  membershipCard,
  deposit,
  otherPrepaid,
  stock,
  fund,
  otherInvestment,
}

enum TransactionType {
  expense,
  income,
  transfer,
  creditRepayment,
  refund,
}

enum ReimbursementStatus {
  none,
  pending,
  reimbursed,
}

enum RefundStatus {
  partial,
  full,
}

enum RecurringFrequency {
  daily,
  weekly,
  monthly,
  yearly,
  custom,
}

enum DebtDirection {
  borrow,
  lend,
}

enum DebtStatus {
  open,
  closed,
}

enum SyncOperation {
  insert,
  update,
  delete,
}

enum BudgetPeriod {
  monthly,
  yearly,
  total,
}
