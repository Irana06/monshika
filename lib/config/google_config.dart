/// Konfigurasi OAuth Google (Google Auth Platform, project `shicomp-005231`).
///
/// Client ID bukan rahasia — aman disimpan di repo. Bisa juga dioverride saat
/// build: `flutter build apk --dart-define=GOOGLE_WEB_CLIENT_ID=xxx`.
abstract final class GoogleConfig {
  /// OAuth client bertipe "Web application" — dipakai sebagai `serverClientId`
  /// oleh Credential Manager di Android.
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '436195400515-t0m5ue4dl5ppqsniojd6epnf1joo7ntg.apps.googleusercontent.com',
  );

  /// OAuth client bertipe "iOS" (opsional, hanya untuk build iOS).
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');

  static bool get isConfigured => webClientId.isNotEmpty;
}
