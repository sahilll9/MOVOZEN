import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/camera_info.dart';
import '../repositories/camera_repository.dart';

/// Enumerate available cameras on the device.
class GetCamerasUseCase {
  final CameraRepository repository;

  const GetCamerasUseCase(this.repository);

  Future<Either<Failure, List<CameraInfo>>> call() {
    return repository.getAvailableCameras();
  }
}
