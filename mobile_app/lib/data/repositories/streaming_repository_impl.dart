import 'package:dartz/dartz.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/camera_info.dart';
import '../../domain/entities/stream_config.dart';
import '../../domain/entities/stream_status.dart';
import '../../domain/repositories/streaming_repository.dart';
import '../datasources/rtmp_data_source.dart';

/// Concrete implementation of [StreamingRepository].
///
/// Maps RTMP URLs to camera facing directions and delegates
/// to the [RtmpDataSource] for actual streaming operations.
class StreamingRepositoryImpl implements StreamingRepository {
  final RtmpDataSource rtmpDataSource;

  StreamingRepositoryImpl({required this.rtmpDataSource});

  /// Determine camera facing from the RTMP URL suffix.
  CameraFacing _facingFromUrl(String url) {
    if (url.endsWith('_front')) return CameraFacing.front;
    if (url.endsWith('_back')) return CameraFacing.back;
    return CameraFacing.front; // default
  }

  @override
  Future<Either<Failure, void>> startStream(StreamConfig config) async {
    try {
      final facing = _facingFromUrl(config.rtmpUrl);
      await rtmpDataSource.startStream(facing, config.rtmpUrl);
      return const Right(null);
    } on StreamException catch (e) {
      return Left(StreamFailure(e.message));
    } on CameraException catch (e) {
      return Left(CameraFailure(e.message));
    } catch (e) {
      return Left(StreamFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> stopStream(String rtmpUrl) async {
    try {
      final facing = _facingFromUrl(rtmpUrl);
      await rtmpDataSource.stopStream(facing);
      return const Right(null);
    } on StreamException catch (e) {
      return Left(StreamFailure(e.message));
    } catch (e) {
      return Left(StreamFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> stopAllStreams() async {
    try {
      await rtmpDataSource.stopAllStreams();
      return const Right(null);
    } on StreamException catch (e) {
      return Left(StreamFailure(e.message));
    } catch (e) {
      return Left(StreamFailure('Unexpected error: $e'));
    }
  }

  @override
  Stream<StreamStatus> streamStatus(String rtmpUrl) {
    final facing = _facingFromUrl(rtmpUrl);
    return rtmpDataSource.streamStatus(facing);
  }
}
