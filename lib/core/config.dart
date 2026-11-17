class AppConfig {
  const AppConfig._();
  static const apiBaseUrl = String.fromEnvironment(
    'LUMA_API_BASE_URL',
    defaultValue: 'https://lumaword.app/api/v1',
  );

  // These switches intentionally default to off. Enabling either feature
  // requires platform credentials and a verified Laravel contract.
  static const firebaseEnabled = bool.fromEnvironment(
    'LUMA_FIREBASE_ENABLED',
    defaultValue: false,
  );
  static const billingEnabled = bool.fromEnvironment(
    'LUMA_BILLING_ENABLED',
    defaultValue: false,
  );
  static const deviceTokenPath = String.fromEnvironment(
    'LUMA_DEVICE_TOKEN_PATH',
    defaultValue: '/mobile/device-tokens',
  );
  static const purchaseVerificationPath = String.fromEnvironment(
    'LUMA_PURCHASE_VERIFICATION_PATH',
    defaultValue: '/mobile/purchases/verify',
  );
  static const monthlyProductId = String.fromEnvironment(
    'LUMA_MONTHLY_PRODUCT_ID',
    defaultValue: '',
  );
  static const annualProductId = String.fromEnvironment(
    'LUMA_ANNUAL_PRODUCT_ID',
    defaultValue: '',
  );
}
