/// Konfigurasi OAuth Google (Google Auth Platform, project `shicomp-005231`).
///
/// Client ID bukan rahasia — aman disimpan di repo. Bisa juga dioverride saat
/// build: `flutter build apk --dart-define=GOOGLE_WEB_CLIENT_ID=xxx`.
abstract final class GoogleConfig {
  /// OAuth client bertipe "Web application" — dipakai sebagai `serverClientId`
  /// oleh Credential Manager di Android.
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

  /// OAuth client bertipe "iOS" (opsional, hanya untuk build iOS).
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');

  static bool get isConfigured => webClientId.isNotEmpty;
}
