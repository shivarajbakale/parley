/// Base class for all API-related exceptions.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when the server returns a 404.
class NotFoundException extends ApiException {
  const NotFoundException(super.message) : super(statusCode: 404);
}

/// Thrown when the server returns a 400 (validation error).
class ValidationException extends ApiException {
  const ValidationException(super.message) : super(statusCode: 400);
}

/// Thrown when the server returns a 500.
class ServerException extends ApiException {
  const ServerException(super.message) : super(statusCode: 500);
}

/// Thrown when there is a network connectivity issue.
class NetworkException extends ApiException {
  const NetworkException(super.message);
}
