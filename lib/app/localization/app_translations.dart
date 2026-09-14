import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../services/local_data/cache_manager.dart';

/// Keys are the English source strings, so `.tr` still renders correctly for a
/// locale that has no entry here. Bengali ships as the worked example.
class AppTranslations extends Translations {
  static const Locale fallbackLocale = Locale('en', 'US');

  /// Locales with a map below; anything else falls back to the key itself.
  static const List<Locale> supported = [
    Locale('en', 'US'),
    Locale('bn', 'BD'),
  ];

  /// Saved choice wins, then device locale, then [fallbackLocale].
  static Locale get initialLocale {
    final saved = _parse(CacheManager.getLocale);
    if (saved != null) return saved;

    final device = Get.deviceLocale;
    final match = supported.where(
      (l) => l.languageCode == device?.languageCode,
    );
    return match.isEmpty ? fallbackLocale : match.first;
  }

  /// Switches locale and persists it so the next launch keeps the choice.
  static Future<void> setLocale(Locale locale) async {
    await CacheManager.setLocale('${locale.languageCode}_${locale.countryCode}');
    await Get.updateLocale(locale);
  }

  /// Parses "bn_BD" back to a supported [Locale], or null if unknown.
  static Locale? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('_');
    final match = supported.where((l) => l.languageCode == parts.first);
    return match.isEmpty ? null : match.first;
  }

  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      // Common
      'Continue': 'Continue',
      'Skip': 'Skip',
      'Get Started': 'Get Started',
      'Please wait': 'Please wait',
      'warning': 'Warning',
      'or': 'or',

      // Sign in
      'Welcome back': 'Welcome back',
      'Please enter your registration email & password':
          'Please enter your registration email & password',
      'Login': 'Login',
      'Log In': 'Log In',
      'Login with Google': 'Login with Google',
      'Login With Apple': 'Login With Apple',
      'Forgot Password': 'Forgot Password',
      'Forget Password?': 'Forget Password?',
      'Don’t have an account?': 'Don’t have an account?',
      'Create New Account': 'Create New Account',
      'Already have an account? ': 'Already have an account? ',

      // Account type
      'Personal account': 'Personal account',
      'Business account': 'Business account',
      'For individuals using the app on their own.':
          'For individuals using the app on their own.',
      'For teams and organizations.': 'For teams and organizations.',

      // Sign up
      'Create Account': 'Create Account',
      'Tell us a bit about yourself to finish setting up your account.':
          'Tell us a bit about yourself to finish setting up your account.',
      'First Name': 'First Name',
      'Enter your first name': 'Enter your first name',
      'Last Name': 'Last Name',
      'Enter your last name': 'Enter your last name',
      'Email': 'Email',
      'Email Address': 'Email Address',
      'Enter your email': 'Enter your email',
      'Enter email address': 'Enter email address',
      'Phone': 'Phone',
      'Phone Number': 'Phone Number',
      'Enter phone number': 'Enter phone number',
      'Address': 'Address',
      'Enter your address': 'Enter your address',
      'I agree to the': 'I agree to the',
      'I agree to the ': 'I agree to the ',
      'Terms': 'Terms',
      'Privacy Policy': 'Privacy Policy',
      'Accept terms': 'Accept terms',
      'Please accept terms': 'Please accept terms',

      // OTP
      'Verification': 'Verification',
      'We’ve the code send to your email': 'We’ve the code send to your email',
      'Didn’t receive code? ': 'Didn’t receive code? ',
      'Resend Code': 'Resend Code',
      'Resend code success': 'Resend code success',
      'Wait for timer complete': 'Wait for timer complete',

      // Password
      'Password': 'Password',
      'Enter password': 'Enter password',
      'New Password': 'New Password',
      'Enter new password': 'Enter new password',
      'Confirm Password': 'Confirm Password',
      'Enter confirm password': 'Enter confirm password',
      'Confirm New Password': 'Confirm New Password',
      'Enter confirm new password': 'Enter confirm new password',
      'Change Password': 'Change Password',
      'Set-up new password': 'Set-up new password',
      'Create a new password to secure your account':
          'Create a new password to secure your account',

      // Forgot password
      'Enter the email address or phone number associated with your account.':
          'Enter the email address or phone number associated with your account.',

      // Validation
      'This field is required.': 'This field is required.',
      'Email is required.': 'Email is required.',
      'Please enter a valid email address.':
          'Please enter a valid email address.',
      'Password is required.': 'Password is required.',
      'Password must be at least 8 characters.':
          'Password must be at least 8 characters.',
      'Password must contain at least one letter.':
          'Password must contain at least one letter.',
      'Password must contain at least one number.':
          'Password must contain at least one number.',
      'Please confirm your password.': 'Please confirm your password.',
      'Passwords do not match.': 'Passwords do not match.',
      'Please enter a valid name.': 'Please enter a valid name.',
      'Must be at least 2 characters.': 'Must be at least 2 characters.',
      'Phone number is required.': 'Phone number is required.',
      'Please enter a valid phone number.':
          'Please enter a valid phone number.',
      'Address is required': 'Address is required',
      'Please enter the verification code.':
          'Please enter the verification code.',
      'Account number is required.': 'Account number is required.',
      'Enter a valid account number.': 'Enter a valid account number.',
      'You must agree to the terms': 'You must agree to the terms',
      // @n is filled by trParams — never interpolate into a key, it can't match.
      'Must be @n characters or less.': 'Must be @n characters or less.',
      'Email must be @n characters or less.':
          'Email must be @n characters or less.',
      'Enter the @n-digit code.': 'Enter the @n-digit code.',
    },
    'bn_BD': {
      // Common
      'Continue': 'চালিয়ে যান',
      'Skip': 'এড়িয়ে যান',
      'Get Started': 'শুরু করুন',
      'Please wait': 'অনুগ্রহ করে অপেক্ষা করুন',
      'warning': 'সতর্কতা',
      'or': 'অথবা',

      // Sign in
      'Welcome back': 'আবার স্বাগতম',
      'Please enter your registration email & password':
          'আপনার নিবন্ধিত ইমেইল ও পাসওয়ার্ড লিখুন',
      'Login': 'লগইন',
      'Log In': 'লগ ইন',
      'Login with Google': 'গুগল দিয়ে লগইন করুন',
      'Login With Apple': 'অ্যাপল দিয়ে লগইন করুন',
      'Forgot Password': 'পাসওয়ার্ড ভুলে গেছেন',
      'Forget Password?': 'পাসওয়ার্ড ভুলে গেছেন?',
      'Don’t have an account?': 'কোনো অ্যাকাউন্ট নেই?',
      'Create New Account': 'নতুন অ্যাকাউন্ট তৈরি করুন',
      'Already have an account? ': 'আগে থেকেই অ্যাকাউন্ট আছে? ',

      // Account type
      'Personal account': 'ব্যক্তিগত অ্যাকাউন্ট',
      'Business account': 'ব্যবসায়িক অ্যাকাউন্ট',
      'For individuals using the app on their own.':
          'যারা নিজে থেকে অ্যাপটি ব্যবহার করবেন তাদের জন্য।',
      'For teams and organizations.': 'দল ও প্রতিষ্ঠানের জন্য।',

      // Sign up
      'Create Account': 'অ্যাকাউন্ট তৈরি করুন',
      'Tell us a bit about yourself to finish setting up your account.':
          'অ্যাকাউন্ট সেটআপ শেষ করতে আপনার সম্পর্কে কিছু তথ্য দিন।',
      'First Name': 'প্রথম নাম',
      'Enter your first name': 'প্রথম নাম লিখুন',
      'Last Name': 'শেষ নাম',
      'Enter your last name': 'শেষ নাম লিখুন',
      'Email': 'ইমেইল',
      'Email Address': 'ইমেইল ঠিকানা',
      'Enter your email': 'ইমেইল লিখুন',
      'Enter email address': 'ইমেইল ঠিকানা লিখুন',
      'Phone': 'ফোন',
      'Phone Number': 'ফোন নম্বর',
      'Enter phone number': 'ফোন নম্বর লিখুন',
      'Address': 'ঠিকানা',
      'Enter your address': 'ঠিকানা লিখুন',
      'I agree to the': 'আমি সম্মত',
      'I agree to the ': 'আমি সম্মত ',
      'Terms': 'শর্তাবলী',
      'Privacy Policy': 'গোপনীয়তা নীতি',
      'Accept terms': 'শর্তাবলী গ্রহণ করুন',
      'Please accept terms': 'অনুগ্রহ করে শর্তাবলী গ্রহণ করুন',

      // OTP
      'Verification': 'যাচাইকরণ',
      'We’ve the code send to your email': 'আমরা আপনার ইমেইলে কোড পাঠিয়েছি',
      'Didn’t receive code? ': 'কোড পাননি? ',
      'Resend Code': 'পুনরায় কোড পাঠান',
      'Resend code success': 'কোড সফলভাবে পুনরায় পাঠানো হয়েছে',
      'Wait for timer complete': 'টাইমার শেষ হওয়া পর্যন্ত অপেক্ষা করুন',

      // Password
      'Password': 'পাসওয়ার্ড',
      'Enter password': 'পাসওয়ার্ড লিখুন',
      'New Password': 'নতুন পাসওয়ার্ড',
      'Enter new password': 'নতুন পাসওয়ার্ড লিখুন',
      'Confirm Password': 'পাসওয়ার্ড নিশ্চিত করুন',
      'Enter confirm password': 'পাসওয়ার্ড আবার লিখুন',
      'Confirm New Password': 'নতুন পাসওয়ার্ড নিশ্চিত করুন',
      'Enter confirm new password': 'নতুন পাসওয়ার্ড আবার লিখুন',
      'Change Password': 'পাসওয়ার্ড পরিবর্তন করুন',
      'Set-up new password': 'নতুন পাসওয়ার্ড সেট করুন',
      'Create a new password to secure your account':
          'আপনার অ্যাকাউন্ট সুরক্ষিত রাখতে নতুন পাসওয়ার্ড তৈরি করুন',

      // Forgot password
      'Enter the email address or phone number associated with your account.':
          'আপনার অ্যাকাউন্টের সাথে যুক্ত ইমেইল ঠিকানা বা ফোন নম্বর লিখুন।',

      // Validation
      'This field is required.': 'এই ঘরটি পূরণ করা আবশ্যক।',
      'Email is required.': 'ইমেইল আবশ্যক।',
      'Please enter a valid email address.': 'সঠিক ইমেইল ঠিকানা লিখুন।',
      'Password is required.': 'পাসওয়ার্ড আবশ্যক।',
      'Password must be at least 8 characters.':
          'পাসওয়ার্ড অন্তত ৮ অক্ষরের হতে হবে।',
      'Password must contain at least one letter.':
          'পাসওয়ার্ডে অন্তত একটি অক্ষর থাকতে হবে।',
      'Password must contain at least one number.':
          'পাসওয়ার্ডে অন্তত একটি সংখ্যা থাকতে হবে।',
      'Please confirm your password.': 'অনুগ্রহ করে পাসওয়ার্ড নিশ্চিত করুন।',
      'Passwords do not match.': 'পাসওয়ার্ড মিলছে না।',
      'Please enter a valid name.': 'সঠিক নাম লিখুন।',
      'Must be at least 2 characters.': 'অন্তত ২ অক্ষর হতে হবে।',
      'Phone number is required.': 'ফোন নম্বর আবশ্যক।',
      'Please enter a valid phone number.': 'সঠিক ফোন নম্বর লিখুন।',
      'Address is required': 'ঠিকানা আবশ্যক',
      'Please enter the verification code.': 'যাচাইকরণ কোড লিখুন।',
      'Account number is required.': 'অ্যাকাউন্ট নম্বর আবশ্যক।',
      'Enter a valid account number.': 'সঠিক অ্যাকাউন্ট নম্বর লিখুন।',
      'You must agree to the terms': 'আপনাকে শর্তাবলীতে সম্মত হতে হবে',
      'Must be @n characters or less.': 'সর্বোচ্চ @n অক্ষর হতে পারে।',
      'Email must be @n characters or less.':
          'ইমেইল সর্বোচ্চ @n অক্ষর হতে পারে।',
      'Enter the @n-digit code.': '@n সংখ্যার কোডটি লিখুন।',
    },
  };
}
