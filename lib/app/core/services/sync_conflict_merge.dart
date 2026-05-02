import '../models/app_models.dart';

/// Summary of a cases merge for telemetry (optional).
class CasesMergeStats {
  const CasesMergeStats({
    required this.remoteCount,
    required this.localWinCount,
    required this.keptLocalOnlyCount,
  });

  final int remoteCount;
  final int localWinCount;
  final int keptLocalOnlyCount;
}

/// Per-case last-write-wins: if the same id exists locally and remotely, keep the newer [StudentCase.updatedAt].
///
/// Local-only rows (e.g. pending remote create with client-generated ids) are retained when absent from [remote].
(List<StudentCase>, CasesMergeStats) mergeCasesRemoteWithLocal(
  List<StudentCase> remote,
  List<StudentCase> local,
) {
  final byId = <String, StudentCase>{
    for (final r in remote) r.id: r,
  };
  var localWins = 0;
  var keptLocalOnly = 0;

  for (final loc in local) {
    final existing = byId[loc.id];
    if (existing == null) {
      byId[loc.id] = loc;
      keptLocalOnly++;
      continue;
    }
    if (loc.updatedAt.isAfter(existing.updatedAt)) {
      byId[loc.id] = loc;
      localWins++;
    }
  }

  final out = byId.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return (
    out,
    CasesMergeStats(
      remoteCount: remote.length,
      localWinCount: localWins,
      keptLocalOnlyCount: keptLocalOnly,
    ),
  );
}

/// Union by (type, itemId): all remote rows plus local rows missing from remote (offline saves).
(List<SavedItem>, int) mergeSavedItemsUnion(
  List<SavedItem> remote,
  List<SavedItem> local,
) {
  final remoteKeys = <String>{
    for (final s in remote) '${s.type.name}:${s.itemId}',
  };
  final merged = <SavedItem>[...remote];
  var extra = 0;
  for (final s in local) {
    final key = '${s.type.name}:${s.itemId}';
    if (!remoteKeys.contains(key)) {
      merged.add(s);
      extra++;
    }
  }
  return (merged, extra);
}
