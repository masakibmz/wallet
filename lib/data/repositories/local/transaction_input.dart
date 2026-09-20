import 'package:wallet/domain/enums/app_enums.dart';

class CreateTransactionInput {
  const CreateTransactionInput({
    required this.ledgerId,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    required this.occurredAt,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.subCategoryId,
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
  final DateTime occurredAt;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? subCategoryId;
  final String? note;
  final int feeMinor;
  final int couponMinor;
  final ReimbursementStatus reimbursementStatus;
  final String? reimbursementTarget;
  final String? originalTransactionId;
  final RefundStatus? refundStatus;
  final List<String> tagIds;
}

class UpdateTransactionInput {
  const UpdateTransactionInput({
    required this.id,
    this.type,
    this.amountMinor,
    this.currencyCode,
    this.occurredAt,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.subCategoryId,
    this.note,
    this.feeMinor,
    this.couponMinor,
    this.reimbursementStatus,
    this.reimbursementTarget,
    this.tagIds,
  });

  final String id;
  final TransactionType? type;
  final int? amountMinor;
  final String? currencyCode;
  final DateTime? occurredAt;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? subCategoryId;
  final String? note;
  final int? feeMinor;
  final int? couponMinor;
  final ReimbursementStatus? reimbursementStatus;
  final String? reimbursementTarget;
  final List<String>? tagIds;
}
