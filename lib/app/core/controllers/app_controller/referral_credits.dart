part of '../app_controller.dart';

/// No-cash referral rewards (KPB-77). The balance lives on the backend; this
/// mixin keeps a last-synced copy for display and routes redemptions through
/// the server (which is the source of truth — no local credit arithmetic).
mixin _ReferralCreditsMixin on _AppControllerBase {
  /// Refresh the referral reward balance from the backend. No-ops (keeping the
  /// last known value) when offline or on a transient failure.
  Future<void> refreshReviewCredits() async {
    if (!await _apiClient.hasAuthSession()) return;
    try {
      final data = await _apiClient.getMyReferralCredits();
      _reviewCredits = (data['balance'] as num?)?.toInt() ?? _reviewCredits;
      _persist();
      update();
    } catch (_) {
      // Keep the last known balance.
    }
  }

  /// Spend a credit for a WhatsApp advisor review voucher. Returns the backend
  /// result (`{ok, balance, voucherCode}` or `{ok:false, reason}`) and re-syncs
  /// the balance from the authoritative response on success.
  Future<Map<String, dynamic>> redeemReviewVoucher(String clientRef) async {
    final res = await _apiClient.redeemReviewVoucher(clientRef);
    if (res['ok'] == true) {
      _reviewCredits = (res['balance'] as num?)?.toInt() ?? _reviewCredits;
      _persist();
      update();
    }
    return res;
  }
}
