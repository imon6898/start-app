/// English is the source language: every value equals its key, so a string with
/// no entry here still renders as readable English.
const Map<String, String> enUs = {
  // Common
  'Continue': 'Continue',
  'Skip': 'Skip',
  'Get Started': 'Get Started',
  'Cancel': 'Cancel',
  'Delete': 'Delete',
  'Please wait': 'Please wait',
  'Warning': 'Warning',
  'or': 'or',

  // Empty and busy states
  'Search...': 'Search...',
  'Not found': 'Not found',
  'No data found': 'No data found',
  'No value provided': 'No value provided',
  'Thinking': 'Thinking',
  'Write something...': 'Write something...',

  // Network
  'No internet connection': 'No internet connection',
  'Please check your internet connection':
      'Please check your internet connection',

  // Feedback — snack bar titles and messages
  'Error': 'Error',
  'Success': 'Success',
  'Welcome!': 'Welcome!',
  'Login Required': 'Login Required',
  'Authentication failed': 'Authentication failed',
  'Login successful': 'Login successful',
  'Please check your credentials': 'Please check your credentials',
  'Please fill in all fields': 'Please fill in all fields',
  'Something went wrong. Please try again.':
      'Something went wrong. Please try again.',
  'Sign in failed. Please try again.': 'Sign in failed. Please try again.',
  'Google sign in failed. Please try again.':
      'Google sign in failed. Please try again.',
  'Apple sign in failed. Please try again.':
      'Apple sign in failed. Please try again.',
  'Account created successfully': 'Account created successfully',
  'Account created successfully. Please verify your email.':
      'Account created successfully. Please verify your email.',
  'Failed to create account. Please try again.':
      'Failed to create account. Please try again.',
  'Registration completed successfully.':
      'Registration completed successfully.',
  'Account verified! Please login to continue.':
      'Account verified! Please login to continue.',
  'Please verify your email to continue. OTP has been sent to your email.':
      'Please verify your email to continue. OTP has been sent to your email.',
  'Failed to send OTP. Please try again.':
      'Failed to send OTP. Please try again.',
  'OTP verified successfully': 'OTP verified successfully',
  'Invalid OTP. Please try again.': 'Invalid OTP. Please try again.',
  'OTP resent successfully': 'OTP resent successfully',
  'Failed to resend OTP. Please try again.':
      'Failed to resend OTP. Please try again.',

  // Destructive confirm
  'Delete this item?': 'Delete this item?',
  'Once you delete this you can’t restore it.':
      'Once you delete this you can’t restore it.',

  // Pickers and upload
  'Country': 'Country',
  'Search country...': 'Search country...',
  'Select date': 'Select date',
  'Click or drag file to upload': 'Click or drag file to upload',
  'Uploaded • Tap to replace': 'Uploaded • Tap to replace',

  // Sign in
  'Welcome back': 'Welcome back',
  'Please enter your registration email & password':
      'Please enter your registration email & password',
  'Login': 'Login',
  'Login with Google': 'Login with Google',
  'Login with Apple': 'Login with Apple',
  'Forgot Password': 'Forgot Password',
  'Forgot Password?': 'Forgot Password?',
  'Don’t have an account?': 'Don’t have an account?',
  'Create New Account': 'Create New Account',
  'Already have an account?': 'Already have an account?',

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
  'Phone': 'Phone',
  'Phone Number': 'Phone Number',
  'Enter phone number': 'Enter phone number',
  'Address': 'Address',
  'Enter your address': 'Enter your address',
  'I agree to the': 'I agree to the',
  'Terms': 'Terms',
  'Privacy Policy': 'Privacy Policy',
  'Accept terms': 'Accept terms',
  'Please accept terms': 'Please accept terms',

  // OTP
  'Verification': 'Verification',
  'We’ve sent a code to your email': 'We’ve sent a code to your email',
  'Didn’t receive code?': 'Didn’t receive code?',
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
  'Please enter a valid email address.': 'Please enter a valid email address.',
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
  'Please enter a valid phone number.': 'Please enter a valid phone number.',
  'Phone number is too short.': 'Phone number is too short.',
  'Phone number is too long.': 'Phone number is too long.',
  'Address is required': 'Address is required',
  'Please select a country': 'Please select a country',
  'Please enter the verification code.': 'Please enter the verification code.',
  'Account number is required.': 'Account number is required.',
  'Enter a valid account number.': 'Enter a valid account number.',
  // @n is filled by trParams — never interpolate into a key, it can't match.
  'Must be @n characters or less.': 'Must be @n characters or less.',
  'Email must be @n characters or less.':
      'Email must be @n characters or less.',
  'Enter the @n-digit code.': 'Enter the @n-digit code.',
};
