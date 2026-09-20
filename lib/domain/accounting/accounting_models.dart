import 'package:equatable/equatable.dart';
import 'package:wallet/domain/accounting/account_classifier.dart';

/// Signed liability position: positive = 欠款, negative = 溢缴款.
typedef LiabilityPositionMinor = int;

class AccountPosting extends Equatable {
  const AccountPosting({
    required this.accountId,
    required this.nature,
    required this.deltaMinor,
  });

  final String accountId;
  final AccountNature nature;
  final int deltaMinor;

  @override
  List<Object?> get props => [accountId, nature, deltaMinor];
}

class StatisticalImpact extends Equatable {
  const StatisticalImpact({
    this.expenseMinor = 0,
    this.incomeMinor = 0,
    this.feeMinor = 0,
    this.discountMinor = 0,
    this.refundOffsetMinor = 0,
    this.reimbursementIncomeMinor = 0,
  });

  final int expenseMinor;
  final int incomeMinor;
  final int feeMinor;
  final int discountMinor;
  final int refundOffsetMinor;
  final int reimbursementIncomeMinor;

  int get netExpenseMinor => expenseMinor - refundOffsetMinor;

  /// Ordinary income only; reimbursement inflows are tracked separately.
  int get netIncomeMinor => incomeMinor;

  StatisticalImpact operator +(StatisticalImpact other) {
    return StatisticalImpact(
      expenseMinor: expenseMinor + other.expenseMinor,
      incomeMinor: incomeMinor + other.incomeMinor,
      feeMinor: feeMinor + other.feeMinor,
      discountMinor: discountMinor + other.discountMinor,
      refundOffsetMinor: refundOffsetMinor + other.refundOffsetMinor,
      reimbursementIncomeMinor:
          reimbursementIncomeMinor + other.reimbursementIncomeMinor,
    );
  }

  @override
  List<Object?> get props => [
        expenseMinor,
        incomeMinor,
        feeMinor,
        discountMinor,
        refundOffsetMinor,
        reimbursementIncomeMinor,
      ];
}

class LiabilitySnapshot extends Equatable {
  const LiabilitySnapshot({required this.positionMinor});

  final LiabilityPositionMinor positionMinor;

  int get debtMinor => positionMinor > 0 ? positionMinor : 0;

  int get overpaymentMinor =>
      positionMinor < 0 ? positionMinor.abs() : 0;

  @override
  List<Object?> get props => [positionMinor];
}
