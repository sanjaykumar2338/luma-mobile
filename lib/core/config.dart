class AppConfig {
  const AppConfig._();
  static const apiBaseUrl = String.fromEnvironment(
    'LUMA_API_BASE_URL',
    defaultValue: 'https://lumaword.app/api/v1',
  );
}
