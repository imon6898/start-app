import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_api_const.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_api_service.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_sse_parser.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_message.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_response.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_tool.dart';
import 'package:flutter_test/flutter_test.dart';

String _frame(Map<String, dynamic> payload) =>
    'event: ${payload['type']}\ndata: ${jsonEncode(payload)}\n\n';

void main() {
  setUpAll(() {
    // ClaudeApiConstant reads .env through Env; give the test an empty one.
    dotenv.loadFromString(envString: 'BASE_URL=x', isOptional: true);
  });

  group('ClaudeSseParser', () {
    test('decodes a full text turn in order', () {
      final parser = ClaudeSseParser();
      final events = <ClaudeStreamEvent>[
        ...parser.addChunk(
          _frame({
            'type': 'message_start',
            'message': {
              'id': 'msg_1',
              'model': 'claude-opus-5',
              'usage': {'input_tokens': 12, 'cache_read_input_tokens': 900},
            },
          }),
        ),
        ...parser.addChunk(
          _frame({
            'type': 'content_block_start',
            'index': 0,
            'content_block': {'type': 'text', 'text': ''},
          }),
        ),
        ...parser.addChunk(
          _frame({
            'type': 'content_block_delta',
            'index': 0,
            'delta': {'type': 'text_delta', 'text': 'Hello'},
          }),
        ),
        ...parser.addChunk(
          _frame({
            'type': 'content_block_delta',
            'index': 0,
            'delta': {'type': 'text_delta', 'text': ' world'},
          }),
        ),
        ...parser.addChunk(_frame({'type': 'content_block_stop', 'index': 0})),
        ...parser.addChunk(
          _frame({
            'type': 'message_delta',
            'delta': {'stop_reason': 'end_turn'},
            'usage': {'output_tokens': 7},
          }),
        ),
        ...parser.addChunk(_frame({'type': 'message_stop'})),
      ];

      expect(events.first, isA<ClaudeMessageStartEvent>());
      expect(events.whereType<ClaudeTextDeltaEvent>().length, 2);
      expect(events.last, isA<ClaudeMessageStopEvent>());
    });

    test('buffers a data line split across chunks', () {
      final parser = ClaudeSseParser();
      final frame = _frame({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': 'split'},
      });
      final cut = frame.length ~/ 2;

      expect(parser.addChunk(frame.substring(0, cut)), isEmpty);
      final events = parser.addChunk(frame.substring(cut));
      expect(events.single, isA<ClaudeTextDeltaEvent>());
      expect((events.single as ClaudeTextDeltaEvent).text, 'split');
    });

    test('never splits a multi-byte character across chunks', () {
      final parser = ClaudeSseParser();
      final frame = _frame({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': 'héllo — 🌍'},
      });
      final bytes = utf8.encode(frame);

      final events = <ClaudeStreamEvent>[];
      for (var i = 0; i < bytes.length; i++) {
        events.addAll(parser.addBytes([bytes[i]]));
      }
      expect((events.single as ClaudeTextDeltaEvent).text, 'héllo — 🌍');
    });

    test('ignores ping and [DONE], surfaces error frames', () {
      final parser = ClaudeSseParser();
      expect(parser.addChunk(_frame({'type': 'ping'})).single, isA<ClaudePingEvent>());
      expect(parser.addChunk('data: [DONE]\n\n'), isEmpty);

      final error = parser
          .addChunk(
            _frame({
              'type': 'error',
              'error': {'type': 'overloaded_error', 'message': 'Overloaded'},
            }),
          )
          .single;
      expect((error as ClaudeStreamErrorEvent).type, 'overloaded_error');
    });

    test('flush drains a trailing line with no newline', () {
      final parser = ClaudeSseParser();
      expect(
        parser.addChunk(
          'data: ${jsonEncode({
            'type': 'content_block_delta',
            'index': 0,
            'delta': {'type': 'text_delta', 'text': 'tail'},
          })}',
        ),
        isEmpty,
      );
      expect(parser.flush().single, isA<ClaudeTextDeltaEvent>());
    });
  });

  group('ClaudeStreamAccumulator', () {
    test('rebuilds text, thinking and usage', () {
      final accumulator = ClaudeStreamAccumulator();
      accumulator
        ..add(
          const ClaudeMessageStartEvent(
            id: 'msg_1',
            model: 'claude-opus-5',
            usage: ClaudeUsage(inputTokens: 10),
          ),
        )
        ..add(const ClaudeBlockStartEvent(index: 0, type: 'thinking'))
        ..add(const ClaudeThinkingDeltaEvent(0, 'Considering options'))
        ..add(const ClaudeBlockStartEvent(index: 1, type: 'text'))
        ..add(const ClaudeTextDeltaEvent(1, 'Answer'))
        ..add(
          const ClaudeMessageDeltaEvent(
            stopReason: ClaudeStopReason.endTurn,
            stopReasonWire: 'end_turn',
            outputTokens: 5,
          ),
        );

      final response = accumulator.build();
      expect(response.text, 'Answer');
      expect(response.thinking, 'Considering options');
      expect(response.stopReason, ClaudeStopReason.endTurn);
      expect(response.usage.outputTokens, 5);
      expect(response.usage.inputTokens, 10);
      // Thinking block first, text second — order must survive.
      expect(response.content.first, isA<ClaudeThinkingBlock>());
    });

    test('reassembles tool_use input from partial JSON', () {
      final accumulator = ClaudeStreamAccumulator();
      accumulator
        ..add(
          const ClaudeBlockStartEvent(
            index: 0,
            type: 'tool_use',
            toolUseId: 'toolu_1',
            toolName: 'get_weather',
          ),
        )
        ..add(const ClaudeInputJsonDeltaEvent(0, '{"city":'))
        ..add(const ClaudeInputJsonDeltaEvent(0, '"Paris"}'))
        ..add(
          const ClaudeMessageDeltaEvent(stopReason: ClaudeStopReason.toolUse),
        );

      final response = accumulator.build();
      expect(response.wantsTools, isTrue);
      expect(response.toolUses.single.name, 'get_weather');
      expect(response.toolUses.single.input['city'], 'Paris');
    });

    test('half a JSON object decodes to empty input, not a crash', () {
      final accumulator = ClaudeStreamAccumulator();
      accumulator
        ..add(
          const ClaudeBlockStartEvent(
            index: 0,
            type: 'tool_use',
            toolUseId: 'toolu_1',
            toolName: 'get_weather',
          ),
        )
        ..add(const ClaudeInputJsonDeltaEvent(0, '{"city":'));
      expect(accumulator.build().toolUses.single.input, isEmpty);
    });
  });

  group('ClaudeResponse', () {
    test('refusal is detected before content is read', () {
      final response = ClaudeResponse.fromJson({
        'id': 'msg_1',
        'model': 'claude-opus-5',
        'stop_reason': 'refusal',
        'stop_details': {'type': 'refusal', 'category': 'cyber'},
        'content': <dynamic>[],
      });
      expect(response.isRefusal, isTrue);
      expect(response.refusalCategory, 'cyber');
      expect(response.content, isEmpty);
      expect(response.text, isEmpty);
    });

    test('pause_turn is not an error', () {
      final response = ClaudeResponse.fromJson({'stop_reason': 'pause_turn'});
      expect(response.isPaused, isTrue);
      expect(response.isRefusal, isFalse);
    });

    test('usage totals include the cache fields', () {
      final usage = ClaudeUsage.fromJson({
        'input_tokens': 100,
        'output_tokens': 20,
        'cache_creation_input_tokens': 300,
        'cache_read_input_tokens': 600,
      });
      expect(usage.totalInputTokens, 1000);
    });

    test('unknown block types round-trip unchanged', () {
      final block = ClaudeBlock.fromJson({
        'type': 'server_tool_use',
        'id': 'srvtoolu_1',
      });
      expect(block, isA<ClaudeUnknownBlock>());
      expect(block.toJson()['id'], 'srvtoolu_1');
    });
  });

  group('ClaudeRepo.buildBody', () {
    final messages = [ClaudeMessage.user('hi')];

    test('emits effort under output_config and no sampling params', () {
      final body = ClaudeRepo.buildBody(
        messages: messages,
        stream: false,
        model: 'claude-opus-5',
        effort: ClaudeEffort.xhigh,
      );
      expect(body['output_config'], {'effort': 'xhigh'});
      expect(body.containsKey('effort'), isFalse);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
      expect(body.containsKey('top_k'), isFalse);
      expect(body.containsKey('stream'), isFalse);
      expect(body['max_tokens'], ClaudeApiConstant.nonStreamingMaxTokens);
    });

    test('omits thinking by default and never sends budget_tokens', () {
      final body = ClaudeRepo.buildBody(messages: messages, stream: true);
      expect(body.containsKey('thinking'), isFalse);
      expect(body['stream'], isTrue);
      expect(body['max_tokens'], ClaudeApiConstant.streamingMaxTokens);
      expect(body['model'], 'claude-opus-5');
    });

    test('summarized display opts into readable reasoning', () {
      final body = ClaudeRepo.buildBody(
        messages: messages,
        stream: true,
        thinkingDisplay: ClaudeThinkingDisplay.summarized,
      );
      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
    });

    test('disabled thinking above high effort is rejected locally', () {
      expect(
        () => ClaudeRepo.buildBody(
          messages: messages,
          stream: false,
          disableThinking: true,
          effort: ClaudeEffort.max,
        ),
        throwsArgumentError,
      );
      final body = ClaudeRepo.buildBody(
        messages: messages,
        stream: false,
        disableThinking: true,
        effort: ClaudeEffort.high,
      );
      expect(body['thinking'], {'type': 'disabled'});
    });

    test('tools serialise to input_schema', () {
      final body = ClaudeRepo.buildBody(
        messages: messages,
        stream: false,
        tools: [
          ClaudeTool.object(
            name: 'get_weather',
            description: 'Call when the user asks about current weather.',
            properties: {
              'city': {'type': 'string'},
            },
            required: ['city'],
          ),
        ],
      );
      final tool = (body['tools'] as List).single as Map<String, dynamic>;
      expect(tool['name'], 'get_weather');
      expect(tool['input_schema']['required'], ['city']);
    });
  });

  group('ClaudeMessage', () {
    test('tool results all land in one user message', () {
      final message = ClaudeMessage.toolResults([
        const ClaudeToolResultBlock(toolUseId: 'a', content: 'ok'),
        const ClaudeToolResultBlock(
          toolUseId: 'b',
          content: 'boom',
          isError: true,
        ),
      ]);
      expect(message.role, ClaudeRole.user);
      expect(message.blocks.length, 2);
      final json = message.toJson();
      expect((json['content'] as List).length, 2);
      expect(((json['content'] as List)[1] as Map)['is_error'], isTrue);
      expect(((json['content'] as List)[0] as Map).containsKey('is_error'), isFalse);
    });

    test('thinking blocks keep their signature', () {
      final json = const ClaudeThinkingBlock('why', signature: 'sig').toJson();
      expect(json['signature'], 'sig');
      final parsed = ClaudeBlock.fromJson(json) as ClaudeThinkingBlock;
      expect(parsed.signature, 'sig');
    });
  });
}
