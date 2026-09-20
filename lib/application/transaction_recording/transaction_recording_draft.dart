import 'package:wallet/application/transaction_recording/transaction_form_kind.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class TransactionRecordingDraft {
  const TransactionRecordingDraft({
    required this.kind,
    required this.ledgerId,
    required this.currencyCode,
    required this.paidAmountMinor,
    required this.occurredAt,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.subCategoryId,
    this.note,
    this.feeMinor = 0,
    this.couponMinor = 0,
    this.tagIds = const [],
    this.attachmentPaths = const [],
    this.reimbursementPending = false,
    this.reimbursementAmountMinor,
    this.reimbursementTarget,
    this.originalExpenseId,
    this.transactionId,
  });

  final TransactionFormKind kind;
  final String ledgerId;
  final String currencyCode;
  final int paidAmountMinor;
  final DateTime occurredAt;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? subCategoryId;
  final String? note;
  final int feeMinor;
  final int couponMinor;
  final List<String> tagIds;
  final List<String> attachmentPaths;
  final bool reimbursementPending;
  final int? reimbursementAmountMinor;
  final String? reimbursementTarget;
  final String? originalExpenseId;
  final String? transactionId;

  bool get isEditing => transactionId != null;

  ReimbursementStatus get reimbursementStatus {
    if (kind != TransactionFormKind.expense) {
      return ReimbursementStatus.none;
    }
    if (reimbursementPending) {
      return ReimbursementStatus.pending;
    }
    return ReimbursementStatus.none;
  }
}
