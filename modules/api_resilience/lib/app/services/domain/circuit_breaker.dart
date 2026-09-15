/// closed = normal, open = failing fast, halfOpen = one probe allowed through.
enum CircuitState { closed, open, halfOpen }

/// Thrown (as DioException.error) when a request is refused by an open circuit.
class CircuitOpenException implements Exception {
  const CircuitOpenException(this.host, this.retryAfter);

  final String host;
  final Duration retryAfter;

  @override
  String toString() =>
      'Circuit open for $host, retry in ${retryAfter.inSeconds}s';
}

/// Per-host consecutive-failure counter that stops hammering a dead backend.
class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 5,
    this.openDuration = const Duration(seconds: 30),
    DateTime Function()? clock,
    this.onStateChanged,
  }) : _now = clock ?? DateTime.now;

  /// Mutable so a shared breaker can adopt the interceptor's config.
  int failureThreshold;
  Duration openDuration;
  final DateTime Function() _now;

  /// Called on every transition so a service can mirror it into Rx state.
  final void Function(String host, CircuitState state, Duration cooldown)?
  onStateChanged;

  final Map<String, _HostCircuit> _hosts = {};

  CircuitState stateOf(String host) =>
      _hosts[host]?.state ?? CircuitState.closed;

  int failureCountOf(String host) => _hosts[host]?.failures ?? 0;

  /// Time left before the next probe is allowed.
  Duration cooldownOf(String host) {
    final circuit = _hosts[host];
    if (circuit == null || circuit.openedUntil == null) return Duration.zero;
    final left = circuit.openedUntil!.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// True if the request may go out. Reserves the half-open probe slot.
  bool allowRequest(String host) {
    final circuit = _hosts.putIfAbsent(host, _HostCircuit.new);
    switch (circuit.state) {
      case CircuitState.closed:
        return true;
      case CircuitState.open:
        if (cooldownOf(host) > Duration.zero) return false;
        circuit.state = CircuitState.halfOpen;
        circuit.probeInFlight = true;
        _emit(host, circuit);
        return true;
      case CircuitState.halfOpen:
        if (circuit.probeInFlight) return false;
        circuit.probeInFlight = true;
        return true;
    }
  }

  void onSuccess(String host) {
    final circuit = _hosts[host];
    if (circuit == null) return;
    final wasOpen = circuit.state != CircuitState.closed;
    circuit
      ..failures = 0
      ..state = CircuitState.closed
      ..probeInFlight = false
      ..openedUntil = null;
    if (wasOpen) _emit(host, circuit);
  }

  void onFailure(String host) {
    final circuit = _hosts.putIfAbsent(host, _HostCircuit.new);
    circuit.failures++;
    // A failed probe reopens the circuit for another full cooldown.
    if (circuit.state == CircuitState.halfOpen ||
        circuit.failures >= failureThreshold) {
      circuit
        ..state = CircuitState.open
        ..probeInFlight = false
        ..openedUntil = _now().add(openDuration);
      _emit(host, circuit);
    }
  }

  void reset([String? host]) {
    if (host == null) {
      _hosts.clear();
    } else {
      _hosts.remove(host);
    }
  }

  void _emit(String host, _HostCircuit circuit) =>
      onStateChanged?.call(host, circuit.state, cooldownOf(host));
}

class _HostCircuit {
  CircuitState state = CircuitState.closed;
  int failures = 0;
  bool probeInFlight = false;
  DateTime? openedUntil;
}
