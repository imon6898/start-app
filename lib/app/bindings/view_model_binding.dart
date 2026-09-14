import "package:get/get.dart";

import "../feature/auth/auth_controllers/create_account_controller.dart";
import "../feature/auth/auth_controllers/retype_pass_controller.dart";
import "../feature/auth/auth_controllers/sent_otp_controller.dart";
import "../feature/auth/auth_controllers/signin_controller.dart";
import "../feature/auth/auth_controllers/signup_controller.dart";
import "../feature/auth/auth_controllers/verify_otp_controller.dart";
import "../feature/splash/controllers/splash_controller.dart";
import "../themes/theme_controller.dart";

class ViewModelBinding extends Bindings {
  @override
  void dependencies() {
    _lazy<ThemeController>(() => ThemeController());
    _lazy<SplashScreenController>(() => SplashScreenController());

    // Auth
    _lazy<SigninController>(() => SigninController());
    _lazy<SignupController>(() => SignupController());
    _lazy<CreateAccountController>(() => CreateAccountController());
    _lazy<SentOtpController>(() => SentOtpController());
    _lazy<VerifyOtpController>(() => VerifyOtpController());
    _lazy<RetypePassController>(() => RetypePassController());
  }

  /// Register a screen-scoped controller once; rebuilt after a `Get.delete`.
  void _lazy<T>(T Function() create) {
    if (!Get.isRegistered<T>()) Get.lazyPut<T>(create, fenix: true);
  }
}
