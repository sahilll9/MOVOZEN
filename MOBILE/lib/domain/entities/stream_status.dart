/// Represents the lifecycle state of a single RTMP stream.
enum StreamStatus {
  /// No stream has been started yet.
  idle,

  /// Camera is being initialised.
  initializing,

  /// RTMP connection is being established.
  connecting,

  /// Actively streaming to the server.
  live,

  /// Connection lost; attempting to reconnect.
  reconnecting,

  /// An unrecoverable error occurred.
  error,

  /// Stream was explicitly stopped by the user.
  stopped,
}
