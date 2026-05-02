/// Version for JSON persisted in [LocalAppRepository] (`SharedPreferences`).
///
/// Increment when adding breaking changes to the snapshot map shape; implement
/// the corresponding step in [migrateAppSnapshotJson].
const kAppSnapshotFormatVersion = 1;

/// Mutates [json] in place so older stored blobs keep loading after schema edits.
void migrateAppSnapshotJson(Map<String, dynamic> json) {
  var from = 0;
  final raw = json['snapshotFormatVersion'];
  if (raw is int) {
    from = raw;
  } else if (raw is num) {
    from = raw.toInt();
  }

  while (from < kAppSnapshotFormatVersion) {
    from++;
    _migrateToVersion(json, from);
  }
  json['snapshotFormatVersion'] = kAppSnapshotFormatVersion;
}

void _migrateToVersion(Map<String, dynamic> json, int toVersion) {
  switch (toVersion) {
    case 1:
      // Legacy snapshots had no `snapshotFormatVersion` key; structure matches v1.
      break;
    default:
      break;
  }
}
