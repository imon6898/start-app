import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:flutter_starter/app/core/config/env.dart';
import 'package:flutter_starter/app/core/models/base_response.dart';
import 'package:flutter_starter/app/feature/payment/payment_logic/payment_api_service.dart';
import 'package:flutter_starter/app/feature/payment/payment_models/payment_intent_model.dart';
import 'package:flutter_starter/app/feature/payment/payment_models/payment_result.dart';
import 'package:flutter_starter/app/services/domain/dev_tools.dart';
import 'package:flutter_starter/app/widgets/feedback/custom_snack_bar.dart';

/// Drives one Stripe PaymentSheet checkout.
///
/// The app never sees a secret key: the backend creates the PaymentIntent, the
/// app confirms it with the client_secret, and the Stripe webhook — not this
/// controller — is what actually proves a payment succeeded.
class PaymentController extends GetxController {
  final PaymentRepo _repo = PaymentRepo();

  final RxBool isLoadingPayment = false.obs;
  final Rx<PaymentResult?> lastResult = Rx<PaymentResult?>(null);
  final Rx<PaymentIntentModel?> paymentIntent = Rx<PaymentIntentModel?>(null);

  /// Merchant name shown on the sheet. Set it before calling [pay].
  String merchantDisplayName = 'Flutter Starter';

  /// True once a valid publishable key was applied.
  bool get isReady => _isReady;
  bool _isReady = false;

  @override
  void onInit() {
    super.onInit();
    _initStripe();
  }

  @override
  void onClose() {
    isLoadingPayment.close();
    lastResult.close();
    paymentIntent.close();
    super.onClose();
  }

  /// Publishable key only — an `sk_` key in a mobile binary is extractable and
  /// lets anyone charge your account. Missing key degrades, never crashes.
  void _initStripe() {
    final String key = Env.stripePublishableKey;
    if (key.isEmpty) {
      devPrint('STRIPE_PUBLISHABLE_KEY is not set in .env — payments disabled');
      return;
    }
    if (!key.startsWith('pk_')) {
      devPrint('STRIPE_PUBLISHABLE_KEY must start with pk_ — never ship sk_');
      return;
    }
    Stripe.publishableKey = key;
    _isReady = true;
  }

  /// Runs the full checkout and returns the outcome the UI switches on.
  Future<PaymentResult> pay({
    required int amountMinor,
    required String currency,
    String? description,
  }) async {
    if (!_isReady) {
      return _finish(
        const PaymentFailed('Stripe is not configured'),
        'Payment unavailable'.tr,
        'Payment is not configured for this app'.tr,
        SnackBarType.Failure,
      );
    }
    if (isLoadingPayment.value) return const PaymentCancelled();

    isLoadingPayment.value = true;
    try {
      // A hint for the order only — the backend must re-derive the real amount.
      final Map<String, dynamic> params = {
        'amount': amountMinor,
        'currency': currency,
        if (description != null && description.isNotEmpty)
          'description': description,
      };

      final response = await _repo.createPaymentIntent(params);
      final baseResponse = BaseResponse<PaymentIntentModel>.fromJson(
        response!,
        (data) => PaymentIntentModel.fromJson(data),
      );

      final PaymentIntentModel? intent = baseResponse.data;
      final String secret = intent?.clientSecret ?? '';
      if (secret.isEmpty) {
        return _finish(
          PaymentFailed(baseResponse.message),
          'Payment failed'.tr,
          baseResponse.message.isEmpty
              ? 'Could not start the payment'.tr
              : baseResponse.message,
          SnackBarType.Failure,
        );
      }
      paymentIntent.value = intent;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: secret,
          customerId: intent?.customerId,
          customerEphemeralKeySecret: intent?.ephemeralKey,
          merchantDisplayName: merchantDisplayName,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Sheet closed without throwing; ask the backend what the webhook saw.
      final String? status = await verifyStatus(intent?.paymentIntentId);
      return _finish(
        PaymentSuccess(
          paymentIntentId: intent?.paymentIntentId,
          status: status,
        ),
        'Payment successful'.tr,
        'Your payment has been submitted'.tr,
        SnackBarType.Success,
      );
    } on StripeException catch (e) {
      return _handleStripeException(e);
    } catch (e) {
      devPrint('pay failed: $e');
      return _finish(
        PaymentFailed(e.toString()),
        'Payment failed'.tr,
        'Something went wrong. Please try again.'.tr,
        SnackBarType.Failure,
      );
    } finally {
      isLoadingPayment.value = false;
    }
  }

  /// Optional read-back. The Stripe webhook on your backend is the real source
  /// of truth — this only reports what the backend already recorded.
  Future<String?> verifyStatus(String? paymentIntentId) async {
    if (paymentIntentId == null || paymentIntentId.isEmpty) return null;
    try {
      final response = await _repo.fetchPaymentStatus({
        'payment_intent_id': paymentIntentId,
      });
      final baseResponse = BaseResponse<PaymentIntentModel>.fromJson(
        response!,
        (data) => PaymentIntentModel.fromJson(data),
      );
      if (baseResponse.data != null) paymentIntent.value = baseResponse.data;
      return baseResponse.data?.status;
    } catch (e) {
      devPrint('verifyStatus failed: $e');
      return null;
    }
  }

  /// Clears the last attempt so a screen can be reused.
  void reset() {
    lastResult.value = null;
    paymentIntent.value = null;
  }

  /// A dismissed sheet is a cancellation, everything else is a failure.
  PaymentResult _handleStripeException(StripeException e) {
    final error = e.error;
    devPrint('StripeException: ${error.code} ${error.message}');

    if (error.code == FailureCode.Canceled) {
      return _finish(
        const PaymentCancelled(),
        'Payment cancelled'.tr,
        'You cancelled the payment'.tr,
        SnackBarType.Warning,
      );
    }

    final String message =
        error.localizedMessage ?? error.message ?? 'Payment failed';
    return _finish(
      PaymentFailed(message, declineCode: error.declineCode),
      'Payment failed'.tr,
      message,
      SnackBarType.Failure,
    );
  }

  /// Stores the outcome, tells the user, and hands the result back.
  PaymentResult _finish(
    PaymentResult result,
    String title,
    String description,
    SnackBarType type,
  ) {
    lastResult.value = result;
    final context = Get.context;
    if (context != null) {
      showCustomSnackBar(
        context: context,
        type: type,
        title: title,
        description: description,
      );
    }
    return result;
  }
}
