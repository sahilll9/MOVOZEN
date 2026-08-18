import 'package:equatable/equatable.dart';

/// Base failure class for the domain layer.
///
/// All specific failure types extend this so that use cases
/// can return typed errors without depending on exceptions.
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class CameraFailure extends Failure {
  const CameraFailure(super.message);
}

class StreamFailure extends Failure {
  const StreamFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}
