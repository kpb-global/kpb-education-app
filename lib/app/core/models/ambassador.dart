part of 'app_models.dart';

/// Milestone of a filleul (referred student) in the ambassador program.
enum ReferralMilestone {
  signedUp,
  quizCompleted,
  applicationCreated,
  premiumSubscribed,
  placed,
  churned,
}

ReferralMilestone _milestoneFromApi(Object? raw) {
  switch (raw) {
    case 'quiz_completed':
      return ReferralMilestone.quizCompleted;
    case 'application_created':
      return ReferralMilestone.applicationCreated;
    case 'premium_subscribed':
      return ReferralMilestone.premiumSubscribed;
    case 'placed':
      return ReferralMilestone.placed;
    case 'churned':
      return ReferralMilestone.churned;
    default:
      return ReferralMilestone.signedUp;
  }
}

class AmbassadorProfileInfo {
  const AmbassadorProfileInfo({
    this.displayName = '',
    this.campus = '',
    this.city = '',
    this.initials = '',
    this.code = '',
    this.rankLabel = '',
    this.payoutMethod = 'wave',
    this.payoutAccountMasked = '',
  });

  final String displayName;
  final String campus;
  final String city;
  final String initials;
  final String code;
  final String rankLabel; // "Top 3 Dakar" etc. (empty if unranked)
  final String payoutMethod;
  final String payoutAccountMasked;

  factory AmbassadorProfileInfo.fromApi(Map<String, dynamic> j) =>
      AmbassadorProfileInfo(
        displayName: j['displayName'] as String? ?? '',
        campus: j['campus'] as String? ?? '',
        city: j['city'] as String? ?? '',
        initials: j['initials'] as String? ?? '',
        code: j['code'] as String? ?? '',
        rankLabel: j['rankLabel'] as String? ?? '',
        payoutMethod: j['payoutMethod'] as String? ?? 'wave',
        payoutAccountMasked: j['payoutAccountMasked'] as String? ?? '',
      );
}

class AmbassadorReward {
  const AmbassadorReward({required this.reason, required this.amountFCFA});
  final String reason; // referral_signup | referral_placed | ...
  final int amountFCFA;

  factory AmbassadorReward.fromApi(Map<String, dynamic> j) => AmbassadorReward(
        reason: j['reason'] as String? ?? '',
        amountFCFA: (j['amountFCFA'] as num?)?.toInt() ?? 0,
      );
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.initials,
    required this.referrals,
    required this.isMe,
  });
  final int rank;
  final String name;
  final String initials;
  final int referrals;
  final bool isMe;

  factory LeaderboardEntry.fromApi(Map<String, dynamic> j) => LeaderboardEntry(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        initials: j['initials'] as String? ?? '',
        referrals: (j['referrals'] as num?)?.toInt() ?? 0,
        isMe: j['isMe'] as bool? ?? false,
      );
}

class ReferralEntry {
  const ReferralEntry({
    required this.name,
    required this.initials,
    required this.note,
    required this.status,
    required this.gainFCFA,
  });
  final String name;
  final String initials;
  final String note;
  final ReferralMilestone status;
  final int gainFCFA;

  factory ReferralEntry.fromApi(Map<String, dynamic> j) => ReferralEntry(
        name: j['name'] as String? ?? '',
        initials: j['initials'] as String? ?? '',
        note: j['note'] as String? ?? '',
        status: _milestoneFromApi(j['status']),
        gainFCFA: (j['gainFCFA'] as num?)?.toInt() ?? 0,
      );
}

class AmbassadorHistoryItem {
  const AmbassadorHistoryItem({
    required this.label,
    required this.date,
    required this.kind,
    required this.amountFCFA,
  });
  final String label;
  final String date; // ISO yyyy-MM-dd
  final String kind; // commission reason or 'withdrawal'
  final int amountFCFA; // signed

  factory AmbassadorHistoryItem.fromApi(Map<String, dynamic> j) =>
      AmbassadorHistoryItem(
        label: j['label'] as String? ?? '',
        date: j['date'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        amountFCFA: (j['amountFCFA'] as num?)?.toInt() ?? 0,
      );
}

/// The whole Ambassadeur surface payload from `GET /referrals/dashboard`.
class AmbassadorDashboard {
  const AmbassadorDashboard({
    required this.activated,
    required this.isSample,
    required this.ambassador,
    required this.activeReferrals,
    required this.placed,
    required this.earnedFCFA,
    required this.objectiveTarget,
    required this.objectiveCurrent,
    required this.objectiveBonusFCFA,
    required this.rewards,
    required this.leaderboard,
    required this.referrals,
    required this.balanceFCFA,
    required this.withdrawableFCFA,
    required this.minWithdrawalFCFA,
    required this.history,
  });

  final bool activated;
  final bool isSample;
  final AmbassadorProfileInfo ambassador;
  final int activeReferrals;
  final int placed;
  final int earnedFCFA;
  final int objectiveTarget;
  final int objectiveCurrent;
  final int objectiveBonusFCFA;
  final List<AmbassadorReward> rewards;
  final List<LeaderboardEntry> leaderboard;
  final List<ReferralEntry> referrals;
  final int balanceFCFA;
  final int withdrawableFCFA;
  final int minWithdrawalFCFA;
  final List<AmbassadorHistoryItem> history;

  bool get canWithdraw => withdrawableFCFA >= minWithdrawalFCFA;

  static List<Map<String, dynamic>> _list(Object? raw) =>
      (raw as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  factory AmbassadorDashboard.fromApi(Map<String, dynamic> j) {
    final stats = j['stats'] as Map<String, dynamic>? ?? const {};
    final obj = j['objective'] as Map<String, dynamic>? ?? const {};
    final amb = j['ambassador'] as Map<String, dynamic>? ?? const {};
    return AmbassadorDashboard(
      activated: j['activated'] as bool? ?? false,
      isSample: j['isSample'] as bool? ?? false,
      ambassador: AmbassadorProfileInfo.fromApi(amb),
      activeReferrals: (stats['activeReferrals'] as num?)?.toInt() ?? 0,
      placed: (stats['placed'] as num?)?.toInt() ?? 0,
      earnedFCFA: (stats['earnedFCFA'] as num?)?.toInt() ?? 0,
      objectiveTarget: (obj['target'] as num?)?.toInt() ?? 0,
      objectiveCurrent: (obj['current'] as num?)?.toInt() ?? 0,
      objectiveBonusFCFA: (obj['bonusFCFA'] as num?)?.toInt() ?? 0,
      rewards: _list(j['rewards']).map(AmbassadorReward.fromApi).toList(),
      leaderboard:
          _list(j['leaderboard']).map(LeaderboardEntry.fromApi).toList(),
      referrals: _list(j['referrals']).map(ReferralEntry.fromApi).toList(),
      balanceFCFA: (j['balanceFCFA'] as num?)?.toInt() ?? 0,
      withdrawableFCFA: (j['withdrawableFCFA'] as num?)?.toInt() ?? 0,
      minWithdrawalFCFA: (j['minWithdrawalFCFA'] as num?)?.toInt() ?? 20000,
      history: _list(j['history']).map(AmbassadorHistoryItem.fromApi).toList(),
    );
  }
}
