import 'package:equatable/equatable.dart';

import '../../../domain/entities/camera_info.dart';
import '../../../domain/entities/stream_status.dart';
import 'streaming_event.dart';

/// States emitted by the [StreamingBloc].
abstract class StreamingState extends Equatable {
  const StreamingState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any action.
class StreamingInitial extends StreamingState {
  const StreamingInitial();
}

/// Cameras enumerated, permissions checked, ready to stream.
class StreamingReady extends StreamingState {
  final bool frontCameraAvailable;
  final bool backCameraAvailable;
  final DashcamMode mode;
  final CameraFacing activeFacing;

  const StreamingReady({
    required this.frontCameraAvailable,
    required this.backCameraAvailable,
    this.mode = DashcamMode.backOnly,
    this.activeFacing = CameraFacing.back,
  });

  StreamingReady copyWith({
    bool? frontCameraAvailable,
    bool? backCameraAvailable,
    DashcamMode? mode,
    CameraFacing? activeFacing,
  }) {
    return StreamingReady(
      frontCameraAvailable: frontCameraAvailable ?? this.frontCameraAvailable,
      backCameraAvailable: backCameraAvailable ?? this.backCameraAvailable,
      mode: mode ?? this.mode,
      activeFacing: activeFacing ?? this.activeFacing,
    );
  }

  @override
  List<Object?> get props => [
        frontCameraAvailable,
        backCameraAvailable,
        mode,
        activeFacing,
      ];
}

/// Actively streaming — contains per-camera status and mode.
class StreamingInProgress extends StreamingState {
  final StreamStatus frontStatus;
  final StreamStatus backStatus;
  final Duration elapsed;
  final DashcamMode mode;
  final CameraFacing activeFacing;

  const StreamingInProgress({
    required this.frontStatus,
    required this.backStatus,
    required this.elapsed,
    this.mode = DashcamMode.backOnly,
    this.activeFacing = CameraFacing.back,
  });

  bool get isAnyLive =>
      frontStatus == StreamStatus.live || backStatus == StreamStatus.live;

  bool get isBothLive =>
      frontStatus == StreamStatus.live && backStatus == StreamStatus.live;

  StreamingInProgress copyWith({
    StreamStatus? frontStatus,
    StreamStatus? backStatus,
    Duration? elapsed,
    DashcamMode? mode,
    CameraFacing? activeFacing,
  }) {
    return StreamingInProgress(
      frontStatus: frontStatus ?? this.frontStatus,
      backStatus: backStatus ?? this.backStatus,
      elapsed: elapsed ?? this.elapsed,
      mode: mode ?? this.mode,
      activeFacing: activeFacing ?? this.activeFacing,
    );
  }

  @override
  List<Object?> get props => [
        frontStatus,
        backStatus,
        elapsed,
        mode,
        activeFacing,
      ];
}

/// Stream was stopped by the user.
class StreamingStopped extends StreamingState {
  final Duration totalDuration;
  final DashcamMode mode;
  final CameraFacing activeFacing;

  const StreamingStopped({
    required this.totalDuration,
    this.mode = DashcamMode.backOnly,
    this.activeFacing = CameraFacing.back,
  });

  @override
  List<Object?> get props => [totalDuration, mode, activeFacing];
}

/// Something went wrong.
class StreamingError extends StreamingState {
  final String message;
  final bool canRetry;

  const StreamingError({
    required this.message,
    this.canRetry = true,
  });

  @override
  List<Object?> get props => [message, canRetry];
}
