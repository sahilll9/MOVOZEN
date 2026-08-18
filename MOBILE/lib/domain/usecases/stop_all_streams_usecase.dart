import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../repositories/streaming_repository.dart';

/// Stop all active RTMP streams.
class StopAllStreamsUseCase {
  final StreamingRepository repository;

  const StopAllStreamsUseCase(this.repository);

  Future<Either<Failure, void>> call() {
    return repository.stopAllStreams();
  }
}
