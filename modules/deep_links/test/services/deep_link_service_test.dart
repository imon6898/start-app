// Matcher + guard only — no plugin channel is touched, so this runs on the VM.

import 'package:flutter_starter/app/services/deep_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = DeepLinkService(
    routes: const {
      '/': '/home',
      '/product/:id': '/product',
      '/product/new': '/newProduct',
      '/order/:id/track': '/track',
      '/docs/*': '/docs',
    },
    schemes: const {'flutterstarter'},
    hosts: const {'example.com'},
    authOnly: const {'/home'},
  );

  test('path params and query params reach the arguments map', () {
    final match = service.matchUri(
      Uri.parse('https://example.com/product/42?ref=push'),
    );
    expect(match!.route, '/product');
    expect(match.pathParams['id'], '42');
    expect(match.arguments['id'], '42');
    expect(match.arguments['ref'], 'push');
    expect(
      match.arguments['deepLinkUri'],
      'https://example.com/product/42?ref=push',
    );
  });

  test('a literal segment outranks a :param', () {
    expect(
      service.matchUri(Uri.parse('https://example.com/product/new'))?.route,
      '/newProduct',
    );
  });

  test('root and wildcard patterns', () {
    expect(service.matchUri(Uri.parse('https://example.com/'))?.route, '/home');
    expect(
      service.matchUri(Uri.parse('https://example.com/docs/a/b'))?.pathParams,
      {'rest': 'a/b'},
    );
    expect(
      service.matchUri(Uri.parse('https://example.com/order/9/track'))?.route,
      '/track',
    );
  });

  test('a custom-scheme host is retried as a path segment', () {
    final bare = service.matchUri(Uri.parse('flutterstarter://product/42'));
    expect(bare?.route, '/product');
    expect(bare?.pathParams['id'], '42');
    expect(
      service
          .matchUri(Uri.parse('flutterstarter://open.app/product/42'))
          ?.route,
      '/product',
    );
  });

  test('foreign hosts and schemes are rejected', () {
    expect(service.accepts(Uri.parse('https://evil.com/product/1')), isFalse);
    expect(service.accepts(Uri.parse('other://product/1')), isFalse);
    expect(service.accepts(Uri.parse('flutterstarter://product/1')), isTrue);
  });

  test('unmatched paths return null so the caller can fall through', () {
    expect(service.matchUri(Uri.parse('https://example.com/nope')), isNull);
  });

  test('the guard hook overrides the auth-only check', () {
    final match = service.matchUri(Uri.parse('https://example.com/'))!;
    expect(service.allows(match), isFalse);
    service.guard = (_) => true;
    expect(service.allows(match), isTrue);
  });
}
