import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/stream_config.dart';
import '../repositories/streaming_repository.dart';

/// Start a single RTMP stream for one camera.
class StartStreamUseCase {
  final StreamingRepository repository;

  const StartStreamUseCase(this.repository);

  Future<Either<Failure, void>> call(StreamConfig config) {
    return repository.startStream(config);
  }
}
