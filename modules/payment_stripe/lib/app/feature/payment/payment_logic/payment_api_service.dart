import 'package:flutter_starter/app/feature/payment/payment_logic/payment_api_const.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

/// Abstract class for Payment API Service
abstract class PaymentApiService {
  Future<dynamic> createPaymentIntent(
    String url, {
    Map<String, dynamic>? params,
  });
  Future<dynamic> fetchPaymentStatus(
    String url, {
    Map<String, dynamic>? params,
  });
}

/// Implementation of PaymentApiService
class PaymentImpl extends PaymentApiService {
  @override
  Future<dynamic> createPaymentIntent(
    String url, {
    Map<String, dynamic>? params,
  }) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future<dynamic> fetchPaymentStatus(
    String url, {
    Map<String, dynamic>? params,
  }) async {
    final dynamic response = await ApiService().get(url, params: params);
    return response;
  }
}

/// Repository for Payment
class PaymentRepo {
  final PaymentApiService paymentApiService = PaymentImpl();

  /// Your backend charges the Stripe secret key and returns a client_secret.
  /// Anything the app sends here is a hint — the server sets the real amount.
  Future<dynamic>? createPaymentIntent(Map<String, dynamic> params) async {
    dynamic responseData = await paymentApiService.createPaymentIntent(
      PaymentApiConst.createPaymentIntentUri,
      params: params,
    );
    return responseData = responseData.data;
  }

  /// Reads back the status your backend recorded from the Stripe webhook.
  Future<dynamic>? fetchPaymentStatus(Map<String, dynamic> params) async {
    dynamic responseData = await paymentApiService.fetchPaymentStatus(
      PaymentApiConst.paymentStatusUri,
      params: params,
    );
    return responseData = responseData.data;
  }
}
