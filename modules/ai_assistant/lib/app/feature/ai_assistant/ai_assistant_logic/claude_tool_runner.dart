import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_api_const.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_api_service.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_message.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_response.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_tool.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';

enum ClaudeRunOutcome {
  /// Normal finish (`end_turn`, `max_tokens`, `stop_sequence`).
  completed,
  refused,

  /// The iteration cap fired — treat as a bug in the tools or the prompt.
  iterationCapReached,
}

class ClaudeToolRunResult {
  /// Full history including every assistant turn and tool_result turn. Feed
  /// this straight back in as the next `history`.
  final List<ClaudeMessage> messages;
  final ClaudeResponse? response;
  final ClaudeRunOutcome outcome;
  final int iterations;
  final ClaudeUsage usage;

  const ClaudeToolRunResult({
    required this.messages,
    required this.response,
    required this.outcome,
    required this.iterations,
    required this.usage,
  });

  String get text => response?.text ?? '';
}

/// Runs the tool loop: ask → execute → send results → repeat until the model
/// stops asking for tools, with a hard iteration cap.
class ClaudeToolRunner {
  ClaudeToolRunner({
    required this.tools,
    required this.handlers,
    ClaudeRepo? repo,
    this.system,
    this.model,
    this.effort = ClaudeEffort.high,
    this.maxIterations = ClaudeApiConstant.toolLoopMaxIterations,
    this.onStep,
  }) : repo = repo ?? ClaudeRepo();

  final ClaudeRepo repo;
  final List<ClaudeTool> tools;
  final Map<String, ClaudeToolHandler> handlers;
  final String? system;
  final String? model;
  final ClaudeEffort effort;
  final int maxIterations;

  /// Called once per model turn — useful for streaming progress into the UI.
  final void Function(ClaudeResponse response)? onStep;

  Future<ClaudeToolRunResult> run(
    List<ClaudeMessage> history, {
    CancelToken? cancelToken,
  }) async {
    final messages = List<ClaudeMessage>.of(history);
    var usage = const ClaudeUsage();
    var iterations = 0;
    ClaudeResponse? last;

    while (iterations < maxIterations) {
      iterations++;
      final response = await repo.send(
        messages: messages,
        system: system,
        tools: tools,
        model: model,
        effort: effort,
        cancelToken: cancelToken,
      );
      last = response;
      usage = usage + response.usage;
      onStep?.call(response);

      // Check stop_reason BEFORE reading content: on a refusal the content list
      // may be empty or partial, so indexing it would crash.
      if (response.isRefusal) {
        return ClaudeToolRunResult(
          messages: messages,
          response: response,
          outcome: ClaudeRunOutcome.refused,
          iterations: iterations,
          usage: usage,
        );
      }

      messages.add(response.asMessage);

      // A server tool hit its own limit: re-send the assistant turn to resume.
      // Never append a "Continue" user message here.
      if (response.isPaused) continue;

      final calls = response.toolUses;
      if (!response.wantsTools || calls.isEmpty) {
        return ClaudeToolRunResult(
          messages: messages,
          response: response,
          outcome: ClaudeRunOutcome.completed,
          iterations: iterations,
          usage: usage,
        );
      }

      // Every tool_result for this turn goes in ONE user message.
      final results = <ClaudeToolResultBlock>[];
      for (final call in calls) {
        results.add(await _execute(call));
      }
      messages.add(ClaudeMessage.toolResults(results));
    }

    devPrint('ClaudeToolRunner: hit the $maxIterations iteration cap');
    return ClaudeToolRunResult(
      messages: messages,
      response: last,
      outcome: ClaudeRunOutcome.iterationCapReached,
      iterations: iterations,
      usage: usage,
    );
  }

  /// A failure still returns a tool_result with `is_error` — dropping it leaves
  /// an unanswered tool_use and the next request is rejected.
  Future<ClaudeToolResultBlock> _execute(ClaudeToolUseBlock call) async {
    final handler = handlers[call.name];
    if (handler == null) {
      return ClaudeToolResultBlock(
        toolUseId: call.id,
        content: 'Unknown tool "${call.name}".',
        isError: true,
      );
    }
    try {
      final output = await handler(call.input);
      return ClaudeToolResultBlock(
        toolUseId: call.id,
        content: _encode(output),
      );
    } catch (e) {
      devPrint('ClaudeToolRunner: tool ${call.name} threw $e');
      return ClaudeToolResultBlock(
        toolUseId: call.id,
        content: 'Tool "${call.name}" failed: $e',
        isError: true,
      );
    }
  }

  static String _encode(Object? output) {
    if (output == null) return '';
    if (output is String) return output;
    try {
      return jsonEncode(output);
    } catch (_) {
      return output.toString();
    }
  }
}
