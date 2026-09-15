// Style A: the Repo owns the endpoint, the Impl is the only place ApiService()
// is constructed.

import 'dart:convert';

import 'package:flutter_starter/app/services/domain/api_service.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';

import 'feature_flags_api_const.dart';

abstract class FeatureFlagsApiService {
  Future<dynamic> getFlags(String url, {Map<String, dynamic>? params});
}

class FeatureFlagsImpl extends FeatureFlagsApiService {
  @override
  Future<dynamic> getFlags(String url, {Map<String, dynamic>? params}) =>
      ApiService().get(url, params: params);
}

class FeatureFlagsRepo {
  final FeatureFlagsApiService _api = FeatureFlagsImpl();

  /// The document as a JSON string, or null on any failure — the caller then
  /// keeps the cached copy instead of dropping to hardcoded defaults.
  Future<String?> fetchDocument({
    String? userId,
    Map<String, dynamic>? extraParams,
  }) async {
    final params = <String, dynamic>{
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      ...?extraParams,
    };

    final response = await _api.getFlags(
      FeatureFlagsApiConst.flagsUri,
      params: params.isEmpty ? null : params,
    );
    if (response == null) return null;

    final status = response.statusCode as int?;
    if (status != 200 && status != 201) {
      devPrint('Flags: HTTP $status');
      return null;
    }

    final body = _unwrap(response.data);
    if (body == null) {
      devPrint('Flags: response body was not a JSON object');
      return null;
    }
    return jsonEncode(body);
  }

  /// Accepts `{...}`, `{"data": {...}}` and `{"flags": {...}}`.
  Map<dynamic, dynamic>? _unwrap(dynamic data) {
    if (data is String) {
      try {
        return _unwrap(jsonDecode(data));
      } catch (_) {
        return null;
      }
    }
    if (data is! Map) return null;
    if (data['flags'] is Map || data['experiments'] is Map) return data;
    if (data['data'] is Map) return data['data'] as Map;
    return data;
  }
}
