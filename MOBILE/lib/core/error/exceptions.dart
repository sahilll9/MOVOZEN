/// Base exception for the data layer.
///
/// These are thrown by data sources and caught by repository
/// implementations, which then map them to domain [Failure]s.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => 'AppException: $message';
}

class CameraException extends AppException {
  const CameraException(super.message);
}

class StreamException extends AppException {
  const StreamException(super.message);
}

class PermissionException extends AppException {
  const PermissionException(super.message);
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}
