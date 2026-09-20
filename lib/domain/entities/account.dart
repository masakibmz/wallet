import 'package:wallet/domain/entities/base_entity.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class Account extends BaseEntity {
  const Account({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.ledgerId,
    required this.name,
    required this.category,
    required this.currencyCode,
    required this.initialBalanceMinor,
    this.includeInTotal = true,
    this.isHidden = false,
    this.sortOrder = 0,
    this.note,
    this.creditLimitMinor,
    this.billingDay,
    this.repaymentDay,
  });

  final String ledgerId;
  final String name;
  final AccountCategory category;
  final String currencyCode;
  final int initialBalanceMinor;
  final bool includeInTotal;
  final bool isHidden;
  final int sortOrder;
  final String? note;
  final int? creditLimitMinor;
  final int? billingDay;
  final int? repaymentDay;

  @override
  List<Object?> get props => [
        ...super.props,
        ledgerId,
        name,
        category,
        currencyCode,
        initialBalanceMinor,
        includeInTotal,
        isHidden,
        sortOrder,
        note,
        creditLimitMinor,
        billingDay,
        repaymentDay,
      ];
}
