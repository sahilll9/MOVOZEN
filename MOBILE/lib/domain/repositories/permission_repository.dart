import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';

/// Contract for runtime permission requests.
abstract class PermissionRepository {
  /// Request camera + microphone permissions.
  /// Returns [Right(true)] if all granted, [Left(PermissionFailure)] otherwise.
  Future<Either<Failure, bool>> requestCameraAndMicPermissions();

  /// Check whether permissions are already granted without prompting.
  Future<bool> hasRequiredPermissions();
}
