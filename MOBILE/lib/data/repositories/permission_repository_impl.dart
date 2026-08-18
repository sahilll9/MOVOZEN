import 'package:dartz/dartz.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../domain/repositories/permission_repository.dart';
import '../datasources/permission_data_source.dart';

/// Concrete implementation of [PermissionRepository].
class PermissionRepositoryImpl implements PermissionRepository {
  final PermissionDataSource permissionDataSource;

  PermissionRepositoryImpl({required this.permissionDataSource});

  @override
  Future<Either<Failure, bool>> requestCameraAndMicPermissions() async {
    try {
      final granted =
          await permissionDataSource.requestCameraAndMicPermissions();
      return Right(granted);
    } on PermissionException catch (e) {
      return Left(PermissionFailure(e.message));
    } catch (e) {
      return Left(PermissionFailure('Permission error: $e'));
    }
  }

  @override
  Future<bool> hasRequiredPermissions() {
    return permissionDataSource.hasRequiredPermissions();
  }
}
