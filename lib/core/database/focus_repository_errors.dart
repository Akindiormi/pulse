enum FocusRepositoryErrorKind {
  unauthenticated,
  notFound,
  invalidTransition,
  permissionDenied,
  duplicateActiveSession,
  database,
}

class FocusRepositoryException implements Exception {
  const FocusRepositoryException(this.kind, this.message, {this.cause});

  final FocusRepositoryErrorKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => 'FocusRepositoryException($kind): $message';
}
