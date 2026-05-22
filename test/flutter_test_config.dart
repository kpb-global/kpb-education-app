import 'dart:async';
import 'package:karatou/app/core/config/app_config.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppConfig.enableRemoteSyncOverride = false;
  await testMain();
}
