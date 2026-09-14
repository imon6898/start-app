class BaseResponse<T> {
  final bool status;
  final String path;
  final int statusCode;
  final String message;
  final T? data;

  BaseResponse({
    required this.status,
    required this.path,
    required this.statusCode,
    required this.message,
    this.data,
  });

  factory BaseResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return BaseResponse<T>(
      status: json['status'] != null ? json['status'] as bool : false,
      path: json['path'] != null ? json['path'] as String : '',
      statusCode: json['statusCode'] != null ? json['statusCode'] as int : 0,
      message: json['message'] != null ? json['message'] as String : '',
      data: json['data'] != null ? fromJsonT(json['data']) : null,
    );
  }
}
