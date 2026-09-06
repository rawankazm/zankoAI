class AppEnv {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kjslmvoaanoqrizawllh.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_',
  );

  // DigitalOcean Trusted Backend API URL
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'https://api.zankoai.com/api/v1',
  );

  // Google OAuth Client IDs (Public Client Identifiers - Never secrets)
  // Web Client ID is used as serverClientId for native Google Sign-In verification
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '437131075344-rj6c49slq5sm6k7qc7sm6hkhahq6p06n.apps.googleusercontent.com',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: 'YOUR_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com',
  );

  // Secure Deep Link Redirects
  static const String authRedirectScheme = 'io.supabase.zankoai';
  static const String authRedirectUrl = '$authRedirectScheme://login-callback';
  static const String passwordResetRedirectUrl = '$authRedirectScheme://reset-password';
}

