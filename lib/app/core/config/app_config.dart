class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'KPB_API_BASE_URL',
    defaultValue: 'https://api.kpb-education.com/api',
  );

  static const enableRemoteSync = bool.fromEnvironment(
    'KPB_ENABLE_REMOTE_SYNC',
    defaultValue: true,
  );

  static const requestTimeoutInSeconds = int.fromEnvironment(
    'KPB_REQUEST_TIMEOUT',
    defaultValue: 15,
  );

  static const storageNamespace = 'kpb_relaunch_v1';
}
