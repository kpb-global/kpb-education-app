# Réponses consoles — build 49 (à recopier au dépôt)

> **À quoi sert cette fiche.** `docs/STORE_READINESS.md` est l'analyse ; celle-ci
> est la **feuille à cocher**, dans l'ordre où chaque console pose ses questions.
> Chaque réponse porte, en une ligne, la **preuve vérifiée dans le code** le
> 2026-08-25 (revérification indépendante des fichiers primaires + suite
> `test/release/` verte). Quand une case n'est pas déductible du dépôt, elle est
> marquée **⚠️ À TRANCHER** et regroupée en tête — ne rien y deviner.
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

## 0. ⚠️ À TRANCHER AVANT DE SOUMETTRE (6 points)

| # | Point | Décision requise | Comment trancher |
|---|---|---|---|
| 1 | **Clé PostHog** | Déclarer *replay + analytique PostHog* **seulement si** le binaire 49 embarque une `POSTHOG_API_KEY` non vide | Décoder le `DART_DEFINES` de l'archive : `scripts/preflight-ios-archive.sh` le fait déjà en mémoire ; ou lire la valeur du secret CI utilisé pour la 49. Défaut compilé = **vide** (`app_config.dart:72-87`). Clé vide → **ne pas** déclarer PostHog. |
| 2 | **AD_ID sur l'AAB réel** | Confirmer que `com.google.android.gms.permission.AD_ID` est **absent du manifeste fusionné** | `scripts/preflight-android-aab.sh --aab <app-release.aab> --expected-cert-sha256 <SHA>` **échoue** si AD_ID revient (`:123`). Le manifeste *source* est correct (vérifié), seul le *fusionné* fait foi. |
| 3 | **Suppression : « immédiate » vs « sous 30 jours »** | Aligner le libellé | Le code supprime **immédiatement et en dur** (`profiles.controller.ts:115`), mais `web/public/suppression-compte.html:40` dit « supprimées sous 30 jours ». Un examinateur qui suit l'URL de suppression voit 30 jours. Choisir : cocher « immédiat » **et** corriger la page, ou déclarer une fenêtre de 30 j. |
| 4 | **SDK d'attribution embarqué (iOS)** | Répondre juste si un formulaire demande « SDK tiers d'attribution/pub présent ? » | `GoogleAdsOnDeviceConversion 3.4.2` **est** dans le binaire (transitif via `firebase_analytics`, `ios/Podfile.lock:124`). **Aucun suivi** (ATT absent, `NSPrivacyTracking=false`) — mais le SDK est *présent*. Le commentaire « no advertising SDK » de `PrivacyInfo.xcprivacy:5` est donc inexact sur ce qui *ship*. Ne pas cocher « Used to Track », mais lister le SDK si le formulaire demande la liste. |
| 5 | **Régions d'hébergement** | Confirmé hors dépôt — recopier tel quel | Supabase **eu-west-3 (Paris)**, VPS **France** (Hostinger), Mautic même VPS. Non prouvé par le code (`STORE_READINESS.md` §1) — vérifié console Supabase / whois. |
| 6 | **Fichiers Success Lab (Apple : User Content → Documents)** | Yes **seulement si** Success Lab est ouvert en prod ; sinon No | Défaut : accès fermé côté serveur (`live_scholarships_screen.dart` échoue fermé). En 49 masquée → **No**. |

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
  `QUERY_ALL_PACKAGES` absent. ⚠️ **Point 2** — reconfirmer sur l'AAB signé.

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
| Fichiers & docs | ⚠️ **Point 6** (No en 49) | Non | Optionnel | Fonctionnalité | envoi de pièces masqué en 49 |
| **Audio — enregistrements vocaux** | **Non** | — | — | — | on-device + accord explicite ; aucun octet chez KPB |
| Activité — **Interactions** | Oui | Non | **Optionnel** (interrupteur) | Analyses | opt-out réel (`analytics_service.dart:144`) |
| Activité — **Historique de recherche** | Oui | Non | **Optionnel** (même interrupteur) | Analyses | terme en clair vers Firebase+PostHog (`:559`) |
| Activité — **Autres actions** (4 étiquettes OneSignal) | Oui | **Oui (OneSignal)** | **Requis — non coupable** | Fonctionnalité (+ perso.) | `addTags` (`onesignal_service.dart:85`) |
| Perf — **Journaux de plantage** | Oui | Non | **FACULTATIVE** (interrupteur) | Stabilité | opt-out réel + purge (`crashlytics_observability.dart:52,59`) |
| Perf — **Diagnostics** | Oui | Non | **FACULTATIVE** (même interrupteur) | Stabilité | idem |
| **Identifiants d'appareil** | Oui | **Oui (OneSignal)** | **Requis** | Analyses, Push | OneSignal init inconditionnel ; ID Firebase suit l'interrupteur |

> **Requis vs optionnel — ne pas uniformiser.** Nom/E-mail = *Requis* ; Téléphone
> = *Optionnel* ; lignes analytiques + diagnostics = *Optionnel* (interrupteur
> réel) ; ID utilisateur / étiquettes OneSignal / ID appareil = *Requis*. Une fiche
> « tout optionnel » ou « tout requis » est fausse.
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
| Contenu — **Autres (docs dossier)** | ⚠️ **Point 6** | — | — | — | masqué en 49 ; Yes si Success Lab ouvert |
| Identifiants — **ID utilisateur** | Oui | Oui | Non | Fonctionnalité, Analyses | OneSignal + PostHog identify |
| Identifiants — **ID appareil** | Oui | Oui | Non | Fonctionnalité, Analyses | ID instance Firebase + abonnement OneSignal |
| Usage — **Interaction, Historique recherche** | Oui | Oui | Non | Analyses, Fonctionnalité | désactivable |
| Diagnostics — **Crash, Performance** | Oui | **Non (non lié)** | Non | Stabilité | aucun `setUserIdentifier` ; désactivable |
| Santé, Finances, Localisation, Navigation, Contacts | **Non** | — | — | — | absence exhaustive vérifiée |

> **Session replay (PostHog) :** ⚠️ **Point 1** — déclarer sous *Usage Data →
> Product Interaction*, Lié Oui, Suivi Non, **seulement si** la clé est posée.
> Contenu masqué (`main.dart` `maskAllTexts`+`maskAllImages`) → pas « User Content ».
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
| Interaction entre utilisateurs | **Non** (build 49) | Community derrière `!mvpOnly` défaut true ; forum 404 sous `MvpGuard` |
| Contenu généré par l'utilisateur | **Oui — visible staff, jamais public** | 3 écritures, aucune publique |
| Signalement de contenu / blocage | **Signalement IA : Oui. Blocage : N/A en 49** | `ai_content_report_sheet.dart` → `POST /cases` |
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

> ⚠️ **Point 3** : la page publique dit « supprimées **sous 30 jours** »
> (`suppression-compte.html:40`) alors que le code supprime **immédiatement**.
> Réconcilier avant de cocher « immédiat » à côté de cette URL.
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
| PostHog | **US** | événements, replay masqué, UUID | Analyses, replay | collecte — ⚠️ Point 1 |
| Firebase Crashlytics | US | traces, modèle, OS (aucun `setUserIdentifier`) | Stabilité | collecte |
| **Reconnaissance vocale Apple/Google** | US/global | audio dicté (si repli accepté) ; texte seul rendu | Dictée | **destinataire** — ⚠️ nommer en politique |
| Resend | **US** | e-mail + objet + corps | E-mail transactionnel | collecte |
| Mautic (auto-hébergé) | France (VPS) | 7 champs, **après opt-in seulement** | Newsletter bourses | collecte |
| CinetPay | (région prestataire) | e-mail, téléphone, nom | Accompagnement payant (inatteignable en 49) | collecte |
| PayDunya | (région prestataire) | facture seule, **aucune donnée client** | idem | collecte |
| **YouTube IFrame (Google)** | US/global | **IP + user-agent + id vidéo** | Lecture vidéo / vignettes | pseudonyme (IP) |
| **WhatsApp / Meta** | US/global | URL `wa.me` (contexte catalogue ; **ni nom ni e-mail**) + ce que l'étudiant envoie | Remise externe | n/a (externe) — **pas un sous-traitant** |

---

_Établi le 2026-08-25. Base : `docs/STORE_READINESS.md` (18/08) + revérification
indépendante des fichiers primaires (7 questions, 0 contradiction) + `test/release/`
verte (46 tests). Tenir à jour à chaque nouveau SDK / flux / sous-traitant._
