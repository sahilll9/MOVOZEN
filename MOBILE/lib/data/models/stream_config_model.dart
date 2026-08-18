import '../../domain/entities/stream_config.dart';

/// Data-layer model extending the domain [StreamConfig] entity.
///
/// In a more complex app this would handle JSON serialization;
/// here it simply provides a factory for creating configs from
/// the constants layer.
class StreamConfigModel extends StreamConfig {
  const StreamConfigModel({
    required super.rtmpUrl,
    super.videoWidth,
    super.videoHeight,
    super.fps,
    super.bitrateKbps,
    super.enableAudio,
  });

  factory StreamConfigModel.fromEntity(StreamConfig entity) {
    return StreamConfigModel(
      rtmpUrl: entity.rtmpUrl,
      videoWidth: entity.videoWidth,
      videoHeight: entity.videoHeight,
      fps: entity.fps,
      bitrateKbps: entity.bitrateKbps,
      enableAudio: entity.enableAudio,
    );
  }
}
