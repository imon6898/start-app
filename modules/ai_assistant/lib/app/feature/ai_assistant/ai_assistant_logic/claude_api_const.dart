import 'package:flutter_starter/app/core/config/env.dart';
import 'package:flutter_starter/app/services/domain/api_const.dart';

/// Hosts, paths and request defaults for the Claude client. Module-local so
/// installing it never requires editing core `api_const.dart`.
class ClaudeApiConstant {
  // Anthropic (ClaudeDirectClient — debug only).
  static const String anthropicBaseUrl = 'https://api.anthropic.com';
  static const String anthropicMessagesUri = '/v1/messages';
  static const String anthropicVersion = '2023-06-01';

  /// Your backend. Defaults to the app's own host, so most projects add no
  /// `.env` keys at all.
  static String get proxyBaseUrl {
    final override = Env.optional('CLAUDE_PROXY_URL');
    return override.isEmpty ? ApiConstant.activeBaseUrl : override;
  }

  static String get proxyMessagesUri =>
      Env.optional('CLAUDE_PROXY_PATH', fallback: '/ai/claude/messages');

  /// Never append a date suffix to a model id.
  static String get defaultModel =>
      Env.optional('CLAUDE_MODEL', fallback: 'claude-opus-5');

  /// Read by ClaudeDirectClient only. Shipping this in a release build is a
  /// financial-loss bug — see the module README.
  static String get anthropicApiKey => Env.optional('ANTHROPIC_API_KEY');

  // max_tokens is REQUIRED and caps thinking + text together.
  static const int nonStreamingMaxTokens = 16000;
  static const int streamingMaxTokens = 64000;

  /// Hard stop for the tool loop so a confused model cannot spin forever.
  static const int toolLoopMaxIterations = 10;

  static const Duration connectTimeout = Duration(seconds: 30);

  /// A single turn at high effort can run for minutes.
  static const Duration receiveTimeout = Duration(minutes: 10);
}

/// `output_config: {"effort": …}` — nested, never top-level. Default is high.
enum ClaudeEffort { low, medium, high, xhigh, max }

extension ClaudeEffortWire on ClaudeEffort {
  String get wire => switch (this) {
    ClaudeEffort.low => 'low',
    ClaudeEffort.medium => 'medium',
    ClaudeEffort.high => 'high',
    ClaudeEffort.xhigh => 'xhigh',
    ClaudeEffort.max => 'max',
  };

  /// `thinking: {"type": "disabled"}` is rejected above `high`.
  bool get allowsDisabledThinking =>
      this != ClaudeEffort.xhigh && this != ClaudeEffort.max;
}

/// `thinking.display`. The API default is `omitted`, which yields thinking
/// blocks with empty text — pick `summarized` to show progress to a user.
enum ClaudeThinkingDisplay { omitted, summarized }

extension ClaudeThinkingDisplayWire on ClaudeThinkingDisplay {
  String get wire =>
      this == ClaudeThinkingDisplay.summarized ? 'summarized' : 'omitted';
}
