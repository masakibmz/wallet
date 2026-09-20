import 'package:wallet/domain/enums/app_enums.dart';
import 'package:wallet/domain/entities/base_entity.dart';

class Ledger extends BaseEntity {
  const Ledger({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.name,
    required this.kind,
    this.iconName,
    this.colorValue,
    this.isDefault = false,
    this.sortOrder = 0,
    this.baseCurrencyCode = 'CNY',
    this.sharedLedgerId,
  });

  final String name;
  final LedgerKind kind;
  final String? iconName;
  final int? colorValue;
  final bool isDefault;
  final int sortOrder;
  final String baseCurrencyCode;
  final String? sharedLedgerId;

  @override
  List<Object?> get props => [
        ...super.props,
        name,
        kind,
        iconName,
        colorValue,
        isDefault,
        sortOrder,
        baseCurrencyCode,
        sharedLedgerId,
      ];
}
