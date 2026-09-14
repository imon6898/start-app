// Pattern reference: one API call per wizard step, Repo/Impl split.
import 'dart:io';
import 'package:flutter_starter/app/feature/auth/auth_logic/onboarding_api_const.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

/// Abstract class for Rider Registration API
abstract class RiderApiService {
  Future postStep1(Map<String, dynamic> fields, Map<String, File> files);
  Future patchStep2(
    String riderId,
    Map<String, dynamic> fields,
    Map<String, File> files,
  );
  Future patchStep3(
    String riderId,
    Map<String, dynamic> fields,
    Map<String, File> files,
  );
  Future patchStep4(String riderId, Map<String, dynamic> body);
}

/// Implementation
class RiderApiImpl extends RiderApiService {
  @override
  Future postStep1(Map<String, dynamic> fields, Map<String, File> files) async {
    return await ApiService(
      logisticsBaseUrl: true,
    ).multipleFileUpload(OnboardingEndpoints.riderStep1, fields, files: files);
  }

  @override
  Future patchStep2(
    String riderId,
    Map<String, dynamic> fields,
    Map<String, File> files,
  ) async {
    return await ApiService(logisticsBaseUrl: true).multipleFileUploadPatch(
      OnboardingEndpoints.riderStep2(riderId),
      fields,
      files: files,
    );
  }

  @override
  Future patchStep3(
    String riderId,
    Map<String, dynamic> fields,
    Map<String, File> files,
  ) async {
    return await ApiService(logisticsBaseUrl: true).multipleFileUploadPatch(
      OnboardingEndpoints.riderStep3(riderId),
      fields,
      files: files,
    );
  }

  @override
  Future patchStep4(String riderId, Map<String, dynamic> body) async {
    return await ApiService(
      logisticsBaseUrl: true,
    ).patch(OnboardingEndpoints.riderStep4(riderId), body);
  }
}

/// Repository
class RiderRegistrationRepo {
  final RiderApiService _api = RiderApiImpl();

  /// Step 1: Create rider with personal info + optional profile photo
  Future<Map<String, dynamic>?> submitStep1(
    Map<String, dynamic> fields, {
    File? profilePhoto,
  }) async {
    final files = <String, File>{};
    if (profilePhoto != null) files['profilePhoto'] = profilePhoto;
    final response = await _api.postStep1(fields, files);
    if (response?.data != null) {
      final data = response.data;
      if (data is Map && data['status'] == true && data['data'] != null) {
        return Map<String, dynamic>.from(data['data']);
      }
      // Some APIs return the rider directly
      if (data is Map && data['id'] != null) {
        return Map<String, dynamic>.from(data);
      }
    }
    return null;
  }

  /// Step 2: Upload documents (TRN, NIS, Proof of Address)
  Future<Map<String, dynamic>?> submitStep2(
    String riderId,
    Map<String, dynamic> fields, {
    File? trnCard,
    File? nisCard,
    File? proofOfAddress,
  }) async {
    final files = <String, File>{};
    if (trnCard != null) files['trnCard'] = trnCard;
    if (nisCard != null) files['nisCard'] = nisCard;
    if (proofOfAddress != null) files['proofOfAddress'] = proofOfAddress;
    final response = await _api.patchStep2(riderId, fields, files);
    return _parseResponse(response);
  }

  /// Step 3: Vehicle & license details
  Future<Map<String, dynamic>?> submitStep3(
    String riderId,
    Map<String, dynamic> fields, {
    File? dlFront,
  }) async {
    final files = <String, File>{};
    if (dlFront != null) files['dlFront'] = dlFront;
    final response = await _api.patchStep3(riderId, fields, files);
    return _parseResponse(response);
  }

  /// Step 4: Bank & work preferences (JSON)
  Future<Map<String, dynamic>?> submitStep4(
    String riderId,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.patchStep4(riderId, body);
    return _parseResponse(response);
  }

  Map<String, dynamic>? _parseResponse(dynamic response) {
    if (response?.data != null) {
      final data = response.data;
      if (data is Map && data['status'] == true && data['data'] != null) {
        return Map<String, dynamic>.from(data['data']);
      }
      if (data is Map && data['id'] != null) {
        return Map<String, dynamic>.from(data);
      }
    }
    return null;
  }
}
