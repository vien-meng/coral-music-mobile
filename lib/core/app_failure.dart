enum AppFailureCode {
  cancelled,
  timeout,
  noNetwork,
  badResponse,
  invalidData,
  unknown,
}

final class AppFailure implements Exception {
  const AppFailure({
    required this.code,
    required this.message,
    this.diagnostic,
  });

  final AppFailureCode code;
  final String message;
  final String? diagnostic;

  @override
  String toString() => message;
}
