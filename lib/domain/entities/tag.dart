import 'package:wallet/domain/entities/base_entity.dart';

class Tag extends BaseEntity {
  const Tag({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.ledgerId,
    required this.name,
    this.colorValue,
  });

  final String ledgerId;
  final String name;
  final int? colorValue;

  @override
  List<Object?> get props => [
        ...super.props,
        ledgerId,
        name,
        colorValue,
      ];
}
