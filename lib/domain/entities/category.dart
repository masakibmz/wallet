import 'package:wallet/domain/entities/base_entity.dart';

class Category extends BaseEntity {
  const Category({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.ledgerId,
    this.groupId,
    this.parentId,
    required this.name,
    this.iconName,
    required this.isExpense,
    this.isSystem = false,
    this.isDeletable = true,
    this.sortOrder = 0,
  });

  final String ledgerId;
  final String? groupId;
  final String? parentId;
  final String name;
  final String? iconName;
  final bool isExpense;
  final bool isSystem;
  final bool isDeletable;
  final int sortOrder;

  bool get isTopLevel => parentId == null;

  @override
  List<Object?> get props => [
        ...super.props,
        ledgerId,
        groupId,
        parentId,
        name,
        iconName,
        isExpense,
        isSystem,
        isDeletable,
        sortOrder,
      ];
}
