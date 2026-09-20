import 'package:equatable/equatable.dart';
import 'package:wallet/domain/enums/app_enums.dart';

class TransactionDraft extends Equatable {
  const TransactionDraft({
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    this.categoryHint,
    this.note,
    this.occurredAt,
  });

  final TransactionType type;
  final int amountMinor;
  final String currencyCode;
  final String? categoryHint;
  final String? note;
  final DateTime? occurredAt;

  @override
  List<Object?> get props => [
        type,
        amountMinor,
        currencyCode,
        categoryHint,
        note,
        occurredAt,
      ];
}
