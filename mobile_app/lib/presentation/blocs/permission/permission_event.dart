import 'package:equatable/equatable.dart';

abstract class PermissionEvent extends Equatable {
  const PermissionEvent();

  @override
  List<Object?> get props => [];
}

class RequestPermissionsEvent extends PermissionEvent {
  const RequestPermissionsEvent();
}

class CheckPermissionsEvent extends PermissionEvent {
  const CheckPermissionsEvent();
}
