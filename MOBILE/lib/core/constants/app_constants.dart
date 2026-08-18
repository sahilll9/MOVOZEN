/// App-wide constants for MoboSafe Pocket Dashcam.
///
/// All streaming configuration is centralized here so that
/// the roll number, server URL, and encoder settings can be
/// changed in one place.
class AppConstants {
  AppConstants._();

  // ── Identity ────────────────────────────────────────────
  /// Change this to your roll number (uppercase, no spaces).
  static const String rollNumber = 'BTECH25169';

  // ── RTMP Server ─────────────────────────────────────────
  static const String rtmpHost = '15.207.177.194';
  static const int rtmpPort = 1936;
  static const String rtmpApp = 'hackathon';

  static String get rtmpFrontUrl =>
      'rtmp://$rtmpHost:$rtmpPort/$rtmpApp/${rollNumber}_front';

  static String get rtmpBackUrl =>
      'rtmp://$rtmpHost:$rtmpPort/$rtmpApp/${rollNumber}_back';

  // ── Viewer ──────────────────────────────────────────────
  static const String viewerUrl =
      'http://$rtmpHost:8081/web/player.html';

  // ── Encoder Settings ────────────────────────────────────
  static const int videoWidth = 1280;
  static const int videoHeight = 720;
  static const int videoFps = 25;
  static const int videoBitrateKbps = 1500; // 1.5 Mbps
  static const int keyframeIntervalSec = 2;
  static const String videoCodec = 'H.264';
  static const String audioCodec = 'AAC';

  // ── Reconnect Policy ────────────────────────────────────
  static const int maxReconnectAttempts = 10;
  static const Duration initialReconnectDelay = Duration(seconds: 2);
  static const Duration maxReconnectDelay = Duration(seconds: 30);

  // ── App Info ────────────────────────────────────────────
  static const String appName = 'MoboSafe';
  static const String appTagline = 'Pocket Dashcam';
}
