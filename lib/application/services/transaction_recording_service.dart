import 'package:wallet/application/transaction_recording/transaction_form_kind.dart';
import 'package:wallet/application/transaction_recording/transaction_recording_draft.dart';
import 'package:wallet/data/repositories/local/attachment_local_repository.dart';
import 'package:wallet/data/repositories/local/refund_local_repository.dart';
import 'package:wallet/data/repositories/local/reimbursement_local_repository.dart';
import 'package:wallet/data/repositories/local/repayment_local_repository.dart';
import 'package:wallet/data/repositories/local/transaction_input.dart';
import 'package:wallet/data/repositories/local/transaction_local_repository.dart';
import 'package:wallet/data/repositories/repository_exception.dart';
import 'package:wallet/domain/entities/transaction.dart';
import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/services/accounting/ledger_accounting_service.dart';

class TransactionRecordingService {
  TransactionRecordingService({
    required this.ledger,
    required this.transactions,
    required this.refunds,
    required this.repayments,
    required this.reimbursements,
    required this.attachments,
  });

  final LedgerAccountingService ledger;
  final TransactionRepository transactions;
  final RefundRepository refunds;
  final RepaymentRepository repayments;
  final ReimbursementRepository reimbursements;
  final AttachmentRepository attachments;

  Future<WalletTransaction> save(TransactionRecordingDraft draft) async {
    _validateDraft(draft);
    if (draft.isEditing) {
      return _update(draft);
    }
    return _create(draft);
  }

  Future<void> delete(String transactionId) async {
    final existing = await transactions.getById(transactionId);
    if (existing == null) {
      throw RepositoryException('账单不存在');
    }
    if (existing.type == TransactionType.refund) {
      await refunds.deleteRefund(transactionId);
      return;
    }
    if (existing.type == TransactionType.creditRepayment) {
      await repayments.deleteRepayment(transactionId);
      return;
    }
    await ledger.softDeleteTransaction(transactionId);
  }

  Future<WalletTransaction> _create(TransactionRecordingDraft draft) async {
    switch (draft.kind) {
      case TransactionFormKind.refund:
        return refunds.createRefund(
          ledgerId: draft.ledgerId,
          originalTransactionId: draft.originalExpenseId!,
          refundAmountMinor: draft.paidAmountMinor,
          currencyCode: draft.currencyCode,
          accountId: draft.accountId,
          occurredAt: draft.occurredAt,
          note: draft.note,
        );
      case TransactionFormKind.creditRepayment:
        final tx = await repayments.createRepayment(
          ledgerId: draft.ledgerId,
          sourceAccountId: draft.accountId!,
          creditAccountId: draft.toAccountId!,
          amountMinor: draft.paidAmountMinor,
          currencyCode: draft.currencyCode,
          occurredAt: draft.occurredAt,
          note: draft.note,
          feeMinor: draft.feeMinor,
        );
        return tx;
      case TransactionFormKind.expense:
      case TransactionFormKind.income:
      case TransactionFormKind.transfer:
        final type = _transactionType(draft.kind);
        final tx = await ledger.createTransaction(
          CreateTransactionInput(
            ledgerId: draft.ledgerId,
            type: type,
            amountMinor: draft.paidAmountMinor,
            currencyCode: draft.currencyCode,
            occurredAt: draft.occurredAt,
            accountId: draft.accountId,
            toAccountId: draft.toAccountId,
            categoryId: draft.categoryId,
            subCategoryId: draft.subCategoryId,
            note: draft.note,
            feeMinor: draft.feeMinor,
            couponMinor: draft.couponMinor,
            reimbursementStatus: draft.reimbursementStatus,
            reimbursementTarget: draft.reimbursementTarget,
            tagIds: draft.tagIds,
          ),
        );
        if (draft.attachmentPaths.isNotEmpty) {
          await attachments.replaceAttachments(
            transactionId: tx.id,
            localPaths: draft.attachmentPaths,
          );
        }
        if (draft.kind == TransactionFormKind.expense &&
            draft.reimbursementPending) {
          await reimbursements.markExpensePendingReimbursement(
            expenseTransactionId: tx.id,
            amountMinor: draft.reimbursementAmountMinor ?? draft.paidAmountMinor,
            target: draft.reimbursementTarget,
          );
        }
        return (await transactions.getById(tx.id))!;
    }
  }

  Future<WalletTransaction> _update(TransactionRecordingDraft draft) async {
    final id = draft.transactionId!;
    final existing = await transactions.getById(id);
    if (existing == null) {
      throw RepositoryException('账单不存在');
    }
    if (existing.type == TransactionType.refund ||
        existing.type == TransactionType.creditRepayment) {
      throw RepositoryException('请删除后重新创建该类型账单');
    }

    final tx = await ledger.updateTransaction(
      UpdateTransactionInput(
        id: id,
        type: _transactionType(draft.kind),
        amountMinor: draft.paidAmountMinor,
        currencyCode: draft.currencyCode,
        occurredAt: draft.occurredAt,
        accountId: draft.accountId,
        toAccountId: draft.toAccountId,
        categoryId: draft.categoryId,
        subCategoryId: draft.subCategoryId,
        note: draft.note,
        feeMinor: draft.feeMinor,
        couponMinor: draft.couponMinor,
        reimbursementStatus: draft.reimbursementStatus,
        reimbursementTarget: draft.reimbursementTarget,
        tagIds: draft.tagIds,
      ),
    );
    await attachments.replaceAttachments(
      transactionId: id,
      localPaths: draft.attachmentPaths,
    );
    return tx;
  }

  TransactionType _transactionType(TransactionFormKind kind) {
    return switch (kind) {
      TransactionFormKind.expense => TransactionType.expense,
      TransactionFormKind.income => TransactionType.income,
      TransactionFormKind.transfer => TransactionType.transfer,
      TransactionFormKind.refund => TransactionType.refund,
      TransactionFormKind.creditRepayment => TransactionType.creditRepayment,
    };
  }

  void _validateDraft(TransactionRecordingDraft draft) {
    if (draft.paidAmountMinor <= 0) {
      throw RepositoryException('金额必须大于 0');
    }
    switch (draft.kind) {
      case TransactionFormKind.expense:
      case TransactionFormKind.income:
        if (draft.categoryId == null) {
          throw RepositoryException('请选择分类');
        }
        if (draft.accountId == null) {
          throw RepositoryException('请选择账户');
        }
      case TransactionFormKind.transfer:
      case TransactionFormKind.creditRepayment:
        if (draft.accountId == null || draft.toAccountId == null) {
          throw RepositoryException('请选择账户');
        }
      case TransactionFormKind.refund:
        if (draft.originalExpenseId == null) {
          throw RepositoryException('请选择原支出账单');
        }
    }
  }
}
