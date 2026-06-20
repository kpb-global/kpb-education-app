# 🗄️ ANNEXE 02 — MODÈLE DE DONNÉES

**Référence** : Cahier des charges KPB Education V1
**Usage** : Schéma DB complet pour le backend (PostgreSQL recommandé)

---

# 1. VUE D'ENSEMBLE

## 1.1 Conventions
- **Naming** : `snake_case` pour les tables et champs
- **Primary keys** : `id` UUID v4 par défaut
- **Timestamps** : `created_at`, `updated_at` sur toutes les tables
- **Soft deletes** : `deleted_at` (nullable) sur les tables business
- **Foreign keys** : `<table>_id` (ex : `user_id`)

## 1.2 Diagramme relationnel simplifié

```
┌─────────┐
│  users  │──┐
└─────────┘  │
    │        │
    │        ├──── requests ─── messages
    │        │         │
    │        │         └─── request_documents
    │        │
    │        ├──── orientation_results
    │        ├──── budget_simulations
    │        ├──── coach_conversations
    │        ├──── notifications
    │        └──── favorites
    │
    └─── user_profiles

┌──────────┐
│countries │──── partner_schools ──── programs
└──────────┘         │
    │                │
    └─── scholarships
```

---

# 2. TABLES DÉTAILLÉES

## 2.1 Authentification & utilisateurs

### `users`
Compte utilisateur principal.

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    phone_verified_at TIMESTAMP,
    email VARCHAR(255) UNIQUE,
    email_verified_at TIMESTAMP,
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    -- role: 'user' | 'commercial' | 'admin'
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    -- status: 'active' | 'suspended' | 'deleted'
    last_login_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    deleted_at TIMESTAMP
);

CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
```

### `user_profiles`
Données détaillées du profil utilisateur.

```sql
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    avatar_url TEXT,
    date_of_birth DATE,
    gender VARCHAR(20),
    -- gender: 'male' | 'female' | 'other' | 'prefer_not_to_say'
    user_type VARCHAR(30),
    -- user_type: 'student' | 'parent' | 'partner'
    education_level VARCHAR(30),
    -- education_level: 'terminale' | 'l1_b1' | 'l2_b2' | 'l3_b3' | 'm1' | 'm2' | 'doctorat'
    bac_series VARCHAR(20),
    -- bac_series: 'A','A1','A4','A8','B','C','D','E','F','F1','F2','F3','F4','G','G1','G2','PRO','Tech','autre'
    country_origin VARCHAR(3),
    -- ISO 3166-1 alpha-3: 'NER', 'SEN', 'CIV', etc.
    city VARCHAR(100),
    monthly_budget_eur INTEGER,
    -- Budget en EUR par mois
    countries_of_interest TEXT[],
    -- Array de codes pays: ['FRA', 'CAN', 'MAR']
    domains_of_interest TEXT[],
    -- Array de domaines depuis orientation
    spoken_languages JSONB,
    -- {"fr": "native", "en": "intermediate", "ar": "basic"}
    onboarding_completed BOOLEAN DEFAULT false,
    onboarding_step INTEGER DEFAULT 0,
    -- Pour reprendre où l'utilisateur s'est arrêté
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_user ON user_profiles(user_id);
CREATE INDEX idx_profiles_type ON user_profiles(user_type);
```

### `otp_codes`
Codes OTP pour l'authentification (purge automatique > 24h).

```sql
CREATE TABLE otp_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) NOT NULL,
    code VARCHAR(6) NOT NULL,
    attempts INTEGER DEFAULT 0,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_otp_phone ON otp_codes(phone_number);
CREATE INDEX idx_otp_expires ON otp_codes(expires_at);
```

### `sessions`
Sessions actives (JWT refresh tokens).

```sql
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash VARCHAR(255) NOT NULL,
    device_info JSONB,
    -- {"platform": "android", "os": "13", "model": "Tecno Spark"}
    fcm_token TEXT,
    -- Pour notifications push
    ip_address VARCHAR(45),
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_fcm ON sessions(fcm_token);
```

---

## 2.2 Référentiels pays / écoles / programmes

### `countries`
Les 9 pays disponibles au lancement.

```sql
CREATE TABLE countries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(3) UNIQUE NOT NULL,
    -- ISO 3166-1 alpha-3: 'FRA', 'DEU', 'USA', 'CAN', 'MAR', 'TUR', 'ARE', 'GBR', 'ESP'
    name_fr VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    flag_emoji VARCHAR(10),
    flag_url TEXT,
    hero_image_url TEXT,
    tagline_fr TEXT,
    -- "Étudier au cœur de l'Europe"
    description_fr TEXT,
    -- Description marketing complète
    next_intake_label VARCHAR(50),
    -- "Septembre 2026" | "Janvier 2027"
    main_language VARCHAR(20),
    -- "Français" | "Anglais" | "Allemand"
    why_study_here TEXT[],
    -- Array de raisons
    process_steps JSONB,
    -- Étapes du process avec titres + descriptions
    avg_tuition_min_eur INTEGER,
    avg_tuition_max_eur INTEGER,
    monthly_living_cost_eur INTEGER,
    visa_info TEXT,
    language_requirements TEXT,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_countries_code ON countries(code);
CREATE INDEX idx_countries_active ON countries(is_active);
```

### `country_eligibility_quizzes`
Quiz d'éligibilité par pays (5-7 questions).

```sql
CREATE TABLE country_eligibility_quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL REFERENCES countries(id) ON DELETE CASCADE,
    questions JSONB NOT NULL,
    -- Array d'objets question : [{id, text, type, options, scoring}]
    scoring_rules JSONB NOT NULL,
    -- Règles de scoring pour déterminer verdict
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);
```

### `partner_schools`
Établissements partenaires KPB.

```sql
CREATE TABLE partner_schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) UNIQUE NOT NULL,
    -- ex: 'icn-business-school', 'ece', 'bau-istanbul'
    name VARCHAR(255) NOT NULL,
    logo_url TEXT,
    cover_image_url TEXT,
    country_id UUID NOT NULL REFERENCES countries(id),
    cities TEXT[],
    -- Array de villes campus: ['Paris', 'Lyon', 'Bordeaux']
    description TEXT,
    website_url TEXT,
    is_partner BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    -- Mettre en avant sur l'accueil
    partner_group VARCHAR(100),
    -- "OMNES Education" | "IGENSIA" | "Standalone"
    rankings JSONB,
    -- {"global": 250, "national": 12}
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_schools_slug ON partner_schools(slug);
CREATE INDEX idx_schools_country ON partner_schools(country_id);
CREATE INDEX idx_schools_featured ON partner_schools(is_featured);
```

### `programs`
Programmes d'études individuels.

```sql
CREATE TABLE programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES partner_schools(id) ON DELETE CASCADE,
    name VARCHAR(500) NOT NULL,
    campus VARCHAR(100),
    -- Ville du campus pour ce programme
    program_family VARCHAR(100),
    -- "Business" | "Engineering" | "Tech & Innovation" | etc.
    domain VARCHAR(100),
    -- Domaine taxonomique (matchera avec orientation IA)
    degree_level VARCHAR(50),
    -- "Bachelor" | "Master/MBA" | "PhD" | "Bac+2 Preparatory" | "Engineering"
    admission_level VARCHAR(100),
    -- "Bachelor 1ère année" | "Master 2"
    duration VARCHAR(50),
    -- "3 years" | "4 years" | "Variable"
    language_of_instruction VARCHAR(100),
    -- "Français" | "Anglais" | "Bilingue FR/EN"
    tuition_amount NUMERIC(10, 2),
    tuition_currency VARCHAR(3),
    -- "EUR" | "USD" | "MAD" | "AED"
    tuition_period VARCHAR(50),
    -- "per year" | "whole program"
    tuition_installments NUMERIC(10, 2),
    -- Paiement échelonné si applicable
    intake_date DATE,
    intake_label VARCHAR(100),
    -- "01/09/2026" | "Fall 2026"
    academic_eligibility TEXT,
    language_eligibility TEXT,
    required_documents TEXT,
    application_process TEXT,
    scholarship_available BOOLEAN DEFAULT false,
    source_urls TEXT[],
    internal_notes TEXT,
    status VARCHAR(50) DEFAULT 'active',
    -- 'active' | 'to_confirm' | 'inactive'
    is_featured BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_programs_school ON programs(school_id);
CREATE INDEX idx_programs_domain ON programs(domain);
CREATE INDEX idx_programs_level ON programs(degree_level);
CREATE INDEX idx_programs_tuition ON programs(tuition_amount, tuition_currency);
CREATE INDEX idx_programs_language ON programs(language_of_instruction);
CREATE INDEX idx_programs_status ON programs(status);
```

---

## 2.3 Orientation IA

### `orientation_questions`
Questions du questionnaire d'orientation (gérées par admin).

```sql
CREATE TABLE orientation_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_text TEXT NOT NULL,
    question_type VARCHAR(50) NOT NULL,
    -- 'single_select' | 'multi_select' | 'free_text' | 'slider' | 'binary'
    options JSONB,
    -- Pour single/multi_select
    display_order INTEGER NOT NULL,
    is_required BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
```

### `orientation_results`
Résultats d'orientation par utilisateur.

```sql
CREATE TABLE orientation_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    answers JSONB NOT NULL,
    -- {"q1": "scientifique", "q2": ["math", "physique"], ...}
    recommended_fields JSONB NOT NULL,
    -- Array : [{field, score, explanation, jobs, ia_resilience, partner_schools}]
    ia_model_used VARCHAR(50),
    -- "claude-3-5-haiku" | "gpt-4o-mini"
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_orientation_user ON orientation_results(user_id);
```

### `bac_interests_mapping`
Table de mapping séries de bac → centres d'intérêt.

```sql
CREATE TABLE bac_interests_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bac_series VARCHAR(20) NOT NULL,
    interest VARCHAR(100) NOT NULL,
    weight NUMERIC(3, 2) DEFAULT 1.0,
    -- Coefficient de pertinence
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_bac_mapping_series ON bac_interests_mapping(bac_series);
```

---

## 2.4 Demandes d'accompagnement & commerciaux

### `requests`
Demandes d'accompagnement.

```sql
CREATE TABLE requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_number SERIAL UNIQUE,
    -- Numéro lisible : #1234
    user_id UUID NOT NULL REFERENCES users(id),
    request_type VARCHAR(50) NOT NULL,
    -- 'school_admission' | 'scholarship' | 'visa' | 'housing' | 'other'
    country_id UUID REFERENCES countries(id),
    school_id UUID REFERENCES partner_schools(id),
    program_id UUID REFERENCES programs(id),
    scholarship_id UUID REFERENCES scholarships(id),
    user_message TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'submitted',
    -- 'submitted' | 'assigned' | 'in_review' | 'documents_missing' |
    -- 'in_progress' | 'submitted_to_institution' | 'awaiting_payment' |
    -- 'accepted' | 'refused' | 'closed'
    assigned_to UUID REFERENCES users(id),
    -- Commercial assigné (FK vers users avec role='commercial')
    assigned_at TIMESTAMP,
    last_commercial_interaction_at TIMESTAMP,
    -- Pour la règle de réattribution 10h
    label VARCHAR(50),
    -- 'qualified' | 'not_qualified' | 'awaiting_payment' |
    -- 'converted' | 'lost' | 'to_follow_up'
    discussion_topic VARCHAR(150),
    -- "Inscription ECE Lyon - budget OK" (par le commercial)
    internal_notes TEXT,
    -- Notes commerciales (non visibles utilisateur)
    closed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_requests_user ON requests(user_id);
CREATE INDEX idx_requests_status ON requests(status);
CREATE INDEX idx_requests_assigned ON requests(assigned_to);
CREATE INDEX idx_requests_label ON requests(label);
CREATE INDEX idx_requests_last_interaction ON requests(last_commercial_interaction_at);
```

### `request_documents`
Documents attachés aux demandes.

```sql
CREATE TABLE request_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    document_type VARCHAR(100),
    -- 'cv' | 'transcript' | 'passport' | 'motivation_letter' | 'photo' | 'other'
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    file_size INTEGER,
    mime_type VARCHAR(100),
    uploaded_by_role VARCHAR(20),
    -- 'user' | 'commercial' | 'admin'
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_documents_request ON request_documents(request_id);
```

### `request_timeline_events`
Historique des changements de statut.

```sql
CREATE TABLE request_timeline_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    -- 'status_changed' | 'assigned' | 'reassigned' | 'document_added' |
    -- 'document_requested' | 'message_sent'
    old_value TEXT,
    new_value TEXT,
    actor_id UUID REFERENCES users(id),
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_timeline_request ON request_timeline_events(request_id, created_at);
```

### `messages`
Chat in-app entre utilisateur et commercial.

```sql
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id),
    sender_role VARCHAR(20) NOT NULL,
    -- 'user' | 'commercial' | 'admin' | 'system'
    content TEXT,
    attachment_url TEXT,
    attachment_type VARCHAR(50),
    -- 'image' | 'document' | 'audio'
    read_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_messages_request ON messages(request_id, created_at);
CREATE INDEX idx_messages_unread ON messages(request_id, sender_role) WHERE read_at IS NULL;
```

### `round_robin_state`
État de la rotation round-robin (singleton).

```sql
CREATE TABLE round_robin_state (
    id INTEGER PRIMARY KEY DEFAULT 1,
    last_assigned_commercial_id UUID REFERENCES users(id),
    last_assigned_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT singleton CHECK (id = 1)
);

-- Insert initial state
INSERT INTO round_robin_state (id) VALUES (1);
```

### `commercial_stats`
Statistiques commerciaux (mises à jour quotidiennement).

```sql
CREATE TABLE commercial_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commercial_id UUID NOT NULL REFERENCES users(id),
    period VARCHAR(20) NOT NULL,
    -- '7d' | '30d' | 'all_time'
    leads_received INTEGER DEFAULT 0,
    leads_responded INTEGER DEFAULT 0,
    avg_first_response_seconds INTEGER,
    leads_qualified INTEGER DEFAULT 0,
    leads_converted INTEGER DEFAULT 0,
    conversion_rate NUMERIC(5, 2),
    -- En pourcentage
    calculated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE(commercial_id, period)
);

CREATE INDEX idx_stats_commercial ON commercial_stats(commercial_id);
```

---

## 2.5 Coach IA

### `coach_conversations`
Conversations avec le Coach IA.

```sql
CREATE TABLE coach_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at TIMESTAMP NOT NULL DEFAULT now(),
    last_message_at TIMESTAMP NOT NULL DEFAULT now(),
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_coach_conv_user ON coach_conversations(user_id);
```

### `coach_messages`
Messages dans une conversation coach.

```sql
CREATE TABLE coach_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES coach_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    role VARCHAR(20) NOT NULL,
    -- 'user' | 'assistant' | 'system'
    content TEXT NOT NULL,
    tokens_input INTEGER,
    tokens_output INTEGER,
    model_used VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_coach_msg_conv ON coach_messages(conversation_id);
```

### `coach_usage_quotas`
Suivi du quota hebdomadaire 5 messages/semaine.

```sql
CREATE TABLE coach_usage_quotas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,
    -- Lundi de la semaine concernée
    messages_count INTEGER DEFAULT 0,
    is_premium BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE(user_id, week_start_date)
);

CREATE INDEX idx_coach_quota_user_week ON coach_usage_quotas(user_id, week_start_date);
```

---

## 2.6 Simulateur de budget

### `budget_simulations`
Simulations de budget sauvegardées.

```sql
CREATE TABLE budget_simulations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    inputs JSONB NOT NULL,
    -- {"annual_budget_eur": 10000, "duration_years": 3, "level": "bachelor",
    --  "loan_acceptable": true, "can_work": true}
    results JSONB NOT NULL,
    -- {countries: [{code, status, total_estimated, ...}]}
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_budget_user ON budget_simulations(user_id);
```

---

## 2.7 Bourses

### `scholarships`
Bourses disponibles.

```sql
CREATE TABLE scholarships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    organization VARCHAR(255),
    -- "McGill University" | "DAAD" | "Türkiye Burslari"
    country_id UUID REFERENCES countries(id),
    target_levels TEXT[],
    -- ['master', 'doctorat']
    target_domains TEXT[],
    coverage_description TEXT,
    -- "Frais scolarité + allocation mensuelle + voyage"
    estimated_amount_eur INTEGER,
    application_open_date DATE,
    application_close_date DATE,
    intake_year INTEGER,
    eligibility_text TEXT,
    eligibility_quiz_id UUID,
    description TEXT,
    logo_url TEXT,
    official_url TEXT,
    status VARCHAR(20) DEFAULT 'active',
    -- 'draft' | 'active' | 'expired' | 'closed'
    is_featured BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_scholarships_country ON scholarships(country_id);
CREATE INDEX idx_scholarships_status ON scholarships(status);
```

### `scholarship_eligibility_quizzes`
Quiz d'éligibilité par bourse.

```sql
CREATE TABLE scholarship_eligibility_quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scholarship_id UUID NOT NULL REFERENCES scholarships(id) ON DELETE CASCADE,
    questions JSONB NOT NULL,
    scoring_rules JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
```

---

## 2.8 Notifications

### `notifications`
Notifications individuelles envoyées aux utilisateurs.

```sql
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    campaign_id UUID REFERENCES notification_campaigns(id),
    type VARCHAR(50) NOT NULL,
    -- 'transactional' | 'campaign' | 'system'
    category VARCHAR(50),
    -- 'request_status' | 'new_message' | 'new_scholarship' |
    -- 'new_article' | 'new_video' | 'live_starting' | 'general'
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    deep_link TEXT,
    -- "kpb://requests/1234" | "kpb://countries/CAN"
    image_url TEXT,
    sent_at TIMESTAMP NOT NULL DEFAULT now(),
    delivered_at TIMESTAMP,
    opened_at TIMESTAMP,
    clicked_at TIMESTAMP,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_notif_user ON notifications(user_id, sent_at DESC);
CREATE INDEX idx_notif_campaign ON notifications(campaign_id);
```

### `notification_campaigns`
Campagnes créées par l'admin.

```sql
CREATE TABLE notification_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    image_url TEXT,
    deep_link TEXT,
    audience_filters JSONB,
    -- {"user_type": ["student"], "countries_of_interest": ["CAN"], ...}
    scheduled_for TIMESTAMP,
    sent_at TIMESTAMP,
    total_recipients INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'draft',
    -- 'draft' | 'scheduled' | 'sending' | 'sent' | 'cancelled'
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
```

---

## 2.9 Favoris

### `favorites`
Items mis en favoris par les utilisateurs.

```sql
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_type VARCHAR(50) NOT NULL,
    -- 'country' | 'school' | 'program' | 'scholarship' | 'video'
    item_id UUID NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE(user_id, item_type, item_id)
);

CREATE INDEX idx_favorites_user ON favorites(user_id);
```

---

## 2.10 Contenu (Blog, Vidéos, Forum)

### `videos`
Vidéos YouTube de la chaîne KPB (M15 / V1.1).

```sql
CREATE TABLE videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    youtube_id VARCHAR(20) UNIQUE NOT NULL,
    -- ex: 'kYUHWhaeJiw'
    title VARCHAR(500) NOT NULL,
    description TEXT,
    summary TEXT,
    -- Résumé pour affichage in-app
    tags TEXT[],
    category VARCHAR(100),
    -- 'sciences' | 'tech' | 'medecine' | 'droit' | 'business' |
    -- 'ingenierie' | 'arts' | 'autres'
    thumbnail_url TEXT,
    -- https://img.youtube.com/vi/{youtube_id}/hqdefault.jpg
    youtube_url TEXT NOT NULL,
    duration_seconds INTEGER,
    published_at TIMESTAMP,
    view_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_videos_category ON videos(category);
CREATE INDEX idx_videos_featured ON videos(is_featured);
```

### `articles`
Articles blog (M16 / V1.1).

```sql
CREATE TABLE articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(200) UNIQUE NOT NULL,
    title VARCHAR(500) NOT NULL,
    excerpt TEXT,
    content_markdown TEXT NOT NULL,
    cover_image_url TEXT,
    category VARCHAR(100),
    tags TEXT[],
    author_id UUID REFERENCES users(id),
    author_name VARCHAR(255),
    reading_time_minutes INTEGER,
    published_at TIMESTAMP,
    view_count INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'draft',
    -- 'draft' | 'published' | 'archived'
    is_featured BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_articles_slug ON articles(slug);
CREATE INDEX idx_articles_status ON articles(status);
CREATE INDEX idx_articles_category ON articles(category);
```

### `forum_threads`
Threads du forum (M17 / V2).

```sql
CREATE TABLE forum_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    category VARCHAR(100) NOT NULL,
    -- 'pays_france' | 'pays_allemagne' | ... | 'admission' | 'visa' |
    -- 'logement' | 'vie_etudiante' | 'bourses' | 'orientation'
    title VARCHAR(500) NOT NULL,
    description TEXT NOT NULL,
    replies_count INTEGER DEFAULT 0,
    views_count INTEGER DEFAULT 0,
    last_reply_at TIMESTAMP,
    moderation_status VARCHAR(20) DEFAULT 'approved',
    -- 'approved' | 'flagged' | 'rejected' | 'pending_review'
    moderation_score NUMERIC(3, 2),
    is_pinned BOOLEAN DEFAULT false,
    is_locked BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_threads_category ON forum_threads(category);
CREATE INDEX idx_threads_status ON forum_threads(moderation_status);
```

### `forum_replies`
Réponses dans les threads.

```sql
CREATE TABLE forum_replies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES forum_threads(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    moderation_status VARCHAR(20) DEFAULT 'approved',
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_replies_thread ON forum_replies(thread_id, created_at);
```

---

## 2.11 Analytics & monitoring

### `events`
Événements analytiques (pour PostHog ou DB interne).

```sql
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    session_id UUID,
    event_name VARCHAR(100) NOT NULL,
    -- 'screen_view' | 'button_click' | 'request_created' | etc.
    properties JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_user ON events(user_id);
CREATE INDEX idx_events_name ON events(event_name);
CREATE INDEX idx_events_created ON events(created_at);
```

---

# 3. RÈGLES DE GESTION CRITIQUES

## 3.1 Round-robin (M9)

**Stored procedure** : `assign_commercial_to_request(request_id UUID)`

```sql
-- Pseudo-code
BEGIN;
  -- 1. Récupérer les commerciaux actifs ordonnés par ID
  SELECT id FROM users
  WHERE role = 'commercial' AND status = 'active'
  ORDER BY id;

  -- 2. Récupérer le dernier assigné
  SELECT last_assigned_commercial_id FROM round_robin_state WHERE id = 1;

  -- 3. Trouver le prochain dans la rotation
  -- (si last_assigned est NULL, prendre le premier)

  -- 4. Mettre à jour la demande
  UPDATE requests SET
    assigned_to = next_commercial_id,
    assigned_at = now(),
    status = 'assigned'
  WHERE id = request_id;

  -- 5. Logger événement timeline
  INSERT INTO request_timeline_events (...) VALUES (...);

  -- 6. Mettre à jour state
  UPDATE round_robin_state SET
    last_assigned_commercial_id = next_commercial_id,
    last_assigned_at = now();

  -- 7. Envoyer notification push (via job async)
COMMIT;
```

## 3.2 Réattribution automatique (10h sans interaction)

**Job CRON** : exécuté toutes les 15 minutes.

```sql
-- Logique pseudo-SQL
SELECT id, assigned_to FROM requests
WHERE status IN ('assigned', 'in_review')
  AND assigned_at < now() - INTERVAL '10 hours'
  AND (last_commercial_interaction_at IS NULL
       OR last_commercial_interaction_at < now() - INTERVAL '10 hours')
  AND NOT EXISTS (
    SELECT 1 FROM messages
    WHERE request_id = requests.id
      AND sender_role = 'commercial'
      AND created_at > now() - INTERVAL '10 hours'
  );

-- Pour chaque demande trouvée :
-- 1. Identifier le commercial avec le meilleur avg_first_response_seconds (30 derniers jours)
--    (différent du commercial actuellement assigné)
-- 2. Réassigner
-- 3. Logger événement timeline 'reassigned'
-- 4. Notifications : ancien commercial, nouveau commercial, admin
```

## 3.3 Quota Coach IA (5 messages/semaine)

**Avant chaque envoi de message** :

```sql
-- 1. Calculer le lundi de la semaine en cours
WITH current_week AS (
  SELECT date_trunc('week', now())::date AS week_start
)
-- 2. Récupérer (ou créer) le quota de la semaine
INSERT INTO coach_usage_quotas (user_id, week_start_date, messages_count)
VALUES (:user_id, (SELECT week_start FROM current_week), 0)
ON CONFLICT (user_id, week_start_date) DO NOTHING;

-- 3. Récupérer le compteur
SELECT messages_count, is_premium FROM coach_usage_quotas
WHERE user_id = :user_id AND week_start_date = (SELECT week_start FROM current_week);

-- 4. Si is_premium = false ET messages_count >= 5 → bloquer
-- Sinon, incrémenter messages_count
UPDATE coach_usage_quotas SET messages_count = messages_count + 1
WHERE user_id = :user_id AND week_start_date = (SELECT week_start FROM current_week);
```

## 3.4 Soft delete utilisateur

Quand un utilisateur supprime son compte :
- `users.deleted_at` = now()
- `users.status` = 'deleted'
- `user_profiles.email` = anonymized (`deleted_{user_id}@kpb.app`)
- `user_profiles.first_name` = "Utilisateur"
- `user_profiles.last_name` = "supprimé"
- Conserver les demandes/messages historiques (pour la traçabilité)
- Purger sessions

---

# 4. SEED DATA INITIALE

À charger à l'install :

1. **Countries** : 9 entrées (voir Annexe 04)
2. **Country eligibility quizzes** : 9 quizzes (voir Annexe 04)
3. **Partner schools** : ~12 entrées (OMNES Education global + ICN + Schiller + ISMAGI + ESA + BAU + GBS)
4. **Programs** : 800+ entrées (748 OMNES + 61 autres + ajouts manuels)
5. **Scholarships** : 1 entrée (McCall MacBain)
6. **Orientation questions** : 12 entrées
7. **Bac interests mapping** : ~400 entrées (séries × intérêts)
8. **Videos** : 0 au MVP, 40 en V1.1
9. **Round robin state** : 1 entrée (singleton)
10. **3 commerciaux** : Jojo, Donald, Richard (rôle 'commercial')
11. **1 admin** : Aminou (rôle 'admin')

---

**FIN ANNEXE 02**
