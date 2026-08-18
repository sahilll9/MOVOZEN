import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/camera_info.dart';

/// Contract for camera hardware operations.
abstract class CameraRepository {
  /// Enumerate available camera sensors.
  Future<Either<Failure, List<CameraInfo>>> getAvailableCameras();
}
