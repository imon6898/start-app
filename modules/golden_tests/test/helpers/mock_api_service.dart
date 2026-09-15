// Network-free stand-ins for the HTTP layer.
//
// The seam in this architecture is the abstract `<Name>ApiService`, not
// `ApiService` itself: an Impl constructs `ApiService()` inline, and the real
// `ApiService.get/post` call `checkInternet()` — which does a live
// `InternetAddress.lookup`, so it cannot be stubbed from inside a test.
// Mock the abstract class; never let a test reach ApiService.

import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_starter/app/feature/auth/auth_logic/auth_api_service.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

/// Useful only where an ApiService is injected rather than constructed inline.
class MockApiService extends Mock implements ApiService {}

/// The seam a Repo test should use. Copy this line per feature.
class MockAuthApiService extends Mock implements AuthApiService {}

/// Repos read `response.data`, so a stub has to hand back a real Dio Response.
Response<dynamic> apiResponse(
  Object? body, {
  int statusCode = 200,
  String path = '/test',
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    statusCode: statusCode,
    data: body,
  );
}

/// A DioException shaped like a failed call, for the error branches.
DioException apiError({
  int statusCode = 500,
  Object? body,
  String path = '/test',
  DioExceptionType type = DioExceptionType.badResponse,
}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    type: type,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: body,
    ),
  );
}

/// mocktail needs a fallback for every non-nullable type used with `any()`.
/// Call once in `setUpAll`.
void registerApiFallbacks() {
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(RequestOptions(path: '/'));
}
