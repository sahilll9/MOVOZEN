import 'package:equatable/equatable.dart';

/// Minimal domain representation of a camera sensor.
enum CameraFacing { front, back }

class CameraInfo extends Equatable {
  final CameraFacing facing;
  final bool isAvailable;

  const CameraInfo({
    required this.facing,
    required this.isAvailable,
  });

  @override
  List<Object?> get props => [facing, isAvailable];
}
