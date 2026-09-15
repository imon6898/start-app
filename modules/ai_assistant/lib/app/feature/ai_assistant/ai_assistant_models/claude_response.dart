import 'claude_message.dart';

enum ClaudeStopReason {
  endTurn,
  maxTokens,
  stopSequence,
  toolUse,
  pauseTurn,
  refusal,

  /// Not reported yet (mid-stream), or a value this client does not know.
  unknown,
}

ClaudeStopReason claudeStopReasonFrom(String? wire) => switch (wire) {
  'end_turn' => ClaudeStopReason.endTurn,
  'max_tokens' => ClaudeStopReason.maxTokens,
  'stop_sequence' => ClaudeStopReason.stopSequence,
  'tool_use' => ClaudeStopReason.toolUse,
  'pause_turn' => ClaudeStopReason.pauseTurn,
  'refusal' => ClaudeStopReason.refusal,
  _ => ClaudeStopReason.unknown,
};

class ClaudeUsage {
  final int inputTokens;
  final int outputTokens;
  final int cacheCreationInputTokens;
  final int cacheReadInputTokens;

  const ClaudeUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheCreationInputTokens = 0,
    this.cacheReadInputTokens = 0,
  });

  factory ClaudeUsage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ClaudeUsage();
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ClaudeUsage(
      inputTokens: read('input_tokens'),
      outputTokens: read('output_tokens'),
      cacheCreationInputTokens: read('cache_creation_input_tokens'),
      cacheReadInputTokens: read('cache_read_input_tokens'),
    );
  }

  /// `input_tokens` is the uncached remainder only — add the cache fields for
  /// the real prompt size.
  int get totalInputTokens =>
      inputTokens + cacheCreationInputTokens + cacheReadInputTokens;

  ClaudeUsage copyWith({
    int? inputTokens,
    int? outputTokens,
    int? cacheCreationInputTokens,
    int? cacheReadInputTokens,
  }) => ClaudeUsage(
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    cacheCreationInputTokens:
        cacheCreationInputTokens ?? this.cacheCreationInputTokens,
    cacheReadInputTokens: cacheReadInputTokens ?? this.cacheReadInputTokens,
  );

  ClaudeUsage operator +(ClaudeUsage other) => ClaudeUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
    cacheCreationInputTokens:
        cacheCreationInputTokens + other.cacheCreationInputTokens,
    cacheReadInputTokens: cacheReadInputTokens + other.cacheReadInputTokens,
  );
}

class ClaudeResponse {
  final String? id;
  final String? model;
  final ClaudeStopReason stopReason;
  final String? stopReasonWire;

  /// Populated only on a refusal (`cyber`, `bio`, …); null otherwise.
  final String? refusalCategory;
  final String? refusalExplanation;
  final List<ClaudeBlock> content;
  final ClaudeUsage usage;

  const ClaudeResponse({
    this.id,
    this.model,
    this.stopReason = ClaudeStopReason.unknown,
    this.stopReasonWire,
    this.refusalCategory,
    this.refusalExplanation,
    this.content = const [],
    this.usage = const ClaudeUsage(),
  });

  factory ClaudeResponse.fromJson(Map<String, dynamic> json) {
    final blocks = <ClaudeBlock>[];
    final raw = json['content'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          blocks.add(ClaudeBlock.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final details = json['stop_details'];
    return ClaudeResponse(
      id: json['id'] as String?,
      model: json['model'] as String?,
      stopReason: claudeStopReasonFrom(json['stop_reason'] as String?),
      stopReasonWire: json['stop_reason'] as String?,
      refusalCategory: details is Map ? details['category'] as String? : null,
      refusalExplanation: details is Map
          ? details['explanation'] as String?
          : null,
      content: blocks,
      usage: ClaudeUsage.fromJson(
        (json['usage'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  /// Check this BEFORE reading [text] — on a refusal `content` may be empty.
  bool get isRefusal => stopReason == ClaudeStopReason.refusal;

  bool get wantsTools => stopReason == ClaudeStopReason.toolUse;

  /// A server tool hit its iteration limit: re-send the assistant turn to
  /// resume. Do NOT append a "Continue" user message.
  bool get isPaused => stopReason == ClaudeStopReason.pauseTurn;

  bool get wasTruncated => stopReason == ClaudeStopReason.maxTokens;

  String get text => content
      .whereType<ClaudeTextBlock>()
      .map((b) => b.text)
      .join('\n')
      .trim();

  String get thinking => content
      .whereType<ClaudeThinkingBlock>()
      .map((b) => b.thinking)
      .where((t) => t.isNotEmpty)
      .join('\n')
      .trim();

  List<ClaudeToolUseBlock> get toolUses =>
      content.whereType<ClaudeToolUseBlock>().toList();

  /// The assistant turn to append to history before sending the next request.
  ClaudeMessage get asMessage => ClaudeMessage(
    role: ClaudeRole.assistant,
    blocks: content,
    createdAt: DateTime.now(),
  );
}

/// Anything that stops a Claude call: transport failure, HTTP error, or an
/// `{"type":"error"}` envelope from the API.
class ClaudeApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? type;

  const ClaudeApiException(this.message, {this.statusCode, this.type});

  /// Reads the `{"error": {"type", "message"}}` envelope when present.
  factory ClaudeApiException.fromBody(Object? body, {int? statusCode}) {
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        return ClaudeApiException(
          (error['message'] ?? 'Request failed').toString(),
          statusCode: statusCode,
          type: error['type'] as String?,
        );
      }
    }
    if (body is String && body.isNotEmpty) {
      return ClaudeApiException(body, statusCode: statusCode);
    }
    return ClaudeApiException(
      'Request failed${statusCode == null ? '' : ' ($statusCode)'}',
      statusCode: statusCode,
    );
  }

  bool get isRateLimited => statusCode == 429 || type == 'rate_limit_error';
  bool get isOverloaded => statusCode == 529 || type == 'overloaded_error';

  @override
  String toString() => 'ClaudeApiException: $message';
}
