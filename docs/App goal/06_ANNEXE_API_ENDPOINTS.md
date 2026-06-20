# 🔌 ANNEXE 06 — API ENDPOINTS REST

**Référence** : Cahier des charges KPB Education V1
**Usage** : Liste exhaustive des endpoints REST pour le backend
**Convention** : RESTful, JSON, prefix `/api/v1`

---

# 1. CONVENTIONS GLOBALES

## 1.1 Format des réponses

### Succès
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 156
  }
}
```

### Erreur
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Le numéro de téléphone est invalide",
    "field": "phone_number",
    "details": {}
  }
}
```

## 1.2 Codes HTTP

| Code | Usage |
|---|---|
| 200 OK | Lecture réussie |
| 201 Created | Création réussie |
| 204 No Content | Suppression réussie |
| 400 Bad Request | Validation input échouée |
| 401 Unauthorized | Non authentifié |
| 403 Forbidden | Authentifié mais pas autorisé |
| 404 Not Found | Ressource introuvable |
| 409 Conflict | Conflit (ex : OTP déjà utilisé) |
| 422 Unprocessable Entity | Validation métier échouée |
| 429 Too Many Requests | Rate limit |
| 500 Internal Server Error | Erreur serveur |

## 1.3 Headers standards

**Requêtes** :
```
Authorization: Bearer {access_token}
X-Client-Version: 1.0.0
X-Platform: android | ios | web
Content-Type: application/json
Accept-Language: fr
```

**Réponses** :
```
X-Request-ID: uuid (pour traçabilité)
X-Rate-Limit-Remaining: 95
```

## 1.4 Pagination

Tous les endpoints liste acceptent :
- `?page=1` (défaut 1)
- `?per_page=20` (défaut 20, max 100)
- `?sort=created_at` (avec optional `-` prefix pour DESC)

## 1.5 Filtres

Convention : `?filter[field]=value` pour les filtres complexes, ou query params simples pour les cas courants.

## 1.6 Localisation

Toutes les chaînes traduisibles renvoyées en français au MVP. Préparer la structure pour i18n future (ex : champ `name_i18n: {fr: '...', en: '...'}`).

---

# 2. AUTH & ONBOARDING

## 2.1 Authentification téléphone + OTP

### `POST /api/v1/auth/otp/send`
Envoie un OTP au numéro de téléphone.

**Request** :
```json
{
  "phone_number": "+22790123456"
}
```

**Response 200** :
```json
{
  "success": true,
  "data": {
    "phone_number": "+22790123456",
    "expires_in": 300,
    "next_resend_in": 30
  }
}
```

**Erreurs** : 400 (format), 429 (déjà envoyé récemment)

---

### `POST /api/v1/auth/otp/verify`
Vérifie l'OTP et crée la session.

**Request** :
```json
{
  "phone_number": "+22790123456",
  "code": "123456",
  "device_info": {
    "platform": "android",
    "os": "13",
    "model": "Tecno Spark 10"
  },
  "fcm_token": "abc123..."
}
```

**Response 200** :
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "phone_number": "+22790123456",
      "role": "user",
      "onboarding_completed": false
    },
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "expires_in": 3600
  }
}
```

**Erreurs** : 400 (code invalide), 410 (expiré), 429 (trop de tentatives)

---

### `POST /api/v1/auth/otp/resend`
Renvoie un OTP (cooldown 30s).

---

### `POST /api/v1/auth/email/magic-link/send`
Fallback email — envoie un lien magique.

**Request** :
```json
{ "email": "aicha@example.com" }
```

---

### `GET /api/v1/auth/email/magic-link/verify?token=...`
Vérifie le token email et crée la session.

---

### `POST /api/v1/auth/refresh`
Renouvelle l'access token.

**Request** :
```json
{ "refresh_token": "eyJ..." }
```

---

### `POST /api/v1/auth/logout`
Révoque la session courante.

---

### `DELETE /api/v1/auth/account`
Suppression du compte (soft delete).

---

## 2.2 Onboarding

### `GET /api/v1/onboarding/status`
Retourne l'étape actuelle de l'onboarding.

**Response 200** :
```json
{
  "success": true,
  "data": {
    "current_step": 3,
    "total_steps": 6,
    "completed": false,
    "saved_answers": {
      "user_type": "student",
      "education_level": "terminale"
    }
  }
}
```

---

### `PATCH /api/v1/onboarding/step`
Sauvegarde une étape (progressif).

**Request** :
```json
{
  "step": 3,
  "answers": {
    "bac_series": "D"
  }
}
```

---

### `POST /api/v1/onboarding/complete`
Marque l'onboarding comme terminé.

---

## 2.3 Profil utilisateur

### `GET /api/v1/me`
Retourne le profil complet de l'utilisateur connecté.

---

### `PATCH /api/v1/me`
Met à jour le profil.

**Request** :
```json
{
  "first_name": "Aïcha",
  "last_name": "Diallo",
  "city": "Niamey",
  "monthly_budget_eur": 800,
  "countries_of_interest": ["FRA", "CAN", "MAR"]
}
```

---

### `POST /api/v1/me/avatar`
Upload de l'avatar (multipart/form-data).

---

### `GET /api/v1/me/documents`
Liste les documents personnels.

---

### `POST /api/v1/me/documents`
Upload un document personnel.

**Request** (multipart) :
- `file`: <binary>
- `document_type`: 'cv' | 'transcript' | 'passport' | 'other'

---

### `DELETE /api/v1/me/documents/:id`
Supprime un document.

---

# 3. DESTINATIONS (PAYS)

### `GET /api/v1/countries`
Liste des 9 pays disponibles.

**Query params** : `?active=true` (défaut)

**Response 200** :
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "code": "FRA",
      "name_fr": "France",
      "flag_emoji": "🇫🇷",
      "tagline_fr": "Étudier au cœur de l'Europe...",
      "next_intake_label": "Septembre 2026",
      "main_language": "Français",
      "avg_tuition_min_eur": 5000,
      "avg_tuition_max_eur": 18000,
      "monthly_living_cost_eur": 1000,
      "is_active": true,
      "display_order": 1
    }
  ]
}
```

---

### `GET /api/v1/countries/:code`
Détail d'un pays (avec quiz inclus).

**Response 200** : tout le contenu de la fiche + structure `eligibility_quiz`.

---

### `POST /api/v1/countries/:code/quiz/submit`
Soumet le quiz d'éligibilité.

**Request** :
```json
{
  "answers": {
    "q1_level": "terminale",
    "q2_diploma": "yes_this_year",
    "q3_grades": "good",
    ...
  }
}
```

**Response 200** :
```json
{
  "success": true,
  "data": {
    "verdict": "eligible",
    "verdict_title": "🎉 Tu es éligible !",
    "verdict_message": "Excellent profil pour étudier en France...",
    "cta_label": "Demander un accompagnement France",
    "score_details": { ... },
    "recommended_alternatives": []
  }
}
```

---

# 4. UNIVERSITÉS & PROGRAMMES

### `GET /api/v1/schools`
Liste paginée des écoles.

**Query params** :
- `?country=FRA`
- `?is_partner=true`
- `?is_featured=true`
- `?search=ECE`
- `?page=1&per_page=20`

---

### `GET /api/v1/schools/:slug`
Détail d'une école avec ses programmes.

---

### `GET /api/v1/programs`
Recherche de programmes.

**Query params** :
- `?country=FRA`
- `?level=Bachelor`
- `?domain=Business`
- `?language=Anglais`
- `?budget_max=15000` (en EUR)
- `?is_partner=true`
- `?search=Marketing`
- `?sort=tuition_amount` (ASC) ou `-tuition_amount` (DESC)
- `?page=1&per_page=20`

**Response 200** :
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "International BBA",
      "school": {
        "id": "uuid",
        "slug": "icn-business-school",
        "name": "ICN Business School",
        "logo_url": "...",
        "is_partner": true
      },
      "country_code": "FRA",
      "campus": "Paris La Défense",
      "degree_level": "Bachelor",
      "duration": "4 years",
      "language_of_instruction": "Bilingue EN/FR",
      "tuition_amount": 9900,
      "tuition_currency": "EUR",
      "tuition_period": "per year",
      "tuition_eur_equivalent": 9900,
      "tuition_xof_equivalent": 6500000,
      "intake_label": "01/09/2026"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 142,
    "filters_applied": { "country": "FRA", "level": "Bachelor" }
  }
}
```

---

### `GET /api/v1/programs/:id`
Détail d'un programme.

---

# 5. ORIENTATION IA (M4)

### `GET /api/v1/orientation/questions`
Liste des questions du questionnaire (admin-gérées).

---

### `POST /api/v1/orientation/submit`
Soumet les réponses et lance le calcul IA.

**Request** :
```json
{
  "answers": {
    "matieres_fortes": ["math", "physique"],
    "interets_libre": "j'aime résoudre des problèmes",
    "preferences": "equipe,bureau,creer,analyser",
    "preoccupation_ia": true,
    "annees_etudes": 5,
    "niveau_langue": {"fr": "fluent", "en": "intermediate"},
    "pas_envie": "rester seul toute la journée"
  }
}
```

**Response 200** :
```json
{
  "success": true,
  "data": {
    "result_id": "uuid",
    "recommended_fields": [
      {
        "field": "Data Science",
        "score": 0.92,
        "explanation": "Tu aimes résoudre des problèmes et tes maths sont fortes — la data science combine analyse, équipe et impact.",
        "jobs": ["Data Scientist", "Data Analyst", "ML Engineer"],
        "ia_resilience": "high",
        "partner_schools": [
          {"id": "uuid", "name": "BAU Istanbul", "country": "TUR"},
          {"id": "uuid", "name": "ISMAGI", "country": "MAR"}
        ]
      }
    ],
    "ia_model_used": "claude-3-5-haiku"
  }
}
```

---

### `GET /api/v1/orientation/results`
Historique des résultats d'orientation de l'utilisateur.

---

### `GET /api/v1/orientation/results/:id`
Détail d'un résultat.

---

# 6. DEMANDES D'ACCOMPAGNEMENT (M8)

### `POST /api/v1/requests`
Crée une nouvelle demande (déclenche round-robin).

**Request** :
```json
{
  "request_type": "school_admission",
  "country_code": "FRA",
  "school_id": "uuid",
  "program_id": "uuid",
  "scholarship_id": null,
  "user_message": "Je veux m'inscrire à ECE Lyon en B1 Computer Science."
}
```

**Response 201** :
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "request_number": 1234,
    "status": "assigned",
    "assigned_to": {
      "id": "uuid",
      "first_name": "Jojo",
      "avatar_url": "..."
    },
    "created_at": "2026-05-22T10:00:00Z"
  }
}
```

---

### `GET /api/v1/requests`
Liste des demandes de l'utilisateur (ou commercial selon le rôle).

**Query params** :
- `?status=in_progress`
- `?country=FRA`
- `?page=1&per_page=20`

---

### `GET /api/v1/requests/:id`
Détail d'une demande (avec timeline events).

---

### `POST /api/v1/requests/:id/documents`
Ajoute un document à la demande.

---

### `GET /api/v1/requests/:id/messages`
Liste des messages de la conversation.

**Query params** : `?page=1&per_page=50`

---

### `POST /api/v1/requests/:id/messages`
Envoie un message dans la conversation.

**Request** :
```json
{
  "content": "Bonjour Jojo, j'ai uploadé mon CV",
  "attachment_url": null
}
```

---

### `PATCH /api/v1/requests/:id/messages/:msg_id/read`
Marque un message comme lu.

---

# 7. COMMERCIAUX (M9) — Rôle commercial uniquement

### `GET /api/v1/commercial/leads`
Liste des leads attribués au commercial connecté.

**Query params** :
- `?filter=all|new|today|starred`
- `?label=qualified|not_qualified|...`

---

### `PATCH /api/v1/commercial/leads/:request_id`
Met à jour étiquette + motif de discussion.

**Request** :
```json
{
  "label": "qualified",
  "discussion_topic": "Inscription ECE Lyon - Terminale D - budget OK"
}
```

---

### `GET /api/v1/commercial/stats`
Stats personnelles du commercial.

**Query params** : `?period=7d|30d|all_time`

**Response 200** :
```json
{
  "success": true,
  "data": {
    "period": "30d",
    "leads_received": 87,
    "leads_responded": 82,
    "avg_first_response_seconds": 1800,
    "leads_qualified": 51,
    "leads_converted": 18,
    "conversion_rate": 20.69
  }
}
```

---

# 8. COACH IA (M10)

### `POST /api/v1/coach/conversations`
Démarre ou récupère une conversation active.

**Response 200** :
```json
{
  "success": true,
  "data": {
    "conversation_id": "uuid",
    "quota_remaining": 3,
    "quota_reset_at": "2026-05-26T00:00:00Z",
    "is_premium": false
  }
}
```

---

### `POST /api/v1/coach/conversations/:id/messages`
Envoie un message au coach (consomme 1 du quota).

**Request** :
```json
{
  "content": "Quel pays choisir avec 800€/mois ?"
}
```

**Response 200 (streaming)** : SSE ou WebSocket, tokens progressifs.

**Erreurs** : 429 (quota dépassé), 402 (premium requis V2)

---

### `GET /api/v1/coach/conversations/:id/messages`
Historique des messages d'une conversation.

---

### `GET /api/v1/coach/quota`
Vérifie le quota courant.

---

# 9. SIMULATEUR DE BUDGET (M11)

### `POST /api/v1/budget/simulate`
Lance une simulation budget.

**Request** :
```json
{
  "annual_budget_eur": 10000,
  "duration_years": 3,
  "level": "bachelor",
  "loan_acceptable": true,
  "can_work": true
}
```

**Response 200** :
```json
{
  "success": true,
  "data": {
    "simulation_id": "uuid",
    "results": [
      {
        "country_code": "MAR",
        "status": "accessible",
        "total_estimated_year_eur": 4500,
        "total_estimated_cursus_eur": 13500,
        "explanation": "Le Maroc est largement dans ton budget. Tu pourrais même viser un Master.",
        "recommended_partners": ["ismagi", "esa-casablanca"]
      },
      {
        "country_code": "FRA",
        "status": "tight_but_possible",
        ...
      },
      {
        "country_code": "USA",
        "status": "inaccessible",
        ...
      }
    ]
  }
}
```

---

### `GET /api/v1/budget/simulations`
Historique des simulations.

---

### `POST /api/v1/budget/simulations/:id/save`
Sauvegarde une simulation dans le profil.

---

# 10. BOURSES (M12)

### `GET /api/v1/scholarships`
Liste des bourses disponibles.

**Query params** : `?country=CAN&level=master&status=active`

---

### `GET /api/v1/scholarships/:slug`
Détail d'une bourse.

---

### `POST /api/v1/scholarships/:slug/quiz/submit`
Soumet le quiz d'éligibilité d'une bourse.

---

# 11. FAVORIS

### `GET /api/v1/favorites`
Liste des favoris de l'utilisateur.

**Query params** : `?item_type=country|school|program|scholarship`

---

### `POST /api/v1/favorites`
Ajoute un favori.

**Request** :
```json
{
  "item_type": "program",
  "item_id": "uuid"
}
```

---

### `DELETE /api/v1/favorites/:id`
Retire un favori.

---

# 12. NOTIFICATIONS (M13)

### `GET /api/v1/notifications`
Liste des notifications reçues.

**Query params** :
- `?page=1&per_page=20`
- `?unread_only=true`

---

### `PATCH /api/v1/notifications/:id/read`
Marque une notification comme lue.

---

### `PATCH /api/v1/notifications/read-all`
Marque toutes les notifications comme lues.

---

### `GET /api/v1/notifications/preferences`
Récupère les préférences de notif par catégorie.

---

### `PATCH /api/v1/notifications/preferences`
Met à jour les préférences.

**Request** :
```json
{
  "preferences": {
    "request_status": true,
    "new_message": true,
    "new_scholarship": true,
    "new_article": false,
    "new_video": true,
    "general": true
  }
}
```

---

# 13. CONTENU (V1.1)

## 13.1 Vidéos (M15)

### `GET /api/v1/videos`
Liste des vidéos.

**Query params** : `?category=tech&page=1`

---

### `GET /api/v1/videos/:id`
Détail vidéo.

---

## 13.2 Articles (M16)

### `GET /api/v1/articles`
Liste des articles publiés.

---

### `GET /api/v1/articles/:slug`
Détail article.

---

# 14. ADMIN / BACK-OFFICE (M13)

> **Préfix** : `/api/v1/admin/`
> **Auth** : rôle `admin` requis

## 14.1 Dashboard

### `GET /api/v1/admin/dashboard/kpis`
KPIs globaux (utilisateurs, demandes, conversion…).

**Query params** : `?period=7d|30d|90d|all`

---

## 14.2 Utilisateurs

### `GET /api/v1/admin/users`
Liste paginée des utilisateurs.

**Query params** : recherche, filtre par rôle, persona, pays…

---

### `GET /api/v1/admin/users/:id`
Détail utilisateur (avec demandes, profil complet).

---

### `PATCH /api/v1/admin/users/:id`
Modifier rôle, statut, etc.

---

## 14.3 Demandes (vue admin)

### `GET /api/v1/admin/requests`
Liste de toutes les demandes (tous commerciaux).

---

### `POST /api/v1/admin/requests/:id/reassign`
Réassigne manuellement une demande.

**Request** :
```json
{
  "new_commercial_id": "uuid",
  "reason": "Demande spécifique au commercial X"
}
```

---

## 14.4 Commerciaux

### `GET /api/v1/admin/commercials`
Liste des commerciaux + leurs stats.

---

### `POST /api/v1/admin/commercials`
Crée un commercial (User avec role='commercial').

---

### `PATCH /api/v1/admin/commercials/:id/status`
Active/désactive un commercial.

---

## 14.5 Contenu

### `POST /api/v1/admin/countries/:code` (PATCH)
Modifie une fiche pays.

---

### `POST /api/v1/admin/schools` (POST/PATCH/DELETE)
CRUD écoles.

---

### `POST /api/v1/admin/programs` (POST/PATCH/DELETE)
CRUD programmes.

---

### `POST /api/v1/admin/scholarships` (POST/PATCH/DELETE)
CRUD bourses.

---

### `POST /api/v1/admin/articles` (POST/PATCH/DELETE)
CRUD articles blog.

---

### `POST /api/v1/admin/videos` (POST/PATCH/DELETE)
CRUD vidéos.

---

## 14.6 Notifications campagnes

### `GET /api/v1/admin/campaigns`
Liste des campagnes notif.

---

### `POST /api/v1/admin/campaigns`
Crée une campagne (brouillon).

**Request** :
```json
{
  "title": "🎓 Nouvelle bourse Canada !",
  "body": "McCall MacBain ouvre ses candidatures...",
  "category": "new_scholarship",
  "image_url": "...",
  "deep_link": "kpb://scholarships/mccall-macbain",
  "audience_filters": {
    "user_type": ["student"],
    "education_level": ["l3", "m1", "m2"],
    "countries_of_interest": ["CAN"]
  },
  "scheduled_for": "2026-06-01T09:00:00Z"
}
```

---

### `POST /api/v1/admin/campaigns/:id/preview`
Preview audience (combien d'utilisateurs touchés).

**Response 200** :
```json
{
  "success": true,
  "data": {
    "estimated_recipients": 1247,
    "sample_users": [ ... ]
  }
}
```

---

### `POST /api/v1/admin/campaigns/:id/send`
Envoie la campagne immédiatement (ou planifié si scheduled_for).

---

### `GET /api/v1/admin/campaigns/:id/stats`
Stats post-envoi.

---

# 15. WEBHOOKS (entrants)

## 15.1 YouTube

### `POST /api/v1/webhooks/youtube`
Webhook YouTube PubSubHubbub pour notification de nouvelle vidéo.

→ Déclenche création d'une video dans la DB + campagne notif auto si activé.

---

# 16. SYSTÈME & HEALTH

### `GET /api/v1/health`
Endpoint de healthcheck pour le monitoring.

**Response 200** :
```json
{
  "status": "ok",
  "uptime_seconds": 12345,
  "version": "1.0.0",
  "checks": {
    "database": "ok",
    "redis": "ok",
    "fcm": "ok"
  }
}
```

---

### `GET /api/v1/system/version`
Version de l'API et compatibilité avec versions mobile.

**Response 200** :
```json
{
  "api_version": "1.0.0",
  "minimum_client_version": {
    "android": "1.0.0",
    "ios": "1.0.0"
  },
  "force_update_below": {
    "android": "0.9.0",
    "ios": "0.9.0"
  }
}
```

---

# 17. RATE LIMITING

| Endpoint | Limite |
|---|---|
| `POST /auth/otp/send` | 5 / 15 min / IP |
| `POST /auth/otp/verify` | 10 / 15 min / IP |
| `POST /coach/.../messages` | 5 / semaine / user (gratuit) |
| `POST /requests` | 5 / heure / user |
| `POST /me/documents` | 20 / heure / user |
| Tous les autres | 100 / minute / user |

---

# 18. EVENTS WEBSOCKET / REALTIME

Pour le chat in-app et les notifications temps réel.

## 18.1 Connexion

```
WSS /ws?token={access_token}
```

## 18.2 Events serveur → client

```json
// Nouveau message dans une demande
{
  "type": "request.message.created",
  "data": { "request_id": "uuid", "message": { ... } }
}

// Changement de statut
{
  "type": "request.status.changed",
  "data": { "request_id": "uuid", "old_status": "...", "new_status": "..." }
}

// Demande attribuée à un commercial
{
  "type": "request.assigned",
  "data": { "request_id": "uuid", "commercial": { ... } }
}

// Notification push (mirror)
{
  "type": "notification.received",
  "data": { "notification": { ... } }
}
```

## 18.3 Events client → serveur

```json
// Marquer comme lu
{
  "type": "message.read",
  "data": { "message_id": "uuid" }
}

// Typing indicator
{
  "type": "request.typing",
  "data": { "request_id": "uuid" }
}
```

---

# 19. SDK & DOCUMENTATION

Générer automatiquement :
- Spec **OpenAPI 3.0** (`openapi.yaml`) accessible à `/api/v1/openapi`
- Doc Swagger UI à `/api/v1/docs`
- Doc ReDoc à `/api/v1/redoc`

---

**FIN ANNEXE 06**
