/// Represents the status of an API request
enum Status {
  loading,    // Request is in progress
  completed,  // Request completed successfully
  error,      // Request failed with an error
}

/// Generic API response wrapper
class ApiResponse<T> {
  final Status status;
  final T? data;
  final String? message;
  final dynamic error;
  final StackTrace? stackTrace;

  ApiResponse._({
    required this.status,
    this.data,
    this.message,
    this.error,
    this.stackTrace,
  });

  /// Create a loading response
  factory ApiResponse.loading() => ApiResponse._(status: Status.loading);

  /// Create a completed response with data
  factory ApiResponse.completed(T data) => 
      ApiResponse._(status: Status.completed, data: data);

  /// Create an error response
  factory ApiResponse.error({
    String? message,
    dynamic error,
    StackTrace? stackTrace,
  }) =>
      ApiResponse._(
        status: Status.error,
        message: message ?? 'An error occurred',
        error: error,
        stackTrace: stackTrace,
      );

  /// Check if the request is loading
  bool get isLoading => status == Status.loading;

  /// Check if the request completed successfully
  bool get isCompleted => status == Status.completed;

  /// Check if the request failed
  bool get hasError => status == Status.error;

  @override
  String toString() {
    return 'ApiResponse{status: $status, data: $data, message: $message, error: $error}';
  }
}
