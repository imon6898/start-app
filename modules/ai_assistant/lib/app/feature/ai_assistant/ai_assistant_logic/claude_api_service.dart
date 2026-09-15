import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_api_const.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_sse_parser.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_message.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_response.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_tool.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/services/local_data/cache_manager.dart';

/// Transport for POST /v1/messages. Two implementations: the proxy (default)
/// and the direct client (debug only).
abstract class ClaudeApiService {
  Future<dynamic> postMessage(
    String url,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  });

  Stream<ClaudeStreamEvent> streamMessage(
    String url,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  });
}

/// DEFAULT. Talks to YOUR backend, which holds the Anthropic key, authenticates
/// your user, enforces per-user quota, and pipes the SSE stream straight
/// through. No Anthropic credential ever reaches the app binary.
class ClaudeProxyClient extends ClaudeApiService {
  ClaudeProxyClient({Dio? dio, String? baseUrl})
    : _dio = dio ?? _build(baseUrl ?? ClaudeApiConstant.proxyBaseUrl);

  final Dio _dio;

  static Dio _build(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ClaudeApiConstant.connectTimeout,
        receiveTimeout: ClaudeApiConstant.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    // Your own session token — the backend maps it to a user and a quota.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = CacheManager.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  @override
  Future<dynamic> postMessage(
    String url,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) => _post(_dio, url, params, cancelToken: cancelToken);

  @override
  Stream<ClaudeStreamEvent> streamMessage(
    String url,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) => _stream(_dio, url, params, cancelToken: cancelToken);
}

/// DEBUG ONLY. Talks to api.anthropic.com with a key read from `.env`.
///
/// An API key inside an app binary is extractable — anyone who pulls the APK
/// can spend your Anthropic budget without limit. Refuses to construct outside
/// a debug build for exactly that reason.
class ClaudeDirectClient extends ClaudeApiService {
  ClaudeDirectClient({Dio? dio, String? apiKey}) {
    assert(kDebugMode, 'ClaudeDirectClient must never ship in a release build.');
    if (!kDebugMode) {
      throw StateError(
        'ClaudeDirectClient is debug-only: it puts an extractable Anthropic '
        'API key in the app binary. Use ClaudeProxyClient in release builds.',
      );
    }
    devPrint(
      '⚠️ ClaudeDirectClient: calling api.anthropic.com directly with a '
      'bundled key. Debug only — switch to ClaudeProxyClient before shipping.',
    );
    _dio = dio ?? _build(apiKey ?? ClaudeApiConstant.anthropicApiKey);
  }

  late final Dio _dio;

  static Dio _build(String apiKey) {
    if (apiKey.isEmpty) {
      throw const ClaudeApiException(
        'ANTHROPIC_API_KEY is not set in .env (ClaudeDirectClient, debug only)',
      );
    }
    return Dio(
      BaseOptions(
        baseUrl: ClaudeApiConstant.anthropicBaseUrl,
        connectTimeout: ClaudeApiConstant.connectTimeout,
        receiveTimeout: ClaudeApiConstant.receiveTimeout,
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': ClaudeApiConstant.anthropicVersion,
          'content-type': 'application/json',
        },
      ),
    );
  }

  @override
  Future<dynamic> postMessage(
    String url,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) => _post(_dio, url, params, cancelToken: cancelToken);

  @override
  Stream<ClaudeStreamEvent> streamMessage(
    String url,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) => _stream(_dio, url, params, cancelToken: cancelToken);
}

Future<dynamic> _post(
  Dio dio,
  String url,
  Map<String, dynamic> params, {
  CancelToken? cancelToken,
}) async {
  try {
    return await dio.post<dynamic>(url, data: params, cancelToken: cancelToken);
  } on DioException catch (e) {
    throw _toException(e);
  }
}

Stream<ClaudeStreamEvent> _stream(
  Dio dio,
  String url,
  Map<String, dynamic> params, {
  CancelToken? cancelToken,
}) async* {
  Response<ResponseBody> response;
  try {
    response = await dio.post<ResponseBody>(
      url,
      data: params,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );
  } on DioException catch (e) {
    // In stream mode the error body is an unread ResponseBody — drain it or the
    // real message ("max_tokens must be …") is lost.
    throw await _toStreamException(e);
  }

  final body = response.data;
  if (body == null) {
    throw ClaudeApiException(
      'Empty SSE response',
      statusCode: response.statusCode,
    );
  }

  final parser = ClaudeSseParser();
  await for (final chunk in body.stream) {
    for (final event in parser.addBytes(chunk)) {
      yield event;
    }
  }
  for (final event in parser.flush()) {
    yield event;
  }
}

ClaudeApiException _toException(DioException e) {
  if (CancelToken.isCancel(e)) {
    return const ClaudeApiException('Cancelled', type: 'cancelled');
  }
  if (e.response != null) {
    return ClaudeApiException.fromBody(
      e.response!.data,
      statusCode: e.response!.statusCode,
    );
  }
  return ClaudeApiException(e.message ?? 'Network error', type: e.type.name);
}

Future<ClaudeApiException> _toStreamException(DioException e) async {
  final data = e.response?.data;
  if (data is ResponseBody) {
    try {
      final bytes = <int>[];
      await for (final chunk in data.stream) {
        bytes.addAll(chunk);
      }
      return ClaudeApiException.fromBody(
        jsonDecode(utf8.decode(bytes, allowMalformed: true)),
        statusCode: e.response?.statusCode,
      );
    } catch (_) {
      return ClaudeApiException(
        'Stream failed',
        statusCode: e.response?.statusCode,
      );
    }
  }
  return _toException(e);
}

/// Owns the endpoint choice and the request body; unwraps `response.data`.
class ClaudeRepo {
  ClaudeRepo({ClaudeApiService? client})
    : claudeApiService = client ?? ClaudeProxyClient();

  final ClaudeApiService claudeApiService;

  /// The direct client posts to Anthropic's path, the proxy to yours.
  String get _messagesUri => claudeApiService is ClaudeDirectClient
      ? ClaudeApiConstant.anthropicMessagesUri
      : ClaudeApiConstant.proxyMessagesUri;

  Future<ClaudeResponse> send({
    required List<ClaudeMessage> messages,
    String? system,
    List<ClaudeTool> tools = const [],
    String? model,
    int? maxTokens,
    ClaudeEffort effort = ClaudeEffort.high,
    ClaudeThinkingDisplay? thinkingDisplay,
    bool disableThinking = false,
    CancelToken? cancelToken,
  }) async {
    final dynamic response = await claudeApiService.postMessage(
      _messagesUri,
      buildBody(
        messages: messages,
        stream: false,
        system: system,
        tools: tools,
        model: model,
        maxTokens: maxTokens,
        effort: effort,
        thinkingDisplay: thinkingDisplay,
        disableThinking: disableThinking,
      ),
      cancelToken: cancelToken,
    );

    final data = response?.data;
    if (data is! Map) {
      throw const ClaudeApiException('Unexpected response shape');
    }
    final json = Map<String, dynamic>.from(data);
    if (json['type'] == 'error') {
      throw ClaudeApiException.fromBody(json);
    }
    return ClaudeResponse.fromJson(json);
  }

  Stream<ClaudeStreamEvent> stream({
    required List<ClaudeMessage> messages,
    String? system,
    List<ClaudeTool> tools = const [],
    String? model,
    int? maxTokens,
    ClaudeEffort effort = ClaudeEffort.high,
    ClaudeThinkingDisplay? thinkingDisplay,
    bool disableThinking = false,
    CancelToken? cancelToken,
  }) => claudeApiService.streamMessage(
    _messagesUri,
    buildBody(
      messages: messages,
      stream: true,
      system: system,
      tools: tools,
      model: model,
      maxTokens: maxTokens,
      effort: effort,
      thinkingDisplay: thinkingDisplay,
      disableThinking: disableThinking,
    ),
    cancelToken: cancelToken,
  );

  /// Public so a test (or a custom backend contract) can assert on the payload.
  static Map<String, dynamic> buildBody({
    required List<ClaudeMessage> messages,
    required bool stream,
    String? system,
    List<ClaudeTool> tools = const [],
    String? model,
    int? maxTokens,
    ClaudeEffort effort = ClaudeEffort.high,
    ClaudeThinkingDisplay? thinkingDisplay,
    bool disableThinking = false,
  }) {
    if (disableThinking && !effort.allowsDisabledThinking) {
      throw ArgumentError(
        'thinking {"type":"disabled"} is rejected at effort ${effort.wire}; '
        'use high or lower, or leave thinking on.',
      );
    }

    final body = <String, dynamic>{
      'model': model ?? ClaudeApiConstant.defaultModel,
      // Required, and it caps thinking + text together.
      'max_tokens':
          maxTokens ??
          (stream
              ? ClaudeApiConstant.streamingMaxTokens
              : ClaudeApiConstant.nonStreamingMaxTokens),
      'messages': messages.map((m) => m.toJson()).toList(),
      // Nested in output_config, never top-level.
      'output_config': {'effort': effort.wire},
    };
    if (stream) body['stream'] = true;
    if (system != null && system.trim().isNotEmpty) body['system'] = system;
    if (tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
    }
    // Thinking is on by default; only emit the field to opt out or to ask for a
    // summary. budget_tokens is removed and returns 400 — never send it.
    if (disableThinking) {
      body['thinking'] = {'type': 'disabled'};
    } else if (thinkingDisplay != null) {
      body['thinking'] = {'type': 'adaptive', 'display': thinkingDisplay.wire};
    }
    // No temperature / top_p / top_k: removed on claude-opus-5, they return 400.
    return body;
  }
}
