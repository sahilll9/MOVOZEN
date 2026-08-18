import 'package:equatable/equatable.dart';

import '../../../domain/entities/camera_info.dart';

/// Camera streaming modes
enum DashcamMode {
  backOnly, // Road view (Back Camera)
  frontOnly, // Cabin view (Front Camera)
  autoCycle, // Alternating road & cabin views
  dual, // Both simultaneously
}

/// Events dispatched to the [StreamingBloc].
abstract class StreamingEvent extends Equatable {
  const StreamingEvent();

  @override
  List<Object?> get props => [];
}

/// User pressed Start — begin streaming.
class StartStreamingEvent extends StreamingEvent {
  final DashcamMode mode;

  const StartStreamingEvent({this.mode = DashcamMode.backOnly});

  @override
  List<Object?> get props => [mode];
}

/// User pressed Stop — tear down all streams.
class StopStreamingEvent extends StreamingEvent {
  const StopStreamingEvent();
}

/// Change the active camera or dashcam mode
class ChangeDashcamModeEvent extends StreamingEvent {
  final DashcamMode mode;

  const ChangeDashcamModeEvent(this.mode);

  @override
  List<Object?> get props => [mode];
}

/// Switch active camera facing
class SwitchCameraFacingEvent extends StreamingEvent {
  final CameraFacing targetFacing;

  const SwitchCameraFacingEvent(this.targetFacing);

  @override
  List<Object?> get props => [targetFacing];
}

/// Internal event: a stream's status changed.
class FrontStreamStatusChanged extends StreamingEvent {
  final String status;
  const FrontStreamStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

/// Internal event: back stream status changed.
class BackStreamStatusChanged extends StreamingEvent {
  final String status;
  const BackStreamStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

/// Initialize cameras and check permissions.
class InitializeStreamingEvent extends StreamingEvent {
  const InitializeStreamingEvent();
}

/// Update the streaming duration timer tick.
class DurationTickEvent extends StreamingEvent {
  const DurationTickEvent();
}

/// Auto cycle timer tick
class AutoCycleTickEvent extends StreamingEvent {
  const AutoCycleTickEvent();
}
