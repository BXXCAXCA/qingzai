sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

final class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

final class WebDavException extends AppException {
  const WebDavException(super.message, {super.cause});
}

final class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.cause});
}

final class SyncException extends AppException {
  const SyncException(super.message, {super.cause});
}

final class TransferException extends AppException {
  const TransferException(super.message, {super.cause});
}

final class UpdateException extends AppException {
  const UpdateException(super.message, {super.cause});
}
