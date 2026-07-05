import { AppConfigController } from './app-config.controller';

describe('AppConfigController', () => {
  const previousEnv = {
    KPB_MIN_APP_VERSION: process.env.KPB_MIN_APP_VERSION,
    KPB_ANDROID_STORE_URL: process.env.KPB_ANDROID_STORE_URL,
    KPB_IOS_STORE_URL: process.env.KPB_IOS_STORE_URL,
  };

  afterEach(() => {
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  });

  it('defaults to a non-blocking minVersion when unset', () => {
    delete process.env.KPB_MIN_APP_VERSION;
    const config = new AppConfigController().getAppConfig();
    expect(config.minVersion).toBe('0.0.0');
    expect(config.androidStoreUrl).toContain('com.kpbeducation.app');
  });

  it('returns the configured minVersion and store URLs, trimmed', () => {
    process.env.KPB_MIN_APP_VERSION = ' 1.2.0 ';
    process.env.KPB_ANDROID_STORE_URL = 'https://play.example/app ';
    process.env.KPB_IOS_STORE_URL = ' https://apps.example/app';
    const config = new AppConfigController().getAppConfig();
    expect(config).toEqual({
      minVersion: '1.2.0',
      androidStoreUrl: 'https://play.example/app',
      iosStoreUrl: 'https://apps.example/app',
    });
  });
});
