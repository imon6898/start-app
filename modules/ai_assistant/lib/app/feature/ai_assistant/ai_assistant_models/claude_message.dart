// Wire model for /v1/messages. The API is stateless: every request carries the
// whole conversation, so blocks must round-trip unchanged.

enum ClaudeRole { user, assistant }

String claudeRoleWire(ClaudeRole role) =>
    role == ClaudeRole.user ? 'user' : 'assistant';

ClaudeRole claudeRoleFrom(String? wire) =>
    wire == 'assistant' ? ClaudeRole.assistant : ClaudeRole.user;

/// One content block inside a message.
sealed class ClaudeBlock {
  const ClaudeBlock();

  Map<String, dynamic> toJson();

  /// Unknown types become [ClaudeUnknownBlock] so a new server block type is
  /// echoed back verbatim instead of being dropped.
  static ClaudeBlock fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'text':
        return ClaudeTextBlock((json['text'] ?? '').toString());
      case 'thinking':
        return ClaudeThinkingBlock(
          (json['thinking'] ?? '').toString(),
          signature: json['signature'] as String?,
        );
      case 'tool_use':
        return ClaudeToolUseBlock(
          id: (json['id'] ?? '').toString(),
          name: (json['name'] ?? '').toString(),
          input: Map<String, dynamic>.from(
            (json['input'] as Map?) ?? const <String, dynamic>{},
          ),
        );
      case 'tool_result':
        return ClaudeToolResultBlock(
          toolUseId: (json['tool_use_id'] ?? '').toString(),
          content: json['content'],
          isError: json['is_error'] == true,
        );
      default:
        return ClaudeUnknownBlock(Map<String, dynamic>.from(json));
    }
  }
}

class ClaudeTextBlock extends ClaudeBlock {
  final String text;
  const ClaudeTextBlock(this.text);

  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'text': text};
}

/// Raw chain of thought is never returned; `display: "summarized"` fills [thinking].
class ClaudeThinkingBlock extends ClaudeBlock {
  final String thinking;
  final String? signature;
  const ClaudeThinkingBlock(this.thinking, {this.signature});

  // Never edit a thinking block before sending it back — the API rejects it.
  @override
  Map<String, dynamic> toJson() => {
    'type': 'thinking',
    'thinking': thinking,
    if (signature != null) 'signature': signature,
  };
}

class ClaudeToolUseBlock extends ClaudeBlock {
  final String id;
  final String name;
  final Map<String, dynamic> input;
  const ClaudeToolUseBlock({
    required this.id,
    required this.name,
    required this.input,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tool_use',
    'id': id,
    'name': name,
    'input': input,
  };
}

class ClaudeToolResultBlock extends ClaudeBlock {
  final String toolUseId;

  /// A string, or a list of content blocks. Never null — a failed tool still
  /// has to report something.
  final Object content;
  final bool isError;
  const ClaudeToolResultBlock({
    required this.toolUseId,
    required this.content,
    this.isError = false,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tool_result',
    'tool_use_id': toolUseId,
    'content': content,
    if (isError) 'is_error': true,
  };
}

/// Block type this client does not model yet; kept so it survives a round-trip.
class ClaudeUnknownBlock extends ClaudeBlock {
  final Map<String, dynamic> raw;
  const ClaudeUnknownBlock(this.raw);

  String get type => (raw['type'] ?? 'unknown').toString();

  @override
  Map<String, dynamic> toJson() => raw;
}

class ClaudeMessage {
  final ClaudeRole role;
  final List<ClaudeBlock> blocks;

  /// Local only — never sent. Used for bubble timestamps.
  final DateTime? createdAt;

  const ClaudeMessage({
    required this.role,
    required this.blocks,
    this.createdAt,
  });

  factory ClaudeMessage.user(String text) => ClaudeMessage(
    role: ClaudeRole.user,
    blocks: [ClaudeTextBlock(text)],
    createdAt: DateTime.now(),
  );

  factory ClaudeMessage.assistantText(String text) => ClaudeMessage(
    role: ClaudeRole.assistant,
    blocks: [ClaudeTextBlock(text)],
    createdAt: DateTime.now(),
  );

  /// All tool_results for one turn belong in a SINGLE user message — splitting
  /// them teaches the model to stop making parallel calls.
  factory ClaudeMessage.toolResults(List<ClaudeToolResultBlock> results) =>
      ClaudeMessage(
        role: ClaudeRole.user,
        blocks: List<ClaudeBlock>.of(results),
        createdAt: DateTime.now(),
      );

  factory ClaudeMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['content'];
    final blocks = <ClaudeBlock>[];
    if (raw is String) {
      blocks.add(ClaudeTextBlock(raw));
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          blocks.add(ClaudeBlock.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return ClaudeMessage(
      role: claudeRoleFrom(json['role'] as String?),
      blocks: blocks,
    );
  }

  String get text => blocks
      .whereType<ClaudeTextBlock>()
      .map((b) => b.text)
      .join('\n')
      .trim();

  String get thinking => blocks
      .whereType<ClaudeThinkingBlock>()
      .map((b) => b.thinking)
      .where((t) => t.isNotEmpty)
      .join('\n')
      .trim();

  List<ClaudeToolUseBlock> get toolUses =>
      blocks.whereType<ClaudeToolUseBlock>().toList();

  List<ClaudeToolResultBlock> get toolResults =>
      blocks.whereType<ClaudeToolResultBlock>().toList();

  bool get isEmpty => blocks.isEmpty;

  ClaudeMessage copyWith({
    ClaudeRole? role,
    List<ClaudeBlock>? blocks,
    DateTime? createdAt,
  }) => ClaudeMessage(
    role: role ?? this.role,
    blocks: blocks ?? this.blocks,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'role': claudeRoleWire(role),
    'content': blocks.map((b) => b.toJson()).toList(),
  };
}
