import 'package:equatable/equatable.dart';

abstract class BaseEntity extends Equatable {
  const BaseEntity({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [id, createdAt, updatedAt, deletedAt];
}
