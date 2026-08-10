// Surface the referral code carried by the invite link. No tracking, no
// redirect: the visitor chooses their store. `to` (the in-app destination)
// is intentionally ignored here — it becomes useful only once App Links
// association is live and this URL can open the app directly.
// External file on purpose: the site CSP (default-src 'self') blocks inline
// scripts, which silently disabled this logic when it lived in invite.html.
(function () {
  var params = new URLSearchParams(window.location.search);
  var ref = (params.get('ref') || '').trim();
  if (ref) {
    document.getElementById('ref-code').textContent = ref;
    document.getElementById('ref-card').hidden = false;
  }
})();
