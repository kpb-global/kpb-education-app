# Réponses consoles

> **Vérifié contre l'artefact `2.2.0 (53)`** — archive iOS téléversée le
> 04/09/2026 à 10h21, AAB Android du run CI 33781909005. Vérification précédente :
> `2.1.0 (49)`, le 25/08/2026.
>
> **Le numéro de build n'est PAS dans le titre**, et c'est délibéré. Ce fichier
> s'appelait « — build 49 » et servait encore de référence quatre numéros plus
> tard, alors que trois de ses six points ouverts s'étaient résolus entre-temps.
> Un titre figé sur une build fait vieillir le document en silence ; un en-tête
> « vérifié contre » se voit périmé du premier coup d'œil. Même correction que
> `mobile-store-submission-contract.md`.
>
> **À quoi sert cette fiche.** `docs/STORE_READINESS.md` est l'analyse ; celle-ci
> est la **feuille à cocher**, dans l'ordre où chaque console pose ses questions.
> Chaque réponse porte, en une ligne, la **preuve vérifiée dans le code**. Quand
> une case n'est pas déductible du dépôt, elle est marquée **⚠️ À TRANCHER** et
> regroupée en tête — ne rien y deviner.
>
> **Certaines réponses dépendent de l'ARTEFACT, pas du dépôt** — « la clé PostHog
> est-elle dans le binaire ? » en est l'exemple type. Elles se revérifient à
> chaque build, et l'en-tête ci-dessus dit contre laquelle.
>
> **Entité (les deux consoles, à l'identique) :** l'éditeur et responsable du
> traitement est **KPB Global L.L.C-FZ**, zone franche Meydan (Dubaï, EAU),
> licence **2537631.01**, siège Meydan Grandstand 6th floor, Meydan Road, Nad Al
> Sheba, Dubaï. **KPB Education est un service de cette société, pas une entité.**
> Régime : décret-loi fédéral EAU n° 45/2021, autorité UAE Data Office. Transferts
> analysés **EAU → US** (sous-traitants US), hébergement **UE** (voir §Régions).
> C'est l'entité que porte la politique liée à la fiche — les deux doivent
> coïncider, sinon rejet « declaration inconsistent with privacy policy ».

---

## 0. ⚠️ À TRANCHER AVANT DE SOUMETTRE (3 points)

Trois des six points de la vérification du 25/08 se sont **résolus** ; ils sont
consignés en §0bis avec leur preuve, parce qu'un point retiré sans trace se
rouvre tout seul à la revue suivante.

| # | Point | Décision requise | Comment trancher |
|---|---|---|---|
| 4 | **SDK d'attribution embarqué (iOS)** | Répondre juste si un formulaire demande « SDK tiers d'attribution/pub présent ? » | `GoogleAdsOnDeviceConversion 3.4.2` **est** dans le binaire (transitif via `firebase_analytics`, `ios/Podfile.lock:124`). **Aucun suivi** (ATT absent, `NSPrivacyTracking=false`) — mais le SDK est *présent*. Ne pas cocher « Used to Track », mais le lister si la liste des SDK est demandée. |
| 5 | **Régions d'hébergement** | Confirmé hors dépôt — recopier tel quel | Supabase **eu-west-3 (Paris)**, VPS **France** (Hostinger), Mautic même VPS. Non prouvable par le code (`STORE_READINESS.md` §1). |
| 6 | **Fichiers Success Lab (Apple : User Content → Documents)** | Yes **seulement si** Success Lab est ouvert en prod ; sinon No | Accès fermé côté serveur par défaut. Vérifier `/config/app` → `features.successLab` sur l'environnement servi au moment de la soumission. |

---

## 0bis. Points RÉSOLUS depuis le 25/08 (ne pas les rouvrir sans preuve contraire)

| # | Point | Résolution, vérifiée sur l'artefact `2.2.0 (53)` |
|---|---|---|
| 1 | Clé PostHog conditionnelle au build | **RÉSOLU — et la réponse s'INVERSE.** La 49 et la 50 partaient sans clé ; la 53 la porte. Vérifié : `strings App.framework/App \| grep -c '^phc_'` → **1** (la 50 rendait 0). Le préflight iOS refuse désormais une clé vide, courte ou sans préfixe `phc_`, et le job AAB applique les mêmes trois règles **avant** de construire. → **PostHog DOIT être déclaré** : analytique produit + enregistrement de session masqué. |
| 2 | AD_ID sur l'AAB réel | **RÉSOLU.** Manifeste **fusionné** du bundle livré : permission absente. Vérifié en dépaquetant `base/manifest/AndroidManifest.xml` de l'AAB téléversé, et par `preflight-android-aab.sh` qui échoue si elle revient. ⚠️ **La déclaration Play, elle, disait encore le contraire** — la corriger réactive les erreurs bloquantes que quelqu'un avait désactivées. |
| 3 | Suppression de compte incomplète | **RÉSOLU.** `deleteMe` fait désormais 499 lignes et 38 `deleteMany`, et traite nommément `counsellorReview`, le registre ambassadeur, le référral et le contact Mautic. Les tables récentes (`EefInterest`, `PremiumWaitlistEntry`) suivent en `onDelete: Cascade` sur `userProfile.delete`. → « **≤ 30 jours** » redevient une réponse exacte. |

---

## 0ter. NOUVEAU depuis la 49 — à ne pas oublier dans les formulaires

| Changement | Effet sur les déclarations |
|---|---|
| **Mesure d'audience passée d'opt-in à ACTIVE PAR DÉFAUT** (revue du build 49, point 6) | La réponse Play « Requis / l'utilisateur peut choisir » **reste « peut choisir »** : le refus explicite existe, fonctionne et est conservé (`app_controller.dart`, verrouillé par `analytics_consent_test.dart`). Mais la collecte démarre **sans geste préalable**, et c'est annoncé dans les CGU (clause « Mesure d'audience »). Ne pas décrire un opt-in. |
| **Liste d'attente Karatou Premium** (en ligne depuis le 03/09) | Nouvelle collecte : identifiant de compte, horodatage, version **et langue** du texte de consentement. Se rattache à « Activité dans l'application → Autres actions » + l'ID utilisateur déjà déclaré. **Aucune donnée financière** : inscription gratuite, sans prix ni moyen de paiement (`premium_screen.dart`, garde exécutable dans `premium_waitlist_consent_version_test.dart`). |
| **Déclaration d'intérêt « Études en France »** (vitrine allumée le 30/08) | Même rattachement. Stocke niveau, filières, horodatage et version de consentement. Écriture réservée aux comptes étudiants. |
| **30 bourses servies au lieu de 10** | Aucun effet sur les déclarations : données de catalogue publiques, aucune donnée personnelle. |

---

## 1. Google Play — Data Safety

### 1.1 Portée
- **L'app collecte-t-elle / partage-t-elle des données ?** **Oui (collecte).**
- **Partage (« shared ») :** les transferts vers sous-traitants (Groq, Firebase,
  Supabase, PostHog, Resend, Mautic, PayDunya, CinetPay) = **collecte**, PAS
  « partage ». **Deux exceptions à cocher « Partagée » :**
  - **OneSignal** — reçoit l'**ID utilisateur** (UUID de profil) + **4 étiquettes**
    de ciblage. Vérifié : `onesignal_service.dart:80` (`OneSignal.login`), `:85`
    (`addTags`) ; étiquettes = `account_type, level, target_country, locale`
    (`app_controller.dart:1918`). **L'e-mail ne part PAS** (`onesignal_service.dart:73`).
  - **Service de reconnaissance vocale (Apple/Google)** — reçoit l'audio *seulement*
    si le local échoue **et** que l'utilisateur accepte (voir §Audio). À nommer en
    politique quoi qu'il arrive.
- **Toutes les données chiffrées en transit ?** **Oui** — API prod `https://`
  (`app_config.dart:250`), ATS iOS `NSAllowsArbitraryLoads=false`, aucun
  `usesCleartextTraffic` Android.
- **Suppression possible ?** **Oui — en app + URL** (voir §4).
- **Identifiant publicitaire utilisé ?** **NON.** Vérifié : AD_ID retiré du
  manifeste (`tools:node="remove"`), `google_analytics_adid_collection_enabled=false`,
  `QUERY_ALL_PACKAGES` absent. **Reconfirmé sur l'AAB signé de la 53** : permission
  absente du manifeste fusionné. Si la Play Console affiche un avertissement
  d'incohérence, c'est la **déclaration** qu'il faut corriger, pas l'app.

### 1.2 Types de données (collecté / partagé / requis-ou-optionnel / finalité)

| Type Play | Collecté | Partagé | Requis / Choix | Finalité | Preuve |
|---|---|---|---|---|---|
| Infos perso — **Nom** | Oui | Non | **Requis** | Fonctionnalité, Compte | `app_controller.dart:1997`, validateur `_req` |
| Infos perso — **E-mail** | Oui | **Non** | **Requis** | Fonctionnalité | e-mail retiré d'OneSignal (`onesignal_service.dart:73`) |
| Infos perso — **Téléphone** | Oui | Non | **Optionnel** | Fonctionnalité | aucun validateur (`onboarding_screen.dart:396-398`) |
| Infos perso — **ID utilisateur** | Oui | **Oui (OneSignal)** | **Requis — non coupable** | Fonctionnalité, Analyses | `OneSignal.login(profile.id)` ; hors interrupteur analyse |
| Infos perso — **Autres** (date de naissance, nom+contact tuteur) | Oui | Non | Requis si mineur déclaré | Contrôle d'âge, consentement tuteur | `schema.prisma:388-390` |
| Infos financières | **Non** | — | — | — | aucun moyen de paiement, aucun SDK d'achat |
| Messages — **In-app (dossiers)** | Oui | Non | Requis pour la fonction | Fonctionnalité | tunnel `case_tunnel_flow.dart:357` |
| Messages — **Autres (coach IA → Groq)** | Oui | Non (aucun ID transmis) | **Optionnel — consentement explicite** | Fonctionnalité | `AiConsentGuard` ; pas de nom dans l'invite |
| Photos | Oui | Non | **Optionnel** | Fonctionnalité | avatar seul, sans EXIF |
| Fichiers & docs | ⚠️ **Point 6** | Non | Optionnel | Fonctionnalité | dépend de l'ouverture de Success Lab — vérifier `/config/app` |
| **Audio — enregistrements vocaux** | **Non** | — | — | — | on-device + accord explicite ; aucun octet chez KPB |
| Activité — **Interactions** | Oui | Non | **Peut choisir** — active par défaut, refus honoré | Analyses | opt-out réel (`analytics_service.dart:144`) ; défaut changé en 50, annoncé aux CGU |
| Activité — **Historique de recherche** | Oui | Non | **Peut choisir** — même interrupteur | Analyses | terme en clair vers Firebase **et PostHog** (`:559`) |
| Activité — **Autres actions** (4 étiquettes OneSignal) | Oui | **Oui (OneSignal)** | **Requis — non coupable** | Fonctionnalité (+ perso.) | `addTags` (`onesignal_service.dart:85`) |
| Perf — **Journaux de plantage** | Oui | Non | **Peut choisir** — active par défaut | Stabilité | opt-out réel + purge (`crashlytics_observability.dart:52,59`) ; dSYM envoyés depuis la 52, donc plantages symbolisés |
| Perf — **Diagnostics** | Oui | Non | **Peut choisir** — même interrupteur | Stabilité | idem |
| Activité — **Autres actions** (listes d'intérêt : Premium, Études en France) | Oui | Non | **Peut choisir** — geste explicite | Fonctionnalité | `PremiumWaitlistEntry` / `EefInterest` : id de compte, horodatage serveur, version **et langue** du consentement. Aucune donnée financière. |
| **Identifiants d'appareil** | Oui | **Oui (OneSignal)** | **Requis** | Analyses, Push | OneSignal init inconditionnel ; ID Firebase suit l'interrupteur |

> **Requis vs « l'utilisateur peut choisir » — ne pas uniformiser.** Nom/E-mail =
> *Requis* ; Téléphone = *Optionnel* ; lignes analytiques + diagnostics = *peut
> choisir* ; ID utilisateur / étiquettes OneSignal / ID appareil = *Requis*. Une
> fiche « tout optionnel » ou « tout requis » est fausse.
>
> **Attention au sens de « peut choisir » pour l'analytique.** Depuis la 50, la
> mesure démarre **sans geste préalable** et l'utilisateur peut la couper ensuite.
> La case Play reste « l'utilisateur peut choisir » — le refus existe, fonctionne
> et est conservé — mais ne décrivez nulle part un opt-in : ce serait faux, et le
> texte des CGU (clause « Mesure d'audience ») dit l'inverse.
>
> **Traitement éphémère : Non** partout (backend + consoles tierces persistent).
>
> **NE PAS cocher :** Localisation (aucun appel géo ; chaîne iOS = module OneSignal
> lié jamais appelé) · Achats intégrés (CTA WhatsApp, aucun SDK) · aucun type
> supplémentaire pour l'embed YouTube (l'IP n'est pas un type déclarable Play).

---

## 2. Apple — App Privacy (« nutrition labels »)

- **Suivi (Tracking) : Non** partout. Vérifié : aucun `NSUserTrackingUsageDescription`,
  pas d'ATT, `PrivacyInfo.xcprivacy` `NSPrivacyTracking=false`. ⚠️ **Point 4** :
  `GoogleAdsOnDeviceConversion` est bundlé (transitif) mais non utilisé pour du
  suivi — ne change pas la réponse « Tracking : Non », mais à mentionner si la
  liste des SDK est demandée.

| Type Apple | Collecté | Lié | Suivi | Finalité | Preuve |
|---|---|---|---|---|---|
| Contact — **Nom, E-mail** | Oui | Oui | Non | Fonctionnalité, Compte | requis à l'inscription |
| Contact — **Téléphone (+ WhatsApp)** | Oui | Oui | Non | Fonctionnalité | optionnel |
| Contact — **Autres (nom+contact tuteur)** | Oui | Oui | Non | Fonctionnalité (mineur) | coordonnées d'un tiers, `schema.prisma:388-390` |
| Sensibles | **Non** | — | — | — | aucun champ sensible au modèle |
| Contenu — **Photos** (avatar) | Oui | Oui | Non | Fonctionnalité | sans EXIF/GPS |
| Contenu — **Support (messages dossier)** | Oui | Oui | Non | Fonctionnalité | tunnel |
| Contenu — **Autres (coach IA → Groq)** | Oui | Oui | Non | Fonctionnalité | derrière consentement ; aucun ID chez Groq |
| Contenu — **Audio** | **Non** | — | — | — | on-device + accord explicite (voir §Audio) |
| Contenu — **Autres (docs dossier)** | ⚠️ **Point 6** | — | — | — | Yes seulement si Success Lab est ouvert sur l'environnement servi — vérifier `/config/app` au moment de la soumission |
| Identifiants — **ID utilisateur** | Oui | Oui | Non | Fonctionnalité, Analyses | OneSignal + PostHog `identify` — PostHog **actif** depuis la 52 |
| Identifiants — **ID appareil** | Oui | Oui | Non | Fonctionnalité, Analyses | ID instance Firebase + abonnement OneSignal |
| Usage — **Interaction, Historique recherche** | Oui | Oui | Non | Analyses, Fonctionnalité | désactivable |
| Diagnostics — **Crash, Performance** | Oui | **Non (non lié)** | Non | Stabilité | aucun `setUserIdentifier` ; désactivable |
| Santé, Finances, Localisation, Navigation, Contacts | **Non** | — | — | — | absence exhaustive vérifiée |

> **Session replay (PostHog) — À DÉCLARER, ce n'est plus conditionnel.** L'archive
> `2.2.0 (53)` **porte la clé** : `strings App.framework/App | grep -c '^phc_'` → 1,
> là où la 50 rendait 0. Déclarer sous *Usage Data → Product Interaction*, **Lié
> Oui, Suivi Non**. Le contenu est masqué à la capture (`main.dart`,
> `maskAllTexts` + `maskAllImages`) → **pas** « User Content ». Désactivable par
> le même interrupteur que le reste de la mesure d'audience.
>
> Le préflight iOS refuse maintenant une clé vide, trop courte ou sans préfixe
> `phc_`, et le job AAB applique les trois mêmes règles avant de construire : une
> build ne peut plus repartir muette en silence comme la 50.
>
> **Contenu tiers embarqué (YouTube/Google) :** le lecteur transmet IP + user-agent
> à Google à l'ouverture → déclarer au titre des partenaires tiers (Usage Data /
> Identifiers via partenaire). Le budget auto-déclaré = App Functionality, **pas**
> « Financial Info ».

---

## 3. Classification d'âge (Apple ASC + IARC Play)

| Item | Réponse | Preuve |
|---|---|---|
| Âge contractuel minimum | **16** | CGU `conditions.html:29` ; in-app `app_translations.dart:704` |
| Accès web illimité | **Non** | lecteur YouTube non navigable (`IgnorePointer`, `controls:0`) ; liens sortants en `externalApplication` |
| Interaction entre utilisateurs | **Non** (vérifié sur la 53) | Community derrière `!mvpOnly` défaut true ; forum 404 sous `MvpGuard` |
| Contenu généré par l'utilisateur | **Oui — visible staff, jamais public** | 3 écritures, aucune publique |
| Signalement de contenu / blocage | **Signalement IA : Oui. Blocage : N/A** | `ai_content_report_sheet.dart` → `POST /cases` |
| IA générative, texte libre | **Oui — 2 surfaces** | coach + test d'orientation → Groq |
| Localisation | **Non** | aucun plugin géo |
| Jeux d'argent | **Non** | absence exhaustive |
| Achats intégrés (IARC) | **Non** | CTA WhatsApp, aucun SDK. PayDunya/CinetPay = §processeurs, jamais ici |
| Contenu « mature » éditorial | **NON PROUVÉ** | dépend de la revue éditoriale, pas du binaire |

> **Recommandé :** saisir ces réponses et laisser chaque questionnaire calculer la
> tranche. **Ne pas** reporter l'ancien couple « Apple 12+ / Google Teen » (dérivé
> d'un module communautaire qui ne ship pas et sans les 2 surfaces d'IA).

---

## 4. Suppression de compte & export (exigence store)

| Champ console | Réponse | Preuve |
|---|---|---|
| Play → *Suppression des données possible ?* | **Oui — en app + URL web** | `DELETE /profiles/me` (`profiles.controller.ts:117`) |
| Play / Apple → **URL de suppression de compte** | `https://kpbeducation.cloud/suppression-compte.html` | page + routeur Traefik + sonde uptime |
| Export proposé | **Oui — en app, JSON partagé depuis l'app** (pas une archive téléchargeable) | `GET /profiles/me/export` (`profiles.controller.ts:110`) |
| Suppression immédiate | **Oui dans le code** (hard-delete Supabase puis purge locale) | `profiles.controller.ts:115` |

> ✅ **Point 3 — RÉSOLU.** Il était encore ouvert le 25/08 : `CounsellorReview`
> (nom civil), le registre ambassadeur et le contact Mautic survivaient
> indéfiniment, et « ≤ 30 jours » était donc faux pour ces utilisateurs.
>
> `deleteMe` fait aujourd'hui **499 lignes et 38 `deleteMany`**, et traite
> nommément `counsellorReview`, l'ambassadeur, le référral et Mautic — ce dernier
> sans jamais faire de lookup quand le contact n'a jamais été synchronisé, la
> requête elle-même divulguant l'adresse au sous-traitant (revue P1 #246). Les
> tables plus récentes (`EefInterest`, `PremiumWaitlistEntry`) tombent en
> `onDelete: Cascade` sur `userProfile.delete({ where: { id } })`.
>
> → **« ≤ 30 jours » est désormais une réponse exacte**, et « immédiat » l'est pour
> le compte et les données actives. Vérifié sur le code servi en production
> (`90264244a0e0`).
>
> **Fenêtre JWT inévitable :** un access-token déjà émis reste valide jusqu'à son
> `exp` après suppression Supabase — ne pas présenter la suppression comme une
> révocation rétroactive des JWT. **Survivances de purge** (à corriger, pas à
> masquer par le libellé) : `CounsellorReview` (nom civil), registre ambassadeur,
> contact Mautic — voir `STORE_READINESS.md` §6.

---

## 5. Régions & sous-traitants (recopier au formulaire « destinataires »)

Hébergement **UE** ; responsable **EAU** ; sous-traitants **US** nommés à part — les
trois se cumulent.

| Sous-traitant | Région | Reçoit | Finalité | Partagé (Play) |
|---|---|---|---|---|
| Backend NestJS/Postgres | **France** (VPS) | toutes les données app | Fonctionnalité | collecte |
| Supabase Auth | **eu-west-3 (Paris)** | e-mail, OAuth Google, jetons | Authentification | collecte |
| Groq (LLM) | **US** | profil pseudonymisé (sans nom), budget en tranche, messages | Réponses IA | collecte |
| **OneSignal** | US | **ID utilisateur + 4 étiquettes** (pas d'e-mail) | Push + segmentation | **PARTAGÉ** |
| Firebase Analytics | US | ID instance, événements, **terme de recherche** | Analyses | collecte |
| PostHog | **US** | événements, replay masqué, UUID | Analyses, replay | collecte — **actif si l'archive porte la clé** (point 1) |
| Firebase Crashlytics | US | traces, modèle, OS (aucun `setUserIdentifier`) | Stabilité | collecte |
| **Reconnaissance vocale Apple/Google** | US/global | audio dicté (si repli accepté) ; texte seul rendu | Dictée | **destinataire** — ⚠️ nommer en politique |
| Resend | **US** | e-mail + objet + corps | E-mail transactionnel | collecte |
| Mautic (auto-hébergé) | France (VPS) | 7 champs, **après opt-in seulement** | Newsletter bourses | collecte |
| CinetPay | (région prestataire) | e-mail, téléphone, nom | Accompagnement payant (**toujours inatteignable** : aucun tunnel d'achat dans l'app) | collecte |
| PayDunya | (région prestataire) | facture seule, **aucune donnée client** | idem | collecte |
| **YouTube IFrame (Google)** | US/global | **IP + user-agent + id vidéo** | Lecture vidéo / vignettes | pseudonyme (IP) |
| **WhatsApp / Meta** | US/global | URL `wa.me` (contexte catalogue ; **ni nom ni e-mail**) + ce que l'étudiant envoie | Remise externe | n/a (externe) — **pas un sous-traitant** |

---

_Établi le 2026-08-25. Base : `docs/STORE_READINESS.md` (18/08) + revérification
indépendante des fichiers primaires (7 questions, 0 contradiction) + `test/release/`
verte (46 tests). Tenir à jour à chaque nouveau SDK / flux / sous-traitant._
