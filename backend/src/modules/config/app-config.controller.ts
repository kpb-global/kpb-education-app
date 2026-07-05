import { Controller, Get } from '@nestjs/common';

/**
 * Public, unauthenticated app configuration. The mobile client reads this at
 * boot to decide whether the installed build is still supported (force-update
 * gate). `minVersion` defaults to 0.0.0 — i.e. no build is ever blocked until
 * operators explicitly raise KPB_MIN_APP_VERSION.
 */
@Controller('config')
export class AppConfigController {
  @Get('app')
  getAppConfig() {
    return {
      minVersion: process.env.KPB_MIN_APP_VERSION?.trim() || '0.0.0',
      androidStoreUrl:
        process.env.KPB_ANDROID_STORE_URL?.trim() ||
        'https://play.google.com/store/apps/details?id=com.kpbeducation.app',
      iosStoreUrl: process.env.KPB_IOS_STORE_URL?.trim() || '',
    };
  }
}
