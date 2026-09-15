import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_api_const.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_api_service.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_logic/claude_sse_parser.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_message.dart';
import 'package:flutter_starter/app/feature/ai_assistant/ai_assistant_models/claude_response.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';
import 'package:get/get.dart';

class ChatController extends GetxController {
  ChatController({ClaudeRepo? repo}) : _repo = repo ?? ClaudeRepo();

  final ClaudeRepo _repo;

  /// Full conversation, resent on every request — the API is stateless.
  final RxList<ClaudeMessage> messages = <ClaudeMessage>[].obs;

  final RxBool isStreaming = false.obs;
  final RxString streamingText = ''.obs;
  final RxString streamingThinking = ''.obs;
  final Rx<String?> errorMessage = Rx<String?>(null);

  /// Message indices whose thinking summary is expanded.
  final RxSet<int> expandedThinking = <int>{}.obs;

  final TextEditingController inputController = TextEditingController();
  final FocusNode inputFocus = FocusNode();
  final ScrollController scrollController = ScrollController();

  String systemPrompt =
      'You are a helpful assistant inside a mobile app. Keep answers focused '
      'and concise.';

  CancelToken? _cancelToken;
  StreamSubscription<ClaudeStreamEvent>? _subscription;

  bool get canSend => !isStreaming.value;

  @override
  void onClose() {
    _cancelToken?.cancel('controller closed');
    _subscription?.cancel();
    inputController.dispose();
    inputFocus.dispose();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> send() async {
    final text = inputController.text.trim();
    if (text.isEmpty || isStreaming.value) return;
    inputController.clear();
    messages.add(ClaudeMessage.user(text));
    await _run();
  }

  /// Drops a failed/partial assistant turn and re-sends the last user turn.
  Future<void> retry() async {
    if (isStreaming.value) return;
    errorMessage.value = null;
    while (messages.isNotEmpty && messages.last.role == ClaudeRole.assistant) {
      messages.removeLast();
    }
    if (messages.isEmpty || messages.last.role != ClaudeRole.user) return;
    await _run();
  }

  void cancel() => _cancelToken?.cancel('cancelled by user');

  void clear() {
    if (isStreaming.value) cancel();
    messages.clear();
    expandedThinking.clear();
    errorMessage.value = null;
    streamingText.value = '';
    streamingThinking.value = '';
  }

  void toggleThinking(int index) {
    if (expandedThinking.contains(index)) {
      expandedThinking.remove(index);
    } else {
      expandedThinking.add(index);
    }
  }

  Future<void> copy(BuildContext context, String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showCustomSnackBar(
      context: context,
      type: SnackBarType.Success,
      title: 'Copied'.tr,
      description: 'The reply is on your clipboard'.tr,
    );
  }

  Future<void> _run() async {
    errorMessage.value = null;
    streamingText.value = '';
    streamingThinking.value = '';
    isStreaming.value = true;
    _scrollToEnd();

    final accumulator = ClaudeStreamAccumulator();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final finished = Completer<void>();

    _subscription = _repo
        .stream(
          messages: messages.toList(),
          system: systemPrompt,
          // Default display is "omitted", which looks like a dead pause.
          thinkingDisplay: ClaudeThinkingDisplay.summarized,
          effort: ClaudeEffort.high,
          cancelToken: cancelToken,
        )
        .listen(
          (event) {
            accumulator.add(event);
            if (event is ClaudeTextDeltaEvent) {
              streamingText.value = accumulator.text;
            } else if (event is ClaudeThinkingDeltaEvent) {
              streamingThinking.value = accumulator.thinking;
            } else if (event is ClaudeStreamErrorEvent) {
              errorMessage.value = event.message;
            }
          },
          onError: (Object error) {
            if (!finished.isCompleted) finished.completeError(error);
          },
          onDone: () {
            if (!finished.isCompleted) finished.complete();
          },
          cancelOnError: true,
        );

    try {
      await finished.future;
      final response = accumulator.build();
      // stop_reason first: a refusal can carry empty or partial content.
      if (response.isRefusal) {
        errorMessage.value = 'Claude declined this request'.tr;
      } else if (response.wasTruncated) {
        errorMessage.value = 'Reply was cut off by the token limit'.tr;
      }
      if (response.content.isNotEmpty) messages.add(response.asMessage);
    } catch (e) {
      // A cancel is a user action, not an error — keep whatever streamed in.
      if (cancelToken.isCancelled) {
        if (!accumulator.isEmpty) {
          final partial = accumulator.build();
          if (partial.content.isNotEmpty) messages.add(partial.asMessage);
        }
      } else {
        devPrint('ChatController stream failed: $e');
        errorMessage.value = e is ClaudeApiException
            ? e.message
            : 'Something went wrong. Please try again.'.tr;
      }
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _cancelToken = null;
      streamingText.value = '';
      streamingThinking.value = '';
      isStreaming.value = false;
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}
