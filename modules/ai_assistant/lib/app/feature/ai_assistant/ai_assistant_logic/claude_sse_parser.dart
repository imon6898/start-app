import 'dart:convert';

import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_message.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_response.dart';

/// One decoded SSE event from `/v1/messages` with `"stream": true`.
sealed class ClaudeStreamEvent {
  const ClaudeStreamEvent();
}

class ClaudeMessageStartEvent extends ClaudeStreamEvent {
  final String? id;
  final String? model;
  final ClaudeUsage usage;
  const ClaudeMessageStartEvent({this.id, this.model, required this.usage});
}

class ClaudeBlockStartEvent extends ClaudeStreamEvent {
  final int index;
  final String type;
  final String? toolUseId;
  final String? toolName;
  const ClaudeBlockStartEvent({
    required this.index,
    required this.type,
    this.toolUseId,
    this.toolName,
  });
}

class ClaudeTextDeltaEvent extends ClaudeStreamEvent {
  final int index;
  final String text;
  const ClaudeTextDeltaEvent(this.index, this.text);
}

class ClaudeThinkingDeltaEvent extends ClaudeStreamEvent {
  final int index;
  final String thinking;
  const ClaudeThinkingDeltaEvent(this.index, this.thinking);
}

class ClaudeSignatureDeltaEvent extends ClaudeStreamEvent {
  final int index;
  final String signature;
  const ClaudeSignatureDeltaEvent(this.index, this.signature);
}

/// Tool input arrives as a JSON string in fragments; only valid once complete.
class ClaudeInputJsonDeltaEvent extends ClaudeStreamEvent {
  final int index;
  final String partialJson;
  const ClaudeInputJsonDeltaEvent(this.index, this.partialJson);
}

class ClaudeBlockStopEvent extends ClaudeStreamEvent {
  final int index;
  const ClaudeBlockStopEvent(this.index);
}

class ClaudeMessageDeltaEvent extends ClaudeStreamEvent {
  final ClaudeStopReason stopReason;
  final String? stopReasonWire;
  final String? refusalCategory;
  final int outputTokens;
  const ClaudeMessageDeltaEvent({
    required this.stopReason,
    this.stopReasonWire,
    this.refusalCategory,
    this.outputTokens = 0,
  });
}

class ClaudeMessageStopEvent extends ClaudeStreamEvent {
  const ClaudeMessageStopEvent();
}

class ClaudePingEvent extends ClaudeStreamEvent {
  const ClaudePingEvent();
}

/// An `{"type":"error"}` frame — the stream can fail mid-flight after a 200.
class ClaudeStreamErrorEvent extends ClaudeStreamEvent {
  final String? type;
  final String message;
  const ClaudeStreamErrorEvent(this.message, {this.type});
}

/// Byte-oriented SSE line parser. Buffers across chunks so a `data:` line split
/// mid-UTF-8 or mid-JSON is never decoded twice.
class ClaudeSseParser {
  final List<int> _buffer = <int>[];
  static const int _newline = 10; // \n
  static const int _carriageReturn = 13; // \r

  List<ClaudeStreamEvent> addBytes(List<int> chunk) {
    _buffer.addAll(chunk);
    final events = <ClaudeStreamEvent>[];
    var start = 0;
    for (var i = 0; i < _buffer.length; i++) {
      if (_buffer[i] != _newline) continue;
      var end = i;
      if (end > start && _buffer[end - 1] == _carriageReturn) end--;
      final event = _parseLine(
        utf8.decode(_buffer.sublist(start, end), allowMalformed: true),
      );
      if (event != null) events.add(event);
      start = i + 1;
    }
    _buffer.removeRange(0, start);
    return events;
  }

  /// Handy for tests and for a backend that hands you text rather than bytes.
  List<ClaudeStreamEvent> addChunk(String chunk) => addBytes(utf8.encode(chunk));

  /// Drains a trailing line that arrived without a final newline.
  List<ClaudeStreamEvent> flush() {
    if (_buffer.isEmpty) return const [];
    final line = utf8.decode(_buffer, allowMalformed: true);
    _buffer.clear();
    final event = _parseLine(line);
    return event == null ? const [] : [event];
  }

  ClaudeStreamEvent? _parseLine(String line) {
    final trimmed = line.trim();
    // `event:` lines are redundant — the JSON payload carries its own type.
    if (trimmed.isEmpty || !trimmed.startsWith('data:')) return null;
    final payload = trimmed.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return parseFrame(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  /// Maps one decoded `data:` payload onto a typed event.
  static ClaudeStreamEvent? parseFrame(Map<String, dynamic> json) {
    final index = (json['index'] as num?)?.toInt() ?? 0;
    switch (json['type']) {
      case 'message_start':
        final message = (json['message'] as Map?)?.cast<String, dynamic>();
        return ClaudeMessageStartEvent(
          id: message?['id'] as String?,
          model: message?['model'] as String?,
          usage: ClaudeUsage.fromJson(
            (message?['usage'] as Map?)?.cast<String, dynamic>(),
          ),
        );
      case 'content_block_start':
        final block = (json['content_block'] as Map?)?.cast<String, dynamic>();
        return ClaudeBlockStartEvent(
          index: index,
          type: (block?['type'] ?? 'text').toString(),
          toolUseId: block?['id'] as String?,
          toolName: block?['name'] as String?,
        );
      case 'content_block_delta':
        final delta = (json['delta'] as Map?)?.cast<String, dynamic>();
        switch (delta?['type']) {
          case 'text_delta':
            return ClaudeTextDeltaEvent(
              index,
              (delta?['text'] ?? '').toString(),
            );
          case 'thinking_delta':
            return ClaudeThinkingDeltaEvent(
              index,
              (delta?['thinking'] ?? '').toString(),
            );
          case 'signature_delta':
            return ClaudeSignatureDeltaEvent(
              index,
              (delta?['signature'] ?? '').toString(),
            );
          case 'input_json_delta':
            return ClaudeInputJsonDeltaEvent(
              index,
              (delta?['partial_json'] ?? '').toString(),
            );
        }
        return null;
      case 'content_block_stop':
        return ClaudeBlockStopEvent(index);
      case 'message_delta':
        final delta = (json['delta'] as Map?)?.cast<String, dynamic>();
        final details = (delta?['stop_details'] as Map?)
            ?.cast<String, dynamic>();
        return ClaudeMessageDeltaEvent(
          stopReason: claudeStopReasonFrom(delta?['stop_reason'] as String?),
          stopReasonWire: delta?['stop_reason'] as String?,
          refusalCategory: details?['category'] as String?,
          outputTokens:
              ((json['usage'] as Map?)?['output_tokens'] as num?)?.toInt() ?? 0,
        );
      case 'message_stop':
        return const ClaudeMessageStopEvent();
      case 'ping':
        return const ClaudePingEvent();
      case 'error':
        final error = (json['error'] as Map?)?.cast<String, dynamic>();
        return ClaudeStreamErrorEvent(
          (error?['message'] ?? 'Stream error').toString(),
          type: error?['type'] as String?,
        );
    }
    return null;
  }
}

/// Rebuilds a complete [ClaudeResponse] from a stream, so a streamed turn can
/// be appended to history exactly like a non-streamed one.
class ClaudeStreamAccumulator {
  String? id;
  String? model;
  ClaudeStopReason stopReason = ClaudeStopReason.unknown;
  String? stopReasonWire;
  String? refusalCategory;
  ClaudeUsage usage = const ClaudeUsage();

  final Map<int, _BlockBuilder> _blocks = <int, _BlockBuilder>{};
  ClaudeStreamErrorEvent? error;

  void add(ClaudeStreamEvent event) {
    switch (event) {
      case ClaudeMessageStartEvent():
        id = event.id;
        model = event.model;
        usage = event.usage;
      case ClaudeBlockStartEvent():
        _blocks[event.index] = _BlockBuilder(
          type: event.type,
          toolUseId: event.toolUseId,
          toolName: event.toolName,
        );
      case ClaudeTextDeltaEvent():
        _at(event.index, 'text').text.write(event.text);
      case ClaudeThinkingDeltaEvent():
        _at(event.index, 'thinking').text.write(event.thinking);
      case ClaudeSignatureDeltaEvent():
        _at(event.index, 'thinking').signature = event.signature;
      case ClaudeInputJsonDeltaEvent():
        _at(event.index, 'tool_use').json.write(event.partialJson);
      case ClaudeMessageDeltaEvent():
        stopReason = event.stopReason;
        stopReasonWire = event.stopReasonWire;
        refusalCategory = event.refusalCategory ?? refusalCategory;
        if (event.outputTokens > 0) {
          usage = usage.copyWith(outputTokens: event.outputTokens);
        }
      case ClaudeStreamErrorEvent():
        error = event;
      case ClaudeBlockStopEvent():
      case ClaudeMessageStopEvent():
      case ClaudePingEvent():
        break;
    }
  }

  _BlockBuilder _at(int index, String type) =>
      _blocks.putIfAbsent(index, () => _BlockBuilder(type: type));

  /// Text seen so far — what the UI renders while tokens arrive.
  String get text => _join('text');

  String get thinking => _join('thinking');

  String _join(String type) {
    final keys = _blocks.keys.where((k) => _blocks[k]!.type == type).toList()
      ..sort();
    return keys.map((k) => _blocks[k]!.text.toString()).join('\n').trim();
  }

  bool get isEmpty => _blocks.isEmpty;

  ClaudeResponse build() {
    final keys = _blocks.keys.toList()..sort();
    final content = <ClaudeBlock>[];
    for (final key in keys) {
      final block = _blocks[key]!;
      switch (block.type) {
        case 'text':
          final value = block.text.toString();
          if (value.isNotEmpty) content.add(ClaudeTextBlock(value));
        case 'thinking':
          content.add(
            ClaudeThinkingBlock(
              block.text.toString(),
              signature: block.signature,
            ),
          );
        case 'tool_use':
          content.add(
            ClaudeToolUseBlock(
              id: block.toolUseId ?? '',
              name: block.toolName ?? '',
              input: block.decodeInput(),
            ),
          );
      }
    }
    return ClaudeResponse(
      id: id,
      model: model,
      stopReason: stopReason,
      stopReasonWire: stopReasonWire,
      refusalCategory: refusalCategory,
      content: content,
      usage: usage,
    );
  }
}

class _BlockBuilder {
  _BlockBuilder({required this.type, this.toolUseId, this.toolName});

  final String type;
  final String? toolUseId;
  final String? toolName;
  final StringBuffer text = StringBuffer();
  final StringBuffer json = StringBuffer();
  String? signature;

  /// An interrupted stream leaves half a JSON object; treat that as no input
  /// rather than crashing the turn.
  Map<String, dynamic> decodeInput() {
    final raw = json.toString();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
