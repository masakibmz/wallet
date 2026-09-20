import 'package:wallet/domain/entities/transaction.dart';

/// Canonical interpretation: [amountMinor] = actual paid, [couponMinor] = discount.
abstract final class TransactionMoney {
  static int paidMinor(WalletTransaction tx) => tx.amountMinor;

  static int discountMinor(WalletTransaction tx) => tx.couponMinor;

  static int feeMinor(WalletTransaction tx) => tx.feeMinor;

  static int grossMinor(WalletTransaction tx) => tx.amountMinor + tx.couponMinor;

  static int cashOutflowMinor(WalletTransaction tx) =>
      tx.amountMinor + tx.feeMinor;
}
