/// Endpoints for the rider/merchant onboarding flow. Point these at your own backend.
class OnboardingEndpoints {
  /// Service prefix on the logistics base URL.
  static const String logistics = '/logistics';

  // Location lookups (parish -> city -> zone cascade).
  static const String parishesUri = '$logistics/parishes';
  static String citiesInParish(String parishId) =>
      '$logistics/parishes/$parishId/cities';
  static String zonesInCity(String cityId) => '$logistics/cities/$cityId/zones';

  // Rider registration, one call per step.
  static const String riderStep1 = '$logistics/riders/register';
  static String riderStep2(String riderId) =>
      '$logistics/riders/$riderId/documents';
  static String riderStep3(String riderId) =>
      '$logistics/riders/$riderId/vehicle';
  static String riderStep4(String riderId) =>
      '$logistics/riders/$riderId/bank-details';

  // Merchant registration.
  static const String merchantRegisterUri = '$logistics/merchants/register';
  static String merchantUploadAllUri(String id) =>
      '$logistics/merchants/$id/documents';
  static String merchantUploadBusinessReg(String id) =>
      '$logistics/merchants/$id/documents/business-registration';
  static String merchantUploadTrn(String id) =>
      '$logistics/merchants/$id/documents/trn';
  static String merchantUploadIdProof(String id) =>
      '$logistics/merchants/$id/documents/id-proof';
  static String merchantUploadAddressProof(String id) =>
      '$logistics/merchants/$id/documents/address-proof';
  static String merchantUploadBankStatement(String id) =>
      '$logistics/merchants/$id/documents/bank-statement';

  // Same documents submitted as already-hosted URLs instead of multipart files.
  static String merchantDocBusinessReg(String id) =>
      '$logistics/merchants/$id/docs/business-registration';
  static String merchantDocTrn(String id) =>
      '$logistics/merchants/$id/docs/trn';
  static String merchantDocIdProof(String id) =>
      '$logistics/merchants/$id/docs/id-proof';
  static String merchantDocAddressProof(String id) =>
      '$logistics/merchants/$id/docs/address-proof';
  static String merchantDocBankStatement(String id) =>
      '$logistics/merchants/$id/docs/bank-statement';
  static String merchantDocumentStatus(String id) =>
      '$logistics/merchants/$id/documents/status';
}
