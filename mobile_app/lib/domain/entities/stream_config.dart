import 'package:equatable/equatable.dart';

/// Immutable configuration for one RTMP stream.
class StreamConfig extends Equatable {
  final String rtmpUrl;
  final int videoWidth;
  final int videoHeight;
  final int fps;
  final int bitrateKbps;
  final bool enableAudio;

  const StreamConfig({
    required this.rtmpUrl,
    this.videoWidth = 1280,
    this.videoHeight = 720,
    this.fps = 25,
    this.bitrateKbps = 1500,
    this.enableAudio = true,
  });

  @override
  List<Object?> get props => [
        rtmpUrl,
        videoWidth,
        videoHeight,
        fps,
        bitrateKbps,
        enableAudio,
      ];
}
