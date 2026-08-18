import 'package:dartz/dartz.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/failures.dart';
import '../entities/stream_config.dart';
import '../repositories/streaming_repository.dart';

/// Start both front and back camera streams concurrently.
class StartDualStreamUseCase {
  final StreamingRepository repository;

  const StartDualStreamUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    final frontConfig = StreamConfig(
      rtmpUrl: AppConstants.rtmpFrontUrl,
      videoWidth: AppConstants.videoWidth,
      videoHeight: AppConstants.videoHeight,
      fps: AppConstants.videoFps,
      bitrateKbps: AppConstants.videoBitrateKbps,
      enableAudio: true, // Only front camera carries audio
    );

    final backConfig = StreamConfig(
      rtmpUrl: AppConstants.rtmpBackUrl,
      videoWidth: AppConstants.videoWidth,
      videoHeight: AppConstants.videoHeight,
      fps: AppConstants.videoFps,
      bitrateKbps: AppConstants.videoBitrateKbps,
      enableAudio: false, // Back camera is video-only
    );

    // Start front stream first (most critical — worth 30 pts alone)
    final frontResult = await repository.startStream(frontConfig);

    return frontResult.fold(
      (failure) => Left(failure),
      (_) async {
        // Then start back stream
        final backResult = await repository.startStream(backConfig);
        return backResult.fold(
          (failure) => Left(failure),
          (_) => const Right(null),
        );
      },
    );
  }
}
