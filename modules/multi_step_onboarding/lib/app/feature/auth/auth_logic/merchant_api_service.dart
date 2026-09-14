// Pattern reference: multipart document upload, Repo/Impl split.
import 'dart:io';
import 'package:flutter_starter/app/feature/auth/auth_logic/onboarding_api_const.dart';
import 'package:flutter_starter/app/services/domain/api_service.dart';

/// Abstract class for Merchant API Service
abstract class MerchantApiService {
  Future postRegister(Map<String, dynamic> params);
  Future postUploadAllDocuments(
    String merchantId,
    Map<String, dynamic> fields,
    Map<String, File> files,
  );
  Future postUploadBusinessReg(
    String merchantId,
    File file, {
    String? registrationNumber,
  });
  Future postUploadTrn(
    String merchantId,
    File file, {
    required String trnNumber,
  });
  Future postUploadIdProof(
    String merchantId,
    File front, {
    File? back,
    required String idType,
    String? idNumber,
    String? expiryDate,
  });
  Future postUploadAddressProof(String merchantId, File file);
  Future postUploadBankStatement(String merchantId, File file);
  // JSON document URL submission
  Future postDocBusinessReg(String merchantId, Map<String, dynamic> params);
  Future postDocTrn(String merchantId, Map<String, dynamic> params);
  Future postDocIdProof(String merchantId, Map<String, dynamic> params);
  Future postDocAddressProof(String merchantId, Map<String, dynamic> params);
  Future postDocBankStatement(String merchantId, Map<String, dynamic> params);
  Future getDocumentStatus(String merchantId);
}

/// Implementation of MerchantApiService
class MerchantImpl extends MerchantApiService {
  @override
  Future postRegister(Map<String, dynamic> params) async {
    return await ApiService(
      logisticsBaseUrl: true,
    ).post(OnboardingEndpoints.merchantRegisterUri, params);
  }

  @override
  Future postUploadAllDocuments(
    String merchantId,
    Map<String, dynamic> fields,
    Map<String, File> files,
  ) async {
    return await ApiService(logisticsBaseUrl: true).multipleFileUploadPatch(
      OnboardingEndpoints.merchantUploadAllUri(merchantId),
      fields,
      files: files,
    );
  }

  @override
  Future postUploadBusinessReg(
    String merchantId,
    File file, {
    String? registrationNumber,
  }) async {
    final fields = <String, dynamic>{};
    if (registrationNumber != null && registrationNumber.isNotEmpty) {
      fields['registrationNumber'] = registrationNumber;
    }
    return await ApiService(logisticsBaseUrl: true).multipleFileUpload(
      OnboardingEndpoints.merchantUploadBusinessReg(merchantId),
      fields,
      files: {'file': file},
    );
  }

  @override
  Future postUploadTrn(
    String merchantId,
    File file, {
    required String trnNumber,
  }) async {
    return await ApiService(logisticsBaseUrl: true).multipleFileUpload(
      OnboardingEndpoints.merchantUploadTrn(merchantId),
      {'trnNumber': trnNumber},
      files: {'file': file},
    );
  }

  @override
  Future postUploadIdProof(
    String merchantId,
    File front, {
    File? back,
    required String idType,
    String? idNumber,
    String? expiryDate,
  }) async {
    final fields = <String, dynamic>{'idType': idType};
    if (idNumber != null && idNumber.isNotEmpty) fields['idNumber'] = idNumber;
    if (expiryDate != null && expiryDate.isNotEmpty)
      fields['expiryDate'] = expiryDate;
    final files = <String, File>{'front': front};
    if (back != null) files['back'] = back;
    return await ApiService(logisticsBaseUrl: true).multipleFileUpload(
      OnboardingEndpoints.merchantUploadIdProof(merchantId),
      fields,
      files: files,
    );
  }

  @override
  Future postUploadAddressProof(String merchantId, File file) async {
    return await ApiService(logisticsBaseUrl: true).multipleFileUpload(
      OnboardingEndpoints.merchantUploadAddressProof(merchantId),
      {},
      files: {'file': file},
    );
  }

  @override
  Future postUploadBankStatement(String merchantId, File file) async {
    return await ApiService(logisticsBaseUrl: true).multipleFileUpload(
      OnboardingEndpoints.merchantUploadBankStatement(merchantId),
      {},
      files: {'file': file},
    );
  }

  // JSON document URL submission
  @override
  Future postDocBusinessReg(
    String merchantId,
    Map<String, dynamic> params,
  ) async {
    return await ApiService(
      logisticsBaseUrl: true,
    ).post(OnboardingEndpoints.merchantDocBusinessReg(merchantId), params);
  }

  @override
  Future postDocTrn(String merchantId, Map<String, dynamic> params) async {
    return await ApiService(
      logisticsBaseUrl: true,
    ).post(OnboardingEndpoints.merchantDocTrn(merchantId), params);
  }

  @override
  Future postDocIdProof(String merchantId, Map<String, dynamic> params) async {
    return await ApiService(
      logisticsBaseUrl: true,
    ).post(OnboardingEndpoints.merchantDocIdProof(merchantId), params);
  }

  @override
  Future postDocAddressProof(
    String merchantId,
    Map<String, dynamic> params,
  ) async {
    return await ApiService(
      logisticsBaseUrl: true,
    ).post(OnboardingEndpoints.merchantDocAddressProof(merchantId), params);
  }

  @override
  Future postDocBankStatement(
    String merchantId,
    Map<String, dynamic> params,
  ) async {
    return await ApiService(
      logisticsBaseUrl: true,
    ).post(OnboardingEndpoints.merchantDocBankStatement(merchantId), params);
  }

  @override
  Future getDocumentStatus(String merchantId) async {
    return await ApiService(
      logisticsBaseUrl: true,
    ).get(OnboardingEndpoints.merchantDocumentStatus(merchantId));
  }
}

/// Repository for Merchant
class MerchantRepo {
  final MerchantApiService _api = MerchantImpl();

  Future<dynamic> register(Map<String, dynamic> params) async {
    final response = await _api.postRegister(params);
    return response?.data;
  }

  Future<dynamic> uploadAllDocuments(
    String merchantId,
    Map<String, dynamic> fields,
    Map<String, File> files,
  ) async {
    final response = await _api.postUploadAllDocuments(
      merchantId,
      fields,
      files,
    );
    return response?.data;
  }

  Future<dynamic> uploadBusinessReg(
    String merchantId,
    File file, {
    String? registrationNumber,
  }) async {
    final response = await _api.postUploadBusinessReg(
      merchantId,
      file,
      registrationNumber: registrationNumber,
    );
    return response?.data;
  }

  Future<dynamic> uploadTrn(
    String merchantId,
    File file, {
    required String trnNumber,
  }) async {
    final response = await _api.postUploadTrn(
      merchantId,
      file,
      trnNumber: trnNumber,
    );
    return response?.data;
  }

  Future<dynamic> uploadIdProof(
    String merchantId,
    File front, {
    File? back,
    required String idType,
    String? idNumber,
    String? expiryDate,
  }) async {
    final response = await _api.postUploadIdProof(
      merchantId,
      front,
      back: back,
      idType: idType,
      idNumber: idNumber,
      expiryDate: expiryDate,
    );
    return response?.data;
  }

  Future<dynamic> uploadAddressProof(String merchantId, File file) async {
    final response = await _api.postUploadAddressProof(merchantId, file);
    return response?.data;
  }

  Future<dynamic> uploadBankStatement(String merchantId, File file) async {
    final response = await _api.postUploadBankStatement(merchantId, file);
    return response?.data;
  }

  // JSON document URL submission
  Future<dynamic> submitDocBusinessReg(
    String merchantId, {
    required String registrationNumber,
    required String documentUrl,
  }) async {
    final response = await _api.postDocBusinessReg(merchantId, {
      'registrationNumber': registrationNumber,
      'documentUrl': documentUrl,
    });
    return response?.data;
  }

  Future<dynamic> submitDocTrn(
    String merchantId, {
    required String trnNumber,
    required String documentUrl,
  }) async {
    final response = await _api.postDocTrn(merchantId, {
      'trnNumber': trnNumber,
      'documentUrl': documentUrl,
    });
    return response?.data;
  }

  Future<dynamic> submitDocIdProof(
    String merchantId, {
    required String idType,
    required String frontUrl,
    String? backUrl,
    String? idNumber,
    String? expiryDate,
  }) async {
    final params = <String, dynamic>{'idType': idType, 'frontUrl': frontUrl};
    if (backUrl != null) params['backUrl'] = backUrl;
    if (idNumber != null && idNumber.isNotEmpty) params['idNumber'] = idNumber;
    if (expiryDate != null && expiryDate.isNotEmpty)
      params['expiryDate'] = expiryDate;
    final response = await _api.postDocIdProof(merchantId, params);
    return response?.data;
  }

  Future<dynamic> submitDocAddressProof(
    String merchantId, {
    required String documentUrl,
  }) async {
    final response = await _api.postDocAddressProof(merchantId, {
      'documentUrl': documentUrl,
    });
    return response?.data;
  }

  Future<dynamic> submitDocBankStatement(
    String merchantId, {
    required String documentUrl,
  }) async {
    final response = await _api.postDocBankStatement(merchantId, {
      'documentUrl': documentUrl,
    });
    return response?.data;
  }

  Future<dynamic> getDocumentStatus(String merchantId) async {
    final response = await _api.getDocumentStatus(merchantId);
    return response?.data;
  }
}
