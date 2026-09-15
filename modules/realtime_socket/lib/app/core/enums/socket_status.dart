// Module-local enum for realtime_socket. Kept out of core enums.dart so the
// installer never has to overwrite a file the template already ships.

/// Connection lifecycle of the realtime socket.
enum SocketStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
  error,
}

extension SocketStatusX on SocketStatus {
  /// Short label for badges and logs. Call `.tr` at the UI layer.
  String get label {
    switch (this) {
      case SocketStatus.idle:
        return 'Offline';
      case SocketStatus.connecting:
        return 'Connecting';
      case SocketStatus.connected:
        return 'Connected';
      case SocketStatus.reconnecting:
        return 'Reconnecting';
      case SocketStatus.disconnected:
        return 'Disconnected';
      case SocketStatus.error:
        return 'Error';
    }
  }

  bool get isConnected => this == SocketStatus.connected;

  /// True while a connect or reconnect attempt is in flight.
  bool get isConnecting =>
      this == SocketStatus.connecting || this == SocketStatus.reconnecting;

  /// True when no socket is live and none is being opened.
  bool get isOffline =>
      this == SocketStatus.idle ||
      this == SocketStatus.disconnected ||
      this == SocketStatus.error;
}
