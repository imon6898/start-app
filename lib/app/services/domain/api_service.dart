import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart' as res;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../routes/app_routes.dart';
import '../../utils/constants/app_colors.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';
import '../local_data/cache_manager.dart';
import 'api_const.dart';
import 'dev_tools.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ApiService {
  late Dio _dio;
  static bool _isRefreshing = false;
  static Completer<bool>? _refreshCompleter;

  ApiService({bool? googleBaseUrl, bool? secondaryBaseUrl}) {
    final BaseOptions options = BaseOptions(
      baseUrl: googleBaseUrl == true
          ? ApiConstant.googleBaseUrl
          : secondaryBaseUrl == true
          ? ApiConstant.activeSecondaryBaseUrl
          : ApiConstant.activeBaseUrl,
      receiveTimeout: const Duration(seconds: 50),
      connectTimeout: const Duration(seconds: 50),
    );

    options.headers['Accept'] = 'application/json';
    options.headers['Content-Type'] = 'application/json';

    try {
      devPrint('token: ${CacheManager.token}');
      options.headers['Authorization'] = 'Bearer ${CacheManager.token}';
    } catch (e) {
      devPrint('Authorization header error = $e');
    }

    _dio = Dio(options);
    // No badCertificateCallback: an untrusted chain must fail in every build.
    // To proxy locally, add the proxy CA to the device trust store instead.

    // Add token refresh interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Always use the latest token from cache for each request
          final token = CacheManager.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode != 401) {
            return handler.next(error);
          }

          // Skip if this is already a retried request (prevent infinite loop)
          if (error.requestOptions.extra['isRetry'] == true) {
            return handler.next(error);
          }

          // Skip refresh for guest users (no refresh token)
          final refreshToken = CacheManager.refreshToken;
          if (refreshToken == null || refreshToken.isEmpty) {
            return handler.next(error);
          }

          // If already refreshing, wait for the ongoing refresh to finish
          if (_isRefreshing) {
            try {
              final success = await _refreshCompleter?.future ?? false;
              if (success) {
                // Retry with new token
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer ${CacheManager.token}';
                opts.extra['isRetry'] = true;
                final retryResponse = await _dio.fetch(opts);
                return handler.resolve(retryResponse);
              } else {
                return handler.next(error);
              }
            } catch (e) {
              return handler.next(error);
            }
          }

          // Start refreshing
          _isRefreshing = true;
          final completer = Completer<bool>();
          _refreshCompleter = completer;

          bool refreshed = false;
          try {
            refreshed = await _refreshToken();
          } catch (e) {
            devPrint('Token refresh error: $e');
            refreshed = false;
          } finally {
            if (!completer.isCompleted) completer.complete(refreshed);
            _isRefreshing = false;
          }

          if (!refreshed) {
            await _handleSessionExpired();
            return handler.next(error);
          }

          // Refresh succeeded — retry the original request with the new token.
          // A retry failure here is NOT a refresh failure: don't sign the user
          // out. Just bubble the error up so the caller can handle it.
          try {
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer ${CacheManager.token}';
            opts.extra['isRetry'] = true;
            final retryResponse = await _dio.fetch(opts);
            return handler.resolve(retryResponse);
          } catch (e) {
            devPrint('Retry after refresh failed: $e');
            return handler.next(error);
          }
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 290,
        ),
      );
    }
  }

  /// Calls the refresh token API and updates stored tokens
  static Future<bool> _refreshToken() async {
    try {
      final refreshToken = CacheManager.refreshToken;

      if (refreshToken == null || refreshToken.isEmpty) {
        devPrint('No refresh token available');
        return false;
      }

      devPrint('Attempting token refresh...');

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiConstant.activeBaseUrl,
          receiveTimeout: const Duration(seconds: 30),
          connectTimeout: const Duration(seconds: 30),
        ),
      );

      final response = await refreshDio.get(
        ApiConstant.refreshTokenUri,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $refreshToken',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData == null) {
          devPrint('Token refresh failed: null response data');
          return false;
        }

        // Handle both nested (data.access_token) and flat (access_token) response structures
        final data = responseData['data'] ?? responseData;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await CacheManager.setToken(newAccessToken);
          devPrint('Access token refreshed successfully');
        }
        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await CacheManager.setRefreshToken(newRefreshToken);
          devPrint('Refresh token updated successfully');
        }

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          return true;
        }
      }

      devPrint(
        'Token refresh failed: unexpected response (status: ${response.statusCode})',
      );
      return false;
    } catch (e) {
      devPrint('Token refresh failed: $e');
      return false;
    }
  }

  /// Clears tokens and navigates to sign-in screen
  static Future<void> _handleSessionExpired() async {
    devPrint('Session expired, clearing data and navigating to sign-in');
    await CacheManager.removeToken();
    await CacheManager.removeRefreshToken();
    await CacheManager.removeUserData();
    // Defer navigation to avoid calling it during a build/frame cycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.offAllNamed(AppRoutes.SigninScreen);
    });
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? params,
    Map<String, dynamic>? data,
  }) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }

    res.Response response;
    try {
      // If params are passed, they will be added as query parameters
      response = await _dio.get(
        endpoint,
        queryParameters: params, // Dynamically pass query parameters
        data: data,
      );
      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'get = $endpoint');
      devPrint('Get api error data = ${e.response}');
      devPrint('Get api error data status code = ${e.response?.statusCode}');
    }
  }

  Future<dynamic> post(String endpoint, [dynamic params]) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }
    res.Response response;
    try {
      devPrint('ApiService.post: endpoint = $endpoint');
      devPrint('ApiService.post: params = $params');
      devPrint('ApiService.post: params type = ${params?.runtimeType}');

      response = await _dio.post(endpoint, data: params);
      devPrint('ApiService.post: statusCode = ${response.statusCode}');

      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'post = $endpoint');
      devPrint('check response Repo api service e = $e');
      devPrint(
        'check response Repo api service status code = ${e.response?.statusCode}',
      );
      devPrint(
        'check response Repo api service e.message = ${e.response?.data}',
      );
      // if (e.response?.statusCode == null) {
      //  Get.offAllNamed(AppRoutes.SigninScreen);
      // }

      devPrint(
        "check response Repo api service = ${e.response?.data['error']}",
      );
      return e.response;
    }
  }

  Future<dynamic> patch(String endpoint, [dynamic params]) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }
    res.Response response;
    try {
      response = await _dio.patch(endpoint, data: params);
      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'patch = $endpoint');
      devPrint(
        "check response Repo api service patch method  = ${e.response?.data['error']}",
      );
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> params) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }
    res.Response response;
    try {
      response = await _dio.put(endpoint, data: params);
      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'put = $endpoint');
      devPrint(
        "check response Repo api service = ${e.response?.data['error']}",
      );
    }
  }

  Future<dynamic> delete(String endpoint, [dynamic params]) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }
    res.Response response;
    try {
      response = await _dio.delete(endpoint, data: params);
      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'delete= $endpoint');
      devPrint('check response Repo api service = $e');
      devPrint('check response Repo api service = ${e.response?.statusCode}');
      devPrint('check response Repo api service = ${e.message}');
      devPrint(
        "check response Repo api service = ${e.response?.data['error']}",
      );
    }
  }

  Future<dynamic> multipleFileUpload(
    String path,
    Map<String, dynamic> body, {
    required Map<String, File> files,
    String replaceFileKey = '',
  }) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }
    final formData = res.FormData.fromMap(body);

    for (var entry in files.entries) {
      // Validate file path before attempting to create multipart file
      if (entry.value.path.isEmpty) {
        devPrint('⚠️ Skipping file with empty path: ${entry.key}');
        continue;
      }

      // Check if file exists
      if (!await entry.value.exists()) {
        devPrint('⚠️ Skipping non-existent file: ${entry.value.path}');
        continue;
      }

      try {
        final filePath = entry.value.path;
        final fileName = filePath.split('/').last;
        final ext = fileName.split('.').last.toLowerCase();
        final mimeType = switch (ext) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'pdf' => 'application/pdf',
          'gif' => 'image/gif',
          'webp' => 'image/webp',
          _ => 'application/octet-stream',
        };
        formData.files.add(
          MapEntry(
            replaceFileKey.isEmpty ? entry.key : replaceFileKey,
            await res.MultipartFile.fromFile(
              filePath,
              filename: fileName,
              contentType: DioMediaType.parse(mimeType),
            ),
          ),
        );
      } catch (e) {
        devPrint('❌ Error processing file ${entry.value.path}: $e');
        continue;
      }
    }

    try {
      final response = await _dio.post(path, data: formData);
      // Return the full response to match other API methods
      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'POST $path');
      // Return the error response (if available) for upstream handling, similar to post()
      return e.response;
    }
  }

  /// Upload files with support for multiple files with the same key
  /// filesMap can contain:
  /// - `File`: single file with the key
  /// - `List<File>`: multiple files all with the same key
  Future<dynamic> multipleFileUploadWithList(
    String path,
    Map<String, dynamic> body, {
    required Map<String, dynamic> filesMap,
  }) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }
    final formData = res.FormData.fromMap(body);

    for (var entry in filesMap.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is File) {
        // Single file
        if (value.path.isEmpty || !await value.exists()) {
          devPrint('⚠️ Skipping non-existent file: ${value.path}');
          continue;
        }
        try {
          formData.files.add(
            MapEntry(
              key,
              await res.MultipartFile.fromFile(
                value.path,
                filename: value.path.split('/').last,
              ),
            ),
          );
        } catch (e) {
          devPrint('❌ Error processing file ${value.path}: $e');
        }
      } else if (value is List<File>) {
        // Multiple files with same key
        for (final file in value) {
          if (file.path.isEmpty || !await file.exists()) {
            devPrint('⚠️ Skipping non-existent file: ${file.path}');
            continue;
          }
          try {
            formData.files.add(
              MapEntry(
                key,
                await res.MultipartFile.fromFile(
                  file.path,
                  filename: file.path.split('/').last,
                ),
              ),
            );
          } catch (e) {
            devPrint('❌ Error processing file ${file.path}: $e');
          }
        }
      }
    }

    try {
      final response = await _dio.post(path, data: formData);
      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'POST $path');
      return e.response;
    }
  }

  Future<dynamic> multipleFileUploadPut(
    String path,
    Map<String, dynamic> body, {
    required Map<String, File> files,
    String replaceFileKey = '',
  }) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }
    final formData = res.FormData.fromMap(body);

    for (var entry in files.entries) {
      // Validate file path before attempting to create multipart file
      if (entry.value.path.isEmpty) {
        devPrint('⚠️ Skipping file with empty path: ${entry.key}');
        continue;
      }

      // Check if file exists
      if (!await entry.value.exists()) {
        devPrint('⚠️ Skipping non-existent file: ${entry.value.path}');
        continue;
      }

      try {
        final filePath = entry.value.path;
        final fileName = filePath.split('/').last;
        final ext = fileName.split('.').last.toLowerCase();
        final mimeType = switch (ext) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'pdf' => 'application/pdf',
          'gif' => 'image/gif',
          'webp' => 'image/webp',
          _ => 'application/octet-stream',
        };
        formData.files.add(
          MapEntry(
            replaceFileKey.isEmpty ? entry.key : replaceFileKey,
            await res.MultipartFile.fromFile(
              filePath,
              filename: fileName,
              contentType: DioMediaType.parse(mimeType),
            ),
          ),
        );
      } catch (e) {
        devPrint('❌ Error processing file ${entry.value.path}: $e');
        continue;
      }
    }

    try {
      final response = await _dio.put(path, data: formData);
      // Return the full response to match other API methods
      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'POST $path');
      // Return the error response (if available) for upstream handling, similar to post()
      return e.response;
    }
  }

  Future<dynamic> multipleFileUploadPatch(
    String path,
    Map<String, dynamic> body, {
    required Map<String, File> files,
    String replaceFileKey = '',
  }) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }
    final formData = res.FormData.fromMap(body);

    for (var entry in files.entries) {
      // Validate file path before attempting to create multipart file
      if (entry.value.path.isEmpty) {
        devPrint('⚠️ Skipping file with empty path: ${entry.key}');
        continue;
      }

      // Check if file exists
      if (!await entry.value.exists()) {
        devPrint('⚠️ Skipping non-existent file: ${entry.value.path}');
        continue;
      }

      try {
        final filePath = entry.value.path;
        final fileName = filePath.split('/').last;
        final ext = fileName.split('.').last.toLowerCase();
        final mimeType = switch (ext) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'pdf' => 'application/pdf',
          'gif' => 'image/gif',
          'webp' => 'image/webp',
          _ => 'application/octet-stream',
        };
        formData.files.add(
          MapEntry(
            replaceFileKey.isEmpty ? entry.key : replaceFileKey,
            await res.MultipartFile.fromFile(
              filePath,
              filename: fileName,
              contentType: DioMediaType.parse(mimeType),
            ),
          ),
        );
      } catch (e) {
        devPrint('❌ Error processing file ${entry.value.path}: $e');
        continue;
      }
    }

    try {
      final response = await _dio.patch(path, data: formData);
      // Return the full response to match other API methods
      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'PATCH $path');
      // Return the error response (if available) for upstream handling, similar to post()
      return e.response;
    }
  }

  Future<dynamic> patchMultipleFileUploadWithList(
    String path,
    Map<String, dynamic> body, {
    required Map<String, dynamic> filesMap,
  }) async {
    //check internet connection
    if (!await checkInternet()) {
      showCustomSnackBar(
        context: Get.context!,
        type: SnackBarType.Warning,
        title: 'No internet connection'.tr,
        description: 'Please check your internet connection'.tr,
      );
      return null;
    }
    final formData = res.FormData.fromMap(body);

    for (var entry in filesMap.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is File) {
        // Single file
        if (value.path.isEmpty || !await value.exists()) {
          devPrint('⚠️ Skipping non-existent file: ${value.path}');
          continue;
        }
        try {
          formData.files.add(
            MapEntry(
              key,
              await res.MultipartFile.fromFile(
                value.path,
                filename: value.path.split('/').last,
              ),
            ),
          );
        } catch (e) {
          devPrint('❌ Error processing file ${value.path}: $e');
        }
      } else if (value is List<File>) {
        // Multiple files with same key
        for (final file in value) {
          if (file.path.isEmpty || !await file.exists()) {
            devPrint('⚠️ Skipping non-existent file: ${file.path}');
            continue;
          }
          try {
            formData.files.add(
              MapEntry(
                key,
                await res.MultipartFile.fromFile(
                  file.path,
                  filename: file.path.split('/').last,
                ),
              ),
            );
          } catch (e) {
            devPrint('❌ Error processing file ${file.path}: $e');
          }
        }
      }
    }

    try {
      final response = await _dio.patch(path, data: formData);
      return response;
    } on DioException catch (e) {
      errorHandle(e: e, requestMethod: 'PATCH $path');
      return e.response;
    }
  }
}

void errorHandle({
  required DioException e,
  required String requestMethod,
  BuildContext? context,
}) {
  devPrint(' Api Request Method: $requestMethod');
  devPrint(' Api Request Method: ${e.type}');

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      devPrint('DioErrorType.connectTimeout');
      break;
    case DioExceptionType.sendTimeout:
      devPrint('DioErrorType.sendTimeout');
      break;
    case DioExceptionType.receiveTimeout:
      devPrint('DioErrorType.receiveTimeout');
      break;
    case DioExceptionType.cancel:
      devPrint('DioErrorType.cancel');
      break;
    case DioExceptionType.connectionError:
      devPrint('DioErrorType.connectionError');
      break;
    case DioExceptionType.unknown:
      devPrint('DioErrorType.other');
      break;
    case DioExceptionType.badCertificate:
      devPrint('DioErrorType.badCertificate');
      // TODO: Handle this case.
      break;
    case DioExceptionType.badResponse:
      // 401/403 is already handled by the refresh interceptor, which signs the
      // user out via _handleSessionExpired once a refresh fails.
      devPrint('DioErrorType.badResponse ${e.response?.statusCode}');
      break;
    default:
      // covers future DioExceptionType values (e.g. transformTimeout)
      devPrint('DioErrorType unhandled: ${e.type}');
      break;
  }
}

Future<bool> checkInternet() async {
  // connectivity_plus v7 returns a List — comparing it to a bare enum is always
  // false, which silently disabled this guard.
  final results = await Connectivity().checkConnectivity();

  if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
    return false;
  }

  // Optional: Verify real internet access with a ping request
  try {
    final lookup = await InternetAddress.lookup('google.com');
    if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
      return true;
    }
  } catch (_) {
    return false;
  }

  return false;
}

String formatValidationMessages(Map<String, dynamic> messages) {
  final StringBuffer formattedMessages = StringBuffer();

  messages.forEach((key, value) {
    if (value is String) {
      formattedMessages.writeln(value);
    } else if (value is List) {
      for (var message in value) {
        formattedMessages.writeln(message);
      }
    }
  });

  return formattedMessages.toString();
}

SnackbarController showErrorSnackbar({required String message}) {
  return Get.showSnackbar(
    GetSnackBar(
      title: 'Error',
      message: message,
      icon: Icon(LucideIcons.circleAlert, color: CustomColors.white()),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: CustomColors.primary(),

      borderRadius: 20,
      margin: const EdgeInsets.all(10),
      duration: const Duration(seconds: 3),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.slowMiddle,
    ),
  );
}
