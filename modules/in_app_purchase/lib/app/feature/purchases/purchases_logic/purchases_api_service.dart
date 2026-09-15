import 'package:flutter_starter/app/feature/purchases/purchases_logic/purchases_api_const.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

/// Abstract class for Purchases API Service
abstract class PurchasesApiService {
  Future<dynamic> verifyPurchase(String url, {Map<String, dynamic>? params});
  Future<dynamic> syncPurchases(String url, {Map<String, dynamic>? params});
  Future<dynamic> fetchEntitlement(String url, {Map<String, dynamic>? params});
}

/// Implementation of PurchasesApiService
class PurchasesImpl extends PurchasesApiService {
  @override
  Future<dynamic> verifyPurchase(
    String url, {
    Map<String, dynamic>? params,
  }) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future<dynamic> syncPurchases(
    String url, {
    Map<String, dynamic>? params,
  }) async {
    final dynamic response = await ApiService().post(url, params);
    return response;
  }

  @override
  Future<dynamic> fetchEntitlement(
    String url, {
    Map<String, dynamic>? params,
  }) async {
    final dynamic response = await ApiService().get(url, params: params);
    return response;
  }
}

/// Repository for Purchases
class PurchasesRepo {
  final PurchasesApiService purchasesApiService = PurchasesImpl();

  /// Sends one store receipt for server-side validation. The response body is
  /// the entitlement the server decided on — the app does not decide.
  Future<dynamic>? verifyPurchase(Map<String, dynamic> params) async {
    dynamic responseData = await purchasesApiService.verifyPurchase(
      PurchasesApiConst.verifyPurchaseUri,
      params: params,
    );
    if (responseData == null) return null;
    return responseData = responseData.data;
  }

  /// Batch variant used by "restore purchases".
  Future<dynamic>? syncPurchases(Map<String, dynamic> params) async {
    dynamic responseData = await purchasesApiService.syncPurchases(
      PurchasesApiConst.syncPurchasesUri,
      params: params,
    );
    if (responseData == null) return null;
    return responseData = responseData.data;
  }

  /// Reads the entitlement the server currently holds, including changes it
  /// learned from a store webhook while the app was closed.
  Future<dynamic>? fetchEntitlement() async {
    dynamic responseData = await purchasesApiService.fetchEntitlement(
      PurchasesApiConst.entitlementUri,
    );
    if (responseData == null) return null;
    return responseData = responseData.data;
  }
}
