// Redirection intelligente vers le bon store selon le téléphone détecté.
// Fichier externe (et non script inline) : la CSP du site — default-src 'self'
// — bloque tout script inline. Sans JavaScript (aperçus WhatsApp, navigateurs
// bas de gamme), rien ne se passe et la page affiche les deux liens de secours.
(function () {
  var ua = navigator.userAgent || '';
  var isIOS =
    /iPhone|iPad|iPod/i.test(ua) ||
    // iPadOS 13+ se présente comme un Mac, mais avec un écran tactile.
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var isAndroid = /Android/i.test(ua);
  if (isIOS) {
    window.location.replace('https://apps.apple.com/app/id1128659292');
  } else if (isAndroid) {
    window.location.replace(
      'https://play.google.com/store/apps/details?id=com.karatou.android'
    );
  }
  // Autre plateforme (ordinateur, détection impossible) : on reste sur la page.
})();
