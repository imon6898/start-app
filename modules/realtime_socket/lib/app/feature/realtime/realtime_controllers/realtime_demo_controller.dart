import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_starter/app/core/enums/socket_status.dart';
import 'package:flutter_starter/app/services/socket_service.dart';
import 'package:flutter_starter/app/utils/main_utils.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';

/// Reference wiring for SocketService: subscribe in onInit, cancel in onClose.
class RealtimeDemoController extends GetxController {
  /// Event names this demo talks over — point them at your own server.
  static const String incomingEvent = 'message';
  static const String outgoingEvent = 'message';
  static const String typingEvent = 'typing';
  static const String pingEvent = 'ping';

  /// Looked up lazily so bootstrap registration order cannot bite.
  SocketService get socket => SocketService.to;

  final TextEditingController messageController = TextEditingController();

  final RxList<String> feed = <String>[].obs;
  final RxBool isLoadingPing = false.obs;

  final List<SocketSubscription> _subscriptions = <SocketSubscription>[];

  Rx<SocketStatus> get status => socket.status;

  @override
  void onInit() {
    super.onInit();
    _subscribe();
    socket.connect();
  }

  @override
  void onClose() {
    for (final SocketSubscription subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    messageController.dispose();
    super.onClose();
  }

  /// Registered once; the service re-attaches them after every reconnect.
  void _subscribe() {
    _subscriptions.add(
      socket.on<Map<String, dynamic>>(incomingEvent, (
        Map<String, dynamic> data,
      ) {
        _append('${data['text'] ?? data}');
      }),
    );
    _subscriptions.add(
      socket.on<dynamic>(
        typingEvent,
        (dynamic data) => _append('typing: $data'),
      ),
    );
  }

  /// Fire-and-forget emit — socket.io buffers it if the link is down.
  void sendMessage(BuildContext context) {
    final String text = messageController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();

    if (!socket.isConnected) {
      showCustomSnackBar(
        context: context,
        type: SnackBarType.Warning,
        title: 'Not connected'.tr,
        description: 'The socket is not connected yet'.tr,
      );
      return;
    }

    socket.emit(outgoingEvent, <String, dynamic>{
      'text': text,
      'sentAt': DateTime.now().toIso8601String(),
    });
    _append('me: $text');
    messageController.clear();
  }

  /// Emit that waits for the server acknowledgement.
  Future<void> sendPing(BuildContext context) async {
    if (isLoadingPing.value) return;
    isLoadingPing.value = true;
    try {
      final dynamic ack = await socket.emitWithAck(pingEvent, <String, dynamic>{
        'at': DateTime.now().toIso8601String(),
      });
      _append('ack: $ack');
    } catch (e) {
      _append('ack failed: $e');
      if (!context.mounted) return;
      showCustomSnackBar(
        context: context,
        type: SnackBarType.Failure,
        title: 'Ping failed'.tr,
        description: 'The server did not acknowledge in time'.tr,
      );
    } finally {
      isLoadingPing.value = false;
    }
  }

  /// Drops the current socket and opens a fresh one with the cached token.
  void reconnect() {
    socket.disconnect();
    socket.connect();
  }

  void clearFeed() => feed.clear();

  /// Newest first, capped so the demo list never grows without bound.
  void _append(String line) {
    feed.insert(0, '${MainUtils.dateToTimeOnly(DateTime.now())}  $line');
    if (feed.length > 100) feed.removeLast();
  }
}
