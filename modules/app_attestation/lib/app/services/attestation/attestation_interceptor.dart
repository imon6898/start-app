// Attaches an attestation token to OPTED-IN requests only. Never to every call:
// Play Integrity and App Attest are quota-limited and take hundreds of ms, so
// blanket use burns quota and adds latency to every screen.

import 'package:dio/dio.dart';

import '../attestation_service.dart';
import '../domain/dev_tools.dart';
import 'attestation_token.dart';

class AttestationInterceptor extends Interceptor {
  /// Path prefixes that get a token. Keep this list short and sensitive-only.
  final List<String> paths;

  /// When false, a missing token rejects the request locally instead of sending it.
  /// Leave it true — the SERVER decides what an unattested request may do.
  final bool failOpen;

  AttestationInterceptor({this.paths = const [], this.failOpen = true});

  /// Per-request opt-in: `Options(extra: {AttestationInterceptor.extraKey: true})`.
  static const String extraKey = 'requiresAttestation';

  /// Per-request opt-out, for retries that already carry a token.
  static const String skipKey = 'skipAttestation';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_needsAttestation(options)) return handler.next(options);

    final service = AttestationService.to;
    final hash = AttestationService.hashFor(
      options.method,
      options.path,
      options.data,
    );
    final token = await service.tokenFor(hash);

    if (token != null) {
      options.headers.addAll(token.toHeaders());
      return handler.next(options);
    }

    final reason = service.lastSkipReason?.name ?? 'unavailable';
    devPrint('no token for ${options.path} ($reason)', tag: 'Attestation');

    if (failOpen) {
      // Tell the server it is unattested rather than pretending nothing happened.
      options.headers[AttestationToken.headerSkipped] = reason;
      return handler.next(options);
    }

    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: 'attestation_unavailable: $reason',
      ),
    );
  }

  bool _needsAttestation(RequestOptions options) {
    if (options.extra[skipKey] == true) return false;
    // Dio.fetch re-runs onRequest, so the 401-refresh retry lands here again
    // with the headers already set. Same request, same hash — leave them.
    if (options.headers.containsKey(AttestationToken.headerToken)) return false;
    if (options.extra[extraKey] == true) return true;
    return paths.any((p) => options.path.startsWith(p));
  }
}
