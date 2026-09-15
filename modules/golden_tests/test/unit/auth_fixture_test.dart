// Proves the test/helpers kit works: fixtures parse into the real models, and a
// mocked *ApiService answers without a socket.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_starter/app/core/models/base_response.dart';
import 'package:flutter_starter/app/feature/auth/auth_models/auth_response.dart';
import 'package:flutter_starter/app/services/domain/api_const.dart';

import '../helpers/fixtures.dart';
import '../helpers/mock_api_service.dart';

void main() {
  setUpAll(registerApiFallbacks);

  group('fixtures parse into the real models', () {
    test('login_success yields a verified user and both tokens', () {
      final parsed = BaseResponse<LoginData>.fromJson(
        fixtureJson('login_success.json'),
        (data) => LoginData.fromJson(data),
      );

      expect(parsed.statusCode, 201);
      expect(parsed.data!.accessToken, 'fixture-access-token');
      expect(parsed.data!.refreshToken, 'fixture-refresh-token');
      expect(parsed.data!.user!.email, 'ada@example.com');
      expect(parsed.data!.user!.isVerified, isTrue);
      expect(parsed.data!.roles, ['user']);
    });

    test('login_unverified drives the OTP branch', () {
      final parsed = BaseResponse<LoginData>.fromJson(
        fixtureJson('login_unverified.json'),
        (data) => LoginData.fromJson(data),
      );

      expect(parsed.data!.user!.isVerified, isFalse);
      expect(parsed.data!.roles, isEmpty);
    });

    test('login_error has no data payload', () {
      final parsed = BaseResponse<LoginData>.fromJson(
        fixtureJson('login_error.json'),
        (data) => LoginData.fromJson(data),
      );

      expect(parsed.status, isFalse);
      expect(parsed.statusCode, 401);
      expect(parsed.data, isNull);
    });

    test('a missing fixture fails loudly instead of returning empty', () {
      expect(() => fixtureJson('nope.json'), throwsStateError);
    });
  });

  group('MockAuthApiService', () {
    late MockAuthApiService api;

    setUp(() => api = MockAuthApiService());

    test('returns the fixture as a Dio Response, no network', () async {
      when(() => api.postSignin(any(), any())).thenAnswer(
        (_) async => apiResponse(fixtureJson('login_success.json')),
      );

      final response = await api.postSignin(ApiConstant.loginUri, {
        'identifier': 'ada@example.com',
        'password': 'secret',
      });

      final parsed = BaseResponse<LoginData>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => LoginData.fromJson(data),
      );

      expect(parsed.data!.accessToken, 'fixture-access-token');
      verify(() => api.postSignin(ApiConstant.loginUri, any())).called(1);
    });

    test('can throw a DioException for the failure branch', () async {
      when(() => api.postSignin(any(), any())).thenThrow(
        apiError(statusCode: 401, body: fixtureJson('login_error.json')),
      );

      expect(
        () => api.postSignin(ApiConstant.loginUri, const {}),
        throwsA(isA<Exception>()),
      );
    });
  });
}
