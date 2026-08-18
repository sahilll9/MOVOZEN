import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../repositories/streaming_repository.dart';

/// Stop a single RTMP stream identified by its URL.
class StopStreamUseCase {
  final StreamingRepository repository;

  const StopStreamUseCase(this.repository);

  Future<Either<Failure, void>> call(String rtmpUrl) {
    return repository.stopStream(rtmpUrl);
  }
}
