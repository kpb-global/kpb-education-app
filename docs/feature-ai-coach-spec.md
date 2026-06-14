# Spec technique — Coach KPB (Conseiller IA, Groq)

> Différenciateur n°1 pour « best study-abroad app in Africa ».
> Conseiller IA 24/7, en français, ancré dans le profil de l'étudiant, avec
> escalade vers un conseiller humain (dossiers existants). S'appuie sur la
> décision projet « keep Groq for AI ».

## 1. Objectif & périmètre

**Problème** : un étudiant africain n'a pas accès à un conseiller à toute heure ;
l'information existe (l'app l'a déjà) mais l'**exécution** et la **confiance**
manquent.

**Solution** : un chat IA qui (a) répond aux questions d'orientation/bourses/visa
en contexte, (b) aide à *exécuter* (lettre de motivation, checklist documents),
(c) escalade vers un humain quand c'est pertinent.

**Principe d'ancrage (anti-hallucination)** : l'IA ne doit JAMAIS inventer de
bourses, deadlines, montants ou exigences visa. Elle raisonne uniquement sur le
contexte fourni par le backend (profil, résultats d'orientation, bourses
sauvegardées, dossiers) et renvoie vers les écrans existants pour les données
factuelles.

### Phasage
- **MVP (P0)** : CRUD conversations + réponse **streamée token-par-token (SSE)** ancrée sur le profil ; écran chat ; **bouton Coach flottant global** + entrée accueil.
- **P1** : prompts suggérés, garde-fous renforcés, **repli automatique de modèle** quand le quota mensuel est atteint.
- **P2** : *tool calling* (recommander bourses, ouvrir un dossier, lancer le test d'orientation, estimer un budget) → l'IA déclenche des actions rendues en cartes/boutons.
- **P3** : escalade humaine (créer un dossier pré-rempli depuis la conversation), entrée vocale, multilingue (AR/PT/SW), nudges proactifs.

## 2. Architecture

```
Flutter (CoachScreen + CoachController, GetX)
   │  HTTP (dio) — JWT StudentAuthGuard
   ▼
NestJS  CoachController → CoachService → GroqService → api.groq.com (OpenAI-compatible)
                              │
                              ├─ assemble le contexte (ProfilesService, OrientationService,
                              │   SavedItemsService, CasesService) — lecture SCOPÉE userId
                              └─ persiste Conversation/Message (Prisma) + comptage tokens
```

- La clé `GROQ_API_KEY` reste **côté serveur uniquement** (jamais dans le client).
- Streaming : **SSE** (`text/event-stream`) en P1. MVP = réponse complète JSON.
  *(Alternative : réutiliser le `CaseMessagingGateway` socket.io ; SSE est plus
  simple pour un flux requête→réponse et évite d'élargir le gateway.)*

## 3. Modèle de données (Prisma)

```prisma
model CoachConversation {
  id          String         @id @default(cuid())
  userId      String         // ⚠️ scope obligatoire (leçon IDOR cette session)
  title       String?        // auto-généré depuis le 1er message
  createdAt   DateTime       @default(now())
  updatedAt   DateTime       @updatedAt
  messages    CoachMessage[]
  userProfile UserProfile    @relation(fields: [userId], references: [id])

  @@index([userId])
}

model CoachMessage {
  id             String            @id @default(cuid())
  conversationId String
  role           String            // 'user' | 'assistant' | 'tool'
  content        String            @db.Text
  toolName       String?           // P2 : nom de l'action appelée
  toolPayload    Json?             // P2 : args/résultat structuré
  tokensIn       Int?              // comptage coût
  tokensOut      Int?
  createdAt      DateTime          @default(now())
  conversation   CoachConversation @relation(fields: [conversationId], references: [id], onDelete: Cascade)

  @@index([conversationId])
}
```
+ relation inverse `coachConversations CoachConversation[]` sur `UserProfile`.
Migration : `npx prisma migrate dev --name add_coach_conversations`
(SQL validable hors-ligne comme on l'a fait pour `persist_profile_arrays_and_case_seq`).

## 4. Backend — module `coach`

`backend/src/modules/coach/` :
- `coach.module.ts`
- `coach.controller.ts` (`@UseGuards(StudentAuthGuard)`)
- `coach.service.ts`
- `llm.service.ts` (client provider-agnostic Groq/OpenRouter — voir §5)
- `dto/create-conversation.dto.ts`, `dto/send-coach-message.dto.ts`
- `coach.service.spec.ts`

### Endpoints (tous scopés `req.studentUser.id`)
| Méthode | Route | Rôle |
|---|---|---|
| `GET` | `/coach/conversations` | Liste des conversations de l'utilisateur |
| `POST` | `/coach/conversations` | Crée une conversation |
| `GET` | `/coach/conversations/:id` | Messages d'une conversation (404 si pas propriétaire) |
| `POST` | `/coach/conversations/:id/messages` | Envoie un message → réponse IA (SSE en P1, JSON en MVP) |
| `DELETE` | `/coach/conversations/:id` | Supprime (deleteMany scopé userId) |

**Règle de sécurité** : reprendre exactement le pattern corrigé dans
`cases.service.ts` — `requireConversation(id, ownerUserId)` qui lève
`NotFoundException` si `conversation.userId !== ownerUserId`. Jamais de lookup
par `id` seul.

### DTOs (class-validator — le `ValidationPipe` global est déjà actif)
```ts
export class SendCoachMessageDto {
  @IsString() @MaxLength(4000) message!: string;
}
export class CreateConversationDto {
  @IsOptional() @IsString() @MaxLength(4000) firstMessage?: string;
}
```

### CoachService — assemblage du contexte
```
buildContext(userId): {
  profile: { niveau, niveauCible, langues, pays cibles, filières, budget }
  orientation: top 3 filières + scores (latestOrientationSession)
  savedScholarships: [{ nom, pays, deadline, financement }]
  activeCases: [{ ref, statut, prochaine étape }]
}
```
Injecté dans le **system prompt** (FR). Historique tronqué (N derniers messages +
résumé) pour borner les tokens.

### Garde-fous (system prompt)
- Persona : « Coach KPB », bienveillant, concret, en français (ou langue du profil).
- Périmètre : études à l'étranger uniquement ; refuse poliment le hors-sujet.
- Ancrage : ne jamais inventer de données factuelles ; pour les chiffres/bourses/visa,
  s'appuyer sur le contexte fourni et renvoyer vers l'écran concerné.
- Escalade : si la demande dépasse l'IA (cas complexe, paiement, litige),
  proposer « Parler à un conseiller KPB » (P3 : ouvre un dossier pré-rempli).

### Modèle économique : GRATUIT avec limites (décidé)
- **Cap quotidien** par utilisateur (ex. 20–30 messages/jour ; configurable via env).
- **Budget mensuel global de tokens** : tant qu'il n'est pas atteint → modèle
  premium (Groq `llama-3.3-70b-versatile`). Une fois atteint → **repli
  automatique** vers un modèle gratuit/meilleur rapport qualité-prix (OpenRouter)
  au lieu de couper le service (voir §5). Le tiers payant viendra plus tard.
- `temperature: 0.4`, `max_tokens` borné, timeout ~30s, retry/backoff 1×.
- Comptage `tokensIn/Out` persisté → pilotage du budget mensuel + base du futur
  quota par offre payante.
- Rate-limit + compteur de budget en mémoire (réutiliser le pattern de
  `student-auth.service`) ; **Redis recommandé en prod multi-instance** (sinon
  le budget/cap n'est pas partagé entre instances).

## 5. Couche LLM — agnostique du fournisseur (`llm.service.ts`)

Groq **et** OpenRouter exposent une API **compatible OpenAI** → un seul client,
configurable par env. Cela permet : Groq `llama-3.3-70b-versatile` en primaire,
et **repli OpenRouter** (modèle gratuit ou meilleur rapport qualité-prix) quand le
budget mensuel est atteint ou en attendant le tiers payant.

```
LlmProvider = { baseUrl, apiKey, model }
PRIMARY  = { https://api.groq.com/openai/v1, GROQ_API_KEY,  GROQ_MODEL=llama-3.3-70b-versatile }
FALLBACK = { https://openrouter.ai/api/v1,   OPENROUTER_API_KEY, OPENROUTER_MODEL=<free/best-value> }
```
- Sélection : si `budgetMensuel.restant() > seuil` → PRIMARY, sinon FALLBACK.
  Sur erreur/timeout du PRIMARY → tenter FALLBACK une fois avant de renoncer.
- Env : `GROQ_API_KEY`, `GROQ_MODEL`, `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`,
  `LLM_MONTHLY_TOKEN_BUDGET`. **Vérifier la dispo réelle des modèles à l'implémentation.**
  *(OpenRouter exige souvent les en-têtes `HTTP-Referer` / `X-Title`.)*
- Streaming : `stream: true` → SSE ; relayer chaque delta au client via SSE NestJS
  (`@Sse()` ou `res.write('data: ...\n\n')`). **Inclus dès le MVP.**
- Tool calling (P2) : champ `tools` (format OpenAI) ; gérer `tool_calls` →
  exécuter côté backend (scopé userId) → renvoyer le résultat au modèle.
  *(À vérifier : support tool-calling du modèle de repli choisi.)*
- Robustesse : si PRIMARY et FALLBACK échouent → message de repli FR + suggestion
  de réessayer / contacter un conseiller (ne jamais crasher l'écran).
- Sécurité : les clés ne transitent **jamais** vers le client.

## 6. Flutter (mobile)

- **Modèles** (`app_models.dart`) : `CoachConversation`, `CoachMessage`.
- **Repository** (`app_api_client.dart`) : `listConversations`, `createConversation`,
  `getConversation`, `sendCoachMessage` (P1 : flux via `dio` `ResponseType.stream` /
  parsing SSE), `deleteConversation`. Codec dédié (`coach_api_codec.dart`).
- **Controller** (`CoachController`, GetX) : état conversations + messages, append
  des tokens en streaming, gestion offline/erreur.
- **Écran** `lib/app/features/coach/coach_screen.dart` (lumineux & épuré, réutilise
  `KpbPressable`, tokens UI) :
  - Bulles user/assistant, indicateur de frappe animé pendant le streaming.
  - **Prompts suggérés** (chips) au démarrage : « Quelles bourses pour mon profil ? »,
    « Aide-moi pour ma lettre de motivation », « Étapes visa Canada ».
  - Barre d'entrée désactivée hors-ligne (`ConnectivityService`) ; conversations
    passées consultables hors-ligne (cache Hive).
  - CTA « Parler à un conseiller KPB » (escalade P3).
- **Points d'entrée (décidé — meilleur UX)** : **5 onglets conservés** + un
  **bouton « Coach » flottant persistant** (au-dessus de la nav, visible sur tout
  l'app via le `AppShell`) qui ouvre le chat ; + une carte/CTA sur l'accueil. Pas
  de 6e onglet (barre de nav surchargée). Le bouton flottant rend le Coach
  omniprésent → fort levier de rétention.
- **i18n** : clés FR/EN dans `app_translations.dart`.
- **Analytics** : événements `coach_opened`, `coach_message_sent`,
  `coach_escalated` (via `analytics_event_contract`).

## 7. Confidentialité & conformité
- Consentement déjà géré à l'onboarding (RGPD) — ajouter une mention « tes
  échanges avec le Coach sont stockés pour améliorer ton suivi ».
- Rétention : permettre la suppression d'une conversation (endpoint DELETE).
- Pas de PII sensible inutile dans les logs ; ne pas logger le contenu en clair côté
  Crashlytics.

## 8. Critères d'acceptation (MVP)
- [ ] Un étudiant connecté crée une conversation et reçoit une réponse pertinente, en français, citant ses filières d'orientation et pays cibles réels.
- [ ] Impossible d'accéder à la conversation d'un autre utilisateur (404).
- [ ] La clé Groq n'apparaît jamais côté client.
- [ ] Hors-ligne : l'écran ne crashe pas, affiche un état clair, l'historique reste lisible.
- [ ] `tsc` ✅, `flutter analyze` ✅, test service backend (mock GroqService) vert.

## 9. Décisions actées
1. **Modèle économique** : **gratuit avec limites** — cap quotidien/utilisateur + budget mensuel global de tokens (cf. §4). Tiers payant plus tard.
2. **Modèle** : **Groq `llama-3.3-70b-versatile`** en primaire avec limite mensuelle ; **repli OpenRouter** (modèle gratuit / meilleur rapport qualité-prix) au-delà du budget et en attendant le tiers payant (client agnostique, cf. §5).
3. **Streaming** : **oui, dès le MVP** (SSE).
4. **Placement** : **5 onglets conservés + bouton « Coach » flottant persistant** (omniprésent) + entrée accueil. Pas de 6e onglet.
5. **Modération** : **garde-fous par system prompt au MVP** (périmètre restreint + refus hors-sujet, + sûreté intégrée du modèle). Passe de modération dédiée ajoutée **seulement si des abus sont constatés**.

### Reste à confirmer à l'implémentation
- Valeurs exactes : cap quotidien (ex. 20–30/j) et `LLM_MONTHLY_TOKEN_BUDGET`.
- Modèle OpenRouter de repli précis (vérifier dispo + support tool-calling).
- Seuil de bascule PRIMARY→FALLBACK.

## 10. Estimation (ordre de grandeur)
- MVP : modèle + migration + module backend + GroqService + écran chat + entrée accueil → **~2–3 jours**.
- P1 streaming + prompts : **+1 jour**.
- P2 tool calling (bourses/dossier/orientation) : **+2–3 jours**.
