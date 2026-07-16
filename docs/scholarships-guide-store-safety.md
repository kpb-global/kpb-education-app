# Bourses et guide — règle produit pour les stores

## Décision

Le libellé **« En savoir plus » ne suffit pas** à rendre une redirection vers
Chariow conforme. Les stores évaluent la destination et le parcours complet,
pas seulement le texte du bouton.

Dans les builds distribués par l'App Store et Google Play, le bouton du guide
doit donc ouvrir une page éditoriale interne qui :

- présente le contenu et l'auteur du guide ;
- ne montre ni prix, ni promotion, ni code promo ;
- ne contient aucun bouton ou lien vers Chariow, WhatsApp ou une page web qui
  mène ensuite au paiement externe ;
- ne demande pas à l'utilisateur d'acheter le guide ailleurs.

Le paiement Chariow reste autorisé sur les canaux web/directs de KPB. Il ne
sera activé depuis une app store que si le canal, le pays et le programme du
store le permettent explicitement, via une configuration distante et un
kill-switch par plateforme/région.

## Notifications du guide

Les notifications envoyées aux utilisateurs des builds stores peuvent faire
découvrir un contenu éducatif gratuit dans l'app. Elles ne doivent pas pousser
chaque semaine un achat externe du guide ni contenir un prix ou un lien Chariow.

Si KPB choisit plus tard de vendre le guide directement dans l'app, la voie par
défaut est l'achat intégré Apple / Google Play Billing. Toute exception devra
être validée pour la plateforme, la région et le type d'app avant activation.

## Garde-fous d'implémentation

- `guideInfoEnabled`: affiche ou masque la page éditoriale interne.
- `guideExternalPurchaseEnabled`: `false` par défaut dans tous les builds stores.
- `guideExternalPurchaseUrl`: ignorée tant que le flag précédent est désactivé.
- Ciblage séparé par plateforme, pays du storefront et canal de distribution.
- Analytics distincts : vue de la page, lecture des sections, clic d'achat web.
- Test de release : aucune chaîne `10.000 FCFA`, `20.000 FCFA`, `Chariow`,
  `Acheter` ou URL de paiement ne doit apparaître dans le parcours store.

## Références officielles vérifiées le 16 juillet 2026

- Apple App Review Guidelines, sections 3.1.1 et 3.1.3 :
  https://developer.apple.com/app-store/review/guidelines/
- Apple External Link Account Entitlement pour les reader apps :
  https://developer.apple.com/support/reader-apps/
- Google Play Payments policy :
  https://support.google.com/googleplay/android-developer/answer/9858738
- Google Play, communication sur les offres externes :
  https://support.google.com/googleplay/android-developer/answer/10281818
