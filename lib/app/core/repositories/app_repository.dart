import 'app_snapshot.dart';

abstract class AppRepository {
  Future<AppSnapshot> loadSnapshot();
  Future<void> saveSnapshot(AppSnapshot snapshot);
}
