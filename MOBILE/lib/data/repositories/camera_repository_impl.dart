import 'package:dartz/dartz.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/camera_info.dart';
import '../../domain/repositories/camera_repository.dart';
import '../datasources/rtmp_data_source.dart';

/// Concrete implementation of [CameraRepository].
class CameraRepositoryImpl implements CameraRepository {
  final RtmpDataSource rtmpDataSource;

  CameraRepositoryImpl({required this.rtmpDataSource});

  @override
  Future<Either<Failure, List<CameraInfo>>> getAvailableCameras() async {
    try {
      final cameras = await rtmpDataSource.getAvailableCameras();
      return Right(cameras);
    } on CameraException catch (e) {
      return Left(CameraFailure(e.message));
    } catch (e) {
      return Left(CameraFailure('Failed to get cameras: $e'));
    }
  }
}
