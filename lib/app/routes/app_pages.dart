import 'package:get/get.dart';

import '../feature/auth/auth_presentation/create_account_screen.dart';
import '../feature/auth/auth_presentation/retype_pass_screen.dart';
import '../feature/auth/auth_presentation/sent_otp_screen.dart';
import '../feature/auth/auth_presentation/signin_screen.dart';
import '../feature/auth/auth_presentation/signup_screen.dart';
import '../feature/auth/auth_presentation/user_registration_info_screen.dart';
import '../feature/auth/auth_presentation/verify_otp_screen.dart';
import '../feature/placeholder/placeholder_screen.dart';
import '../feature/splash/splash_presentation/splash_screen.dart';
import 'app_routes.dart';

class AppPages {
  static const _transition = Transition.rightToLeft;
  static const _duration = Duration(milliseconds: 200);

  static final List<GetPage> pages = [
    _page(AppRoutes.SplashScreen, () => const SplashScreen()),

    // Auth
    _page(AppRoutes.SigninScreen, () => const SigninScreen()),
    _page(AppRoutes.SignupScreen, () => const SignupScreen()),
    _page(AppRoutes.CreateAccountScreen, () => const CreateAccountScreen()),
    _page(
      AppRoutes.UserRegistrationInfoScreen,
      () => const UserRegistrationInfoScreen(),
    ),
    _page(AppRoutes.SentOtpScreen, () => const SentOtpScreen()),
    _page(AppRoutes.VerifyOtpScreen, () => const VerifyOtpScreen()),
    _page(AppRoutes.RetypePassScreen, () => const RetypePassScreen()),

    // Screens the template does not ship — auth navigates here, so they are
    // stubbed rather than left unrouted. Swap in your own pages.
    _page(
      AppRoutes.OnboardingScreen,
      () => const PlaceholderScreen(title: 'Onboarding'),
    ),
    _page(
      AppRoutes.DashboardScreen,
      () => const PlaceholderScreen(title: 'Dashboard'),
    ),
    _page(
      AppRoutes.TermsOfServiceScreen,
      () => const PlaceholderScreen(title: 'Terms of Service'),
    ),
    _page(
      AppRoutes.PrivacyPolicyScreen,
      () => const PlaceholderScreen(title: 'Privacy Policy'),
    ),
  ];

  /// Shown for an unknown route instead of GetX's blank red page.
  static final GetPage unknownRoute = _page(
    '/notFound',
    () => const PlaceholderScreen(title: 'Page not found'),
  );

  static GetPage _page(String name, GetPageBuilder page) => GetPage(
    name: name,
    page: page,
    transition: _transition,
    transitionDuration: _duration,
  );
}
