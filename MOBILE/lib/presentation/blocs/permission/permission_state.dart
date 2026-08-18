import 'package:equatable/equatable.dart';

abstract class PermissionState extends Equatable {
  const PermissionState();

  @override
  List<Object?> get props => [];
}

class PermissionInitial extends PermissionState {
  const PermissionInitial();
}

class PermissionGranted extends PermissionState {
  const PermissionGranted();
}

class PermissionDenied extends PermissionState {
  final String message;
  const PermissionDenied(this.message);

  @override
  List<Object?> get props => [message];
}

class PermissionRequesting extends PermissionState {
  const PermissionRequesting();
}
