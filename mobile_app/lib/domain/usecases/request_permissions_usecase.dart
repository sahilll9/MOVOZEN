import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../repositories/permission_repository.dart';

/// Request camera and microphone permissions.
class RequestPermissionsUseCase {
  final PermissionRepository repository;

  const RequestPermissionsUseCase(this.repository);

  Future<Either<Failure, bool>> call() {
    return repository.requestCameraAndMicPermissions();
  }
}
