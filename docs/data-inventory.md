# Inventaire des données — dérivé du code

Source de vérité pour les destinataires que l’utilisateur accepte à
l’inscription. Chaque ligne cite le fichier qui **prouve** le flux. Les docs
existants ne font pas autorité : si ce fichier et le code divergent, c’est le
code qui gagne, et ce fichier doit être mis à jour.

Dernière lecture du dépôt : 2026-08-16 (lot 11).

## 1. Destinataires tiers (8 + paiements)

| Destinataire | Hôte / preuve | Région | Ce qui part | Finalité |
|---|---|---|---|---|
| **Groq** | `https://api.groq.com/openai/v1/chat/completions` — `backend/src/modules/ai/llm.service.ts` | États-Unis | Texte libre du coach ; faits de profil (niveau, pays, tranche de budget, domaine). Le nom civil n'est plus recopié dans l'invite (`tools.service.ts`, lot 11). Les quatre outils IA restent masqués (`KPB_AI_TOOLS_ENABLED=false`) jusqu'au déploiement couplé avec la build 49. | Réponses IA |
| **OneSignal** | `https://onesignal.com/api/v1/notifications` — `backend/src/modules/notifications/onesignal-sender.service.ts` ; SDK `lib/app/core/services/onesignal_service.dart` | États-Unis | Jeton push, `external id` = `UserProfile.id` | Notifications |
| **Firebase** (Analytics + Crashlytics) | `https://karatoupostbac-178213.firebaseio.com` — `lib/firebase_options.dart` ; init `lib/main.dart` | Google | Événements d’usage, termes de recherche, piles de crash, modèle / OS / version | Analytique, stabilité |
| **PostHog** | `https://us.i.posthog.com` — `lib/app/core/config/app_config.dart` | États-Unis | Événements, vues d’écran, UUID après login, replays **textes + images masqués** | Analytique, session replay |
| **Supabase** (auth) | `https://hijzqsljasbobjrjotjy.supabase.co` — `lib/app/core/config/app_config.dart` | (région projet — à confirmer) | E-mail, identité Google OAuth, jetons de session | Authentification |
| **Resend** | `https://api.resend.com/emails` — `backend/src/modules/notifications/campaign-mail.service.ts` | États-Unis | Adresse e-mail + contenu des campagnes | E-mails transactionnels / campagnes |
| **Mautic** | `$MAUTIC_BASE_URL` — `backend/src/modules/newsletter/mautic.service.ts` (pas d’hôte en dur : instance auto-hébergée) | VPS KPB | Contact newsletter (e-mail) si consentement | Newsletter bourses |
| **Backend KPB** (NestJS / Postgres) | `https://api.kpbeducation.cloud/api` — `lib/app/core/config/app_config.dart` | VPS Hostinger | Toutes les données d’app ci-dessous | Fonctionnement |

Paiements (hors liste historique des 8, mais présents dans le code) :

| Destinataire | Preuve | Ce qui part |
|---|---|---|
| **PayDunya** | `https://app.paydunya.com` — `backend/src/modules/payments/paydunya.adapter.ts` | Intentions de paiement |
| **CinetPay** | `https://api-checkout.cinetpay.com` — `backend/src/modules/payments/cinetpay.adapter.ts` | Intentions de paiement |

## 2. Données collectées (côté app)

| Donnée | Où elle naît | Où elle vit | Note |
|---|---|---|---|
| Nom, e-mail, téléphone, WhatsApp | Onboarding | Postgres ; e-mail aussi Supabase Auth | Le nom n’est **pas** envoyé à Groq (coach + outils, lot 11). Les outils IA restent masqués jusqu’au déploiement couplé 49 |
| Date de naissance | Onboarding (étudiants) | Postgres + snapshot local | Plancher 16 ans (lot 9) ; tuteur si &lt; 18 |
| Nom / contact / consentement du tuteur | Onboarding (mineurs déclarés) | Postgres | Contact tuteur non persisté sur l’appareil |
| Photo de profil | Profil | Stockage backend, scan antivirus, pas d’URL publique | Caméra / photothèque |
| Documents de dossier | WhatsApp (pas l’app) | — | `KPB_DOCUMENT_UPLOAD_ENABLED=false` (M2) : l’app n’envoie aucun fichier. Les pièces (passeport, relevés…) passent par WhatsApp vers le conseiller. Fichiers d’anciennes builds encore en stockage. |
| Messages de dossier | In-app | Postgres | |
| Textes soumis au coach | In-app | Postgres + Groq (US) | Texte libre |
| Dictée vocale | Demande d’accompagnement | Convertie en texte localement puis message | `NSMicrophoneUsageDescription` + `RECORD_AUDIO` |
| Profil académique, budget | Onboarding | Postgres + local | Budget → Groq en **tranche** seulement |
| Jeton push | Runtime | OneSignal | |
| Analytique / replay / crash | Runtime | Firebase + PostHog + Crashlytics | Opt-out : Profil → « Analyse d’usage » |

## 3. Permissions (ce que l’OS affiche)

### Android (`android/app/src/main/AndroidManifest.xml`)

- `INTERNET`, `ACCESS_NETWORK_STATE` — API, Firebase
- `POST_NOTIFICATIONS` — OneSignal (Android 13+)
- `USE_BIOMETRIC` — verrouillage local
- `RECORD_AUDIO` — dictée

### iOS (`ios/Runner/Info.plist`)

- `NSCameraUsageDescription` — pièce jointe de dossier **et** photo de profil
- `NSPhotoLibraryUsageDescription` — même usages
- `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` — dictée
- `NSFaceIDUsageDescription` — verrouillage
- `NSLocationWhenInUseUsageDescription` — déclarée parce que le SDK OneSignal référence CoreLocation ; **jamais demandée ni utilisée**

## 4. Ce que ce fichier n’est pas

- L’identité juridique de l’entité (forme, adresse, pays, autorité) est
  introuvable dans le dépôt. `TODO(owner-identity)` — échéance 28/08/2026.
- La région exacte du projet Supabase et du VPS reste à confirmer par le
  propriétaire (déjà noté dans `STORE_READINESS.md`).
