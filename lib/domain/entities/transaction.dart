import 'package:wallet/domain/entities/base_entity.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class WalletTransaction extends BaseEntity {
  const WalletTransaction({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.ledgerId,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.subCategoryId,
    required this.occurredAt,
    this.note,
    this.feeMinor = 0,
    this.couponMinor = 0,
    this.reimbursementStatus = ReimbursementStatus.none,
    this.reimbursementTarget,
    this.originalTransactionId,
    this.refundStatus,
    this.tagIds = const [],
  });

  final String ledgerId;
  final TransactionType type;
  final int amountMinor;
  final String currencyCode;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? subCategoryId;
  final DateTime occurredAt;
  final String? note;
  final int feeMinor;
  final int couponMinor;
  final ReimbursementStatus reimbursementStatus;
  final String? reimbursementTarget;
  final String? originalTransactionId;
  final RefundStatus? refundStatus;
  final List<String> tagIds;

  @override
  List<Object?> get props => [
        ...super.props,
        ledgerId,
        type,
        amountMinor,
        currencyCode,
        accountId,
        toAccountId,
        categoryId,
        subCategoryId,
        occurredAt,
        note,
        feeMinor,
        couponMinor,
        reimbursementStatus,
        reimbursementTarget,
        originalTransactionId,
        refundStatus,
        tagIds,
      ];
}
