import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/stream_config.dart';
import '../entities/stream_status.dart';

/// Contract for RTMP streaming operations.
///
/// The domain layer depends on this interface; the data layer
/// provides the concrete implementation.
abstract class StreamingRepository {
  /// Begin streaming one camera feed to the given RTMP config.
  Future<Either<Failure, void>> startStream(StreamConfig config);

  /// Stop a specific stream (identified by its RTMP URL).
  Future<Either<Failure, void>> stopStream(String rtmpUrl);

  /// Stop all active streams.
  Future<Either<Failure, void>> stopAllStreams();

  /// Reactive status updates for a given stream URL.
  Stream<StreamStatus> streamStatus(String rtmpUrl);
}
