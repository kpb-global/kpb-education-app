# 📱 CAHIER DES CHARGES — APPLICATION MOBILE KPB EDUCATION V1

**Document maître pour Antigravity / Codex / Claude Code / Cursor**
**Version 1.0 — Mai 2026**
**Rédigé pour : équipe de développement automatisée**

---

## 📌 Comment lire ce document

Ce document est le **document maître**. Il est accompagné de **6 annexes** qui doivent être lues ensemble :

| Fichier | Contenu | Usage |
|---|---|---|
| `00_CAHIER_DES_CHARGES_MASTER.md` | Ce document (vision, modules, specs) | Lecture obligatoire en premier |
| `01_ANNEXE_PERSONAS_USER_STORIES.md` | Personas + user stories complètes | Pour comprendre les flows utilisateurs |
| `02_ANNEXE_MODELE_DONNEES.md` | Schéma DB complet (tables, champs, relations) | Pour le backend |
| `03_ANNEXE_DESIGN_SYSTEM.md` | Couleurs, typo, composants, ton | Pour le frontend |
| `04_ANNEXE_DATA_SEED_PAYS.md` | 9 fiches pays complètes prêtes à intégrer | Pour peupler la base au lancement |
| `05_ANNEXE_DATA_SEED_PARTENAIRES.md` | Programmes partenaires (hors OMNES qui est en xlsx) | Pour peupler la base au lancement |
| `06_ANNEXE_API_ENDPOINTS.md` | Endpoints REST détaillés | Pour le backend |

**Règle d'or** : si une instruction de ce document semble contredire une annexe, le **master gagne** sauf indication contraire explicite.

---

# 1. VISION & POSITIONNEMENT

## 1.1 Mission

KPB Education construit **l'application mobile de référence en Afrique francophone** pour l'orientation académique et l'inscription dans des établissements d'enseignement supérieur à l'étranger.

L'application doit permettre à un jeune Africain francophone de passer en quelques jours d'un état "je ne sais pas quoi faire ni où aller" à un état "j'ai une demande d'accompagnement KPB en cours pour une école précise dans un pays précis".

## 1.2 Proposition de valeur

| Côté étudiant | Côté KPB |
|---|---|
| Aide à choisir une filière (orientation IA) | Génération continue de leads qualifiés |
| Découverte de 9 destinations possibles | Conversion vers les services payants d'accompagnement |
| Quiz d'éligibilité par pays en 1 clic | Commissions sur placements écoles partenaires |
| Recherche universités par budget + pays | Système commercial intégré avec round-robin |
| Coaching IA conversationnel | Pilotage centralisé depuis admin cloud |
| Simulateur de budget personnalisé | Communication directe (notifs push) avec base utilisateurs |
| Demande d'accompagnement en 1 clic | |

## 1.3 Marché cible & langue

- **Marché géographique** : Afrique francophone (Niger, Sénégal, Côte d'Ivoire, Cameroun, Mali, Burkina Faso, Bénin, Togo, Gabon, Congo, Madagascar, etc.)
- **Langue de l'app au lancement** : **100% français**
- Une version anglophone séparée sera créée plus tard (autre branding / nom). Ne pas perdre de temps sur l'i18n au MVP.

## 1.4 KPIs de succès (à mesurer dès le lancement)

| KPI | Cible 3 mois | Cible 6 mois |
|---|---|---|
| Téléchargements | 5 000 | 25 000 |
| Comptes créés | 3 000 | 15 000 |
| Demandes d'accompagnement soumises | 200 | 1 000 |
| Taux de conversion demande → signature | 15 % | 25 % |
| Temps moyen 1ère réponse commercial | < 2 h | < 30 min |
| Note moyenne stores | 4.3 | 4.6 |

## 1.5 Principes UX directeurs

1. **Mobile-first absolu** — l'app doit être utilisable sur des Android entrée de gamme avec connexion 3G instable.
2. **Simplicité radicale** — aucun jargon académique non expliqué. Tout doit être compréhensible par un élève de Terminale.
3. **Action visible** — sur chaque écran de contenu, un CTA "Demander un accompagnement" ou "Discuter avec un conseiller" doit être présent.
4. **Bouton WhatsApp toujours accessible** — fallback pour les utilisateurs qui veulent une réponse immédiate.
5. **Cartes plutôt que texte long** — pas de paragraphes de plus de 5 lignes sur mobile.
6. **Pas d'écrans bloquants** — l'utilisateur doit pouvoir explorer sans créer de compte (sauf actions transactionnelles).

---

# 2. PERSONAS & USAGES PRINCIPAUX

→ Voir détails complets dans `01_ANNEXE_PERSONAS_USER_STORIES.md`

| Persona | Besoin principal | Modules clés |
|---|---|---|
| **Étudiant Terminale** (16-19 ans, ne sait pas quoi faire) | Trouver une filière + un pays + un budget | Orientation IA, Destinations, Simulateur budget, Coach IA |
| **Étudiant Lic/Master** (19-25 ans, projet plus défini) | Choisir une école précise pour son niveau | Recherche universités, Admission France privé, Demandes |
| **Parent d'élève** (40-60 ans, recherche pour son enfant) | Comparer pays + budgets + contacter un conseiller | Destinations, Simulateur, Coach IA, Demandes |
| **Commercial KPB** (Jojo, Donald, Richard) | Recevoir et traiter les leads | Inbox leads, Chat client, Étiquetage, Notifs push |

> ⚠️ **Le commercial accède à l'app via le même APK mobile** — pas de back-office séparé pour eux. Seul l'admin a une web app séparée (voir §5.12).

---

# 3. ARCHITECTURE FONCTIONNELLE

## 3.1 Liste exhaustive des modules

| # | Module | Phase | Priorité |
|---|---|---|---|
| M1 | Auth (Téléphone + OTP / Email backup) | **MVP** | 🔴 Critique |
| M2 | Onboarding 3 personas (avec Skip) | **MVP** | 🔴 Critique |
| M3 | Profil utilisateur | **MVP** | 🔴 Critique |
| M4 | Orientation IA (questionnaire + reco filières) | **MVP** | 🔴 Critique |
| M5 | Destinations (9 fiches pays + quiz éligibilité) | **MVP** | 🔴 Critique |
| M6 | Recherche universités (filtres budget/pays) | **MVP** | 🔴 Critique |
| M7 | Admission France écoles privées | **MVP** | 🔴 Critique |
| M8 | Demandes d'accompagnement (in-app + WhatsApp) | **MVP** | 🔴 Critique |
| M9 | Système commerciaux (round-robin + chat) | **MVP** | 🔴 Critique |
| M10 | Coach IA conversationnel (5 msg/sem) | **MVP** | 🟠 Haute |
| M11 | Simulateur de budget | **MVP** | 🟠 Haute |
| M12 | Bourses (McCall MacBain + ajout dynamique) | **MVP** | 🟡 Moyenne |
| M13 | Notifications push + Admin cloud | **MVP** | 🔴 Critique |
| M14 | Mes demandes (timeline + chat conseiller) | **MVP** | 🔴 Critique |
| M15 | Exemples de parcours (YouTube) | **V1.1** | 🟡 Moyenne |
| M16 | Blog (articles éditoriaux) | **V1.1** | 🟡 Moyenne |
| M17 | Forum communautaire (modération IA) | **V2** | 🟢 Basse |
| M18 | Scraping logements France | **V2** | 🟢 Basse (risques juridiques) |
| M19 | Coach IA Premium (paiement) | **V2** | 🟢 Basse |

## 3.2 Phasage temporel

```
┌─────────────────────────────────────────────────────────────┐
│ MVP — Semaines 1 à 3 (lancement)                            │
│ M1-M14 (14 modules critiques)                               │
├─────────────────────────────────────────────────────────────┤
│ V1.1 — Semaines 4 à 7 (enrichissement contenu)              │
│ M15 (Exemples parcours) + M16 (Blog)                        │
├─────────────────────────────────────────────────────────────┤
│ V2 — Mois 2 à 3 (communauté + monétisation IA)              │
│ M17 (Forum) + M18 (Scraping logements) + M19 (IA Premium)   │
└─────────────────────────────────────────────────────────────┘
```

> ⚠️ **Pourquoi le scraping logement est en V2** : la majorité des sites français de logement étudiant (LogementEtudiant.com, Studapart, Adele, Lokaviz) interdisent explicitement le scraping dans leurs CGU. Risque juridique + risque technique (HTML qui change toutes les semaines). **Stratégie recommandée** : négocier des partenariats d'affiliation avec 2-3 plateformes pour un accès API officiel. À traiter en V2.

---

# 4. ARCHITECTURE DE NAVIGATION

## 4.1 Bottom navigation principale (5 onglets pour étudiant/parent)

```
┌──────┬──────────┬────────────┬──────────┬───────┐
│ 🏠   │  🌍      │   🎓       │  💬      │  👤   │
│Accueil│Destinations│Universités│ Demandes │ Moi  │
└──────┴──────────┴────────────┴──────────┴───────┘
```

> **Note** : Antigravity avait fait 4 onglets en regroupant Destinations + Universités dans "Explorer". On passe à **5 onglets** pour séparer la logique Destination (pays) vs Universités (recherche).

## 4.2 Bottom navigation pour commercial (3 onglets)

```
┌─────────────┬───────────────┬────────┐
│ 📥          │  💬           │  👤    │
│ Mes Leads   │ Conversations │  Moi   │
└─────────────┴───────────────┴────────┘
```

L'app détecte le rôle à la connexion et affiche la navigation adaptée.

## 4.3 Bouton flottant global

**Bouton Coach IA** en bas à droite, présent sur tous les écrans (sauf si l'utilisateur est déjà dans un chat actif). Toujours visible. Icône 🤖 sur fond orange KPB.

## 4.4 Arborescence complète des écrans

```
APPLICATION KPB EDUCATION
│
├── 🔓 NON AUTHENTIFIÉ
│   ├── Splash screen
│   ├── Écran de bienvenue (3 slides : Pourquoi KPB / Quoi de mieux ici / Lancement)
│   ├── Choix méthode connexion (Téléphone OTP ou Email)
│   ├── Saisie téléphone → OTP → Vérification
│   ├── Saisie email (fallback) → Email magique → Vérification
│   └── [SKIP DISPONIBLE] → Accueil mode invité (lecture seule)
│
├── 🟢 ONBOARDING (post-auth, première connexion)
│   ├── Étape 1 : Tu es ? (Étudiant / Parent / Partenaire)
│   ├── Étape 2 (étudiant) : Niveau d'études actuel
│   │   └─ Terminale / L1-B1 / L2-B2 / L3-B3 / M1 / M2 / Doctorat
│   ├── Étape 3 (étudiant) : Série de baccalauréat (A, B, C, D, E, F, G, PRO, Tech, autre)
│   ├── Étape 4 : Pays(s) d'intérêt (multi-sélection, optionnel)
│   ├── Étape 5 : Budget mensuel disponible (slider 200-2000 EUR)
│   ├── Étape 6 : Notifications (autorisation push)
│   └── [BOUTON SKIP en haut à droite à chaque étape]
│
├── 🏠 ACCUEIL (étudiant/parent connecté)
│   ├── Header : nom utilisateur + avatar + bell notifications
│   ├── Carte "Reprendre" (dernière action en cours)
│   ├── Bannière Coach IA (animation glassmorphique)
│   ├── Actions rapides (3 boutons) :
│   │   ├─ Faire mon orientation
│   │   ├─ Trouver une école
│   │   └─ Simuler mon budget
│   ├── Section "À la Une" (push admin : nouvelle bourse / article / vidéo)
│   ├── Section "Destinations populaires" (carrousel 9 pays)
│   ├── Section "Écoles partenaires" (carrousel)
│   ├── Section "Bourses du moment" (1-3 cartes)
│   └── Bouton flottant Coach IA
│
├── 🌍 DESTINATIONS
│   ├── Liste 9 pays (cartes avec drapeau + flag rentrée)
│   │   ├─ France 🇫🇷 (rentrée Sept 2026 — écoles privées)
│   │   ├─ Allemagne 🇩🇪 (rentrée Sept 2026 — programme langue)
│   │   ├─ USA 🇺🇸 (rentrée Sept 2026)
│   │   ├─ Canada 🇨🇦 (rentrée Janvier 2027)
│   │   ├─ Maroc 🇲🇦 (rentrée Sept 2026)
│   │   ├─ Turquie 🇹🇷 (rentrée Sept 2026)
│   │   ├─ EAU 🇦🇪 (rentrée Sept 2026 — Dubaï)
│   │   ├─ Royaume-Uni 🇬🇧 (rentrée Janvier 2027)
│   │   └─ Espagne 🇪🇸 (rentrée Sept 2026)
│   └── Fiche pays (détails) → §5.5
│
├── 🎓 UNIVERSITÉS (recherche)
│   ├── Barre de recherche en haut
│   ├── Filtres : Pays, Budget, Niveau, Domaine, Langue
│   ├── Onglet "Partenaires KPB" (mis en avant par défaut)
│   ├── Onglet "Toutes les écoles"
│   ├── Liste de cartes établissements
│   └── Fiche établissement (détails) → §5.6
│
├── 💬 DEMANDES
│   ├── Liste de mes demandes (timeline statut)
│   ├── Fiche demande → chat avec conseiller + documents + timeline
│   └── Bouton "+ Nouvelle demande"
│
└── 👤 MOI
    ├── Profil (modifiable)
    ├── Mes favoris (écoles, pays, bourses)
    ├── Mes documents
    ├── Mes notifications (historique)
    ├── Paramètres (langue, notifications, confidentialité)
    ├── Aide & FAQ
    └── Déconnexion
```

---

# 5. SPÉCIFICATION DES MODULES

## 5.1 M1 — Authentification

### Description
Système d'authentification mobile-first avec **téléphone + OTP** en méthode principale (adapté au marché africain) et **email + lien magique** en backup.

### Écrans
- Saisie numéro de téléphone (préfixe pays auto-détecté)
- Saisie code OTP (6 chiffres, expiration 5 min)
- Saisie email (backup)
- Lien magique reçu par email

### Règles métier
- OTP valide 5 minutes
- 3 tentatives maximum avant blocage 15 min
- Renvoi OTP possible après 30 sec
- Le numéro de téléphone est la clé unique du compte
- Email = clé secondaire optionnelle (pour récupération)
- Pas de mot de passe au MVP (passwordless)

### Stack recommandé
- **Twilio Verify** pour OTP SMS (couvre toute l'Afrique francophone)
- **Resend** ou **Postmark** pour emails transactionnels
- **JWT** pour les sessions (refresh token 30j, access token 1h)

### Critères d'acceptation
- [ ] Un utilisateur peut s'inscrire en moins de 60 secondes
- [ ] L'OTP arrive en moins de 30 secondes dans 95% des cas
- [ ] Si SMS ne fonctionne pas, fallback email proposé après 90 sec d'attente
- [ ] Bouton "Skip" disponible mais désactivé pour les actions transactionnelles (demande, message)

---

## 5.2 M2 — Onboarding

### Description
Questionnaire post-auth de 6 étapes, conçu pour collecter les infos critiques sans frustrer. Skip toujours disponible.

### Logique
1. **Étape 1 — Tu es ?** (single select obligatoire)
   - Étudiant • Parent d'élève • Partenaire (école/agence)
2. **Étape 2 — Niveau d'études** (si étudiant)
   - Terminale • L1/Bachelor 1 • L2/Bachelor 2 • L3/Bachelor 3 • M1 • M2 • Doctorat
3. **Étape 3 — Série de bac** (si Terminale ou L1, optionnel sinon)
   - Liste : A, A1, A4, A8, B, C, D, E, F, F1, F2, F3, F4, G, G1, G2, PRO, Tech, Autre
   - → Détermine les centres d'intérêt suggérés (voir §5.4 Orientation IA)
4. **Étape 4 — Pays d'intérêt** (multi-select, optionnel)
   - Les 9 pays listés
5. **Étape 5 — Budget mensuel** (slider, optionnel)
   - 200 € à 2000 € — sert au simulateur et au matching
6. **Étape 6 — Notifications push** (autorisation OS)

### Critères d'acceptation
- [ ] Skip top-right présent à chaque étape (sauf étape 1)
- [ ] Si l'utilisateur skip tout, il accède à l'accueil avec un bandeau "Complète ton profil"
- [ ] Si l'utilisateur quitte l'app à l'étape 3, il reprend à l'étape 3 à la reconnexion
- [ ] Toutes les données sont sauvegardées progressivement (pas tout à la fin)

---

## 5.3 M3 — Profil utilisateur

### Données collectées
| Champ | Type | Source | Obligatoire |
|---|---|---|---|
| Téléphone | string | Auth | ✅ |
| Email | string | Auth ou profil | ❌ |
| Prénom | string | Profil | ❌ |
| Nom | string | Profil | ❌ |
| Type | enum | Onboarding | ✅ |
| Niveau d'études | enum | Onboarding | si étudiant |
| Série de bac | enum | Onboarding | si Terminale/L1 |
| Pays d'origine | string | Profil | ❌ |
| Ville actuelle | string | Profil | ❌ |
| Date de naissance | date | Profil | ❌ |
| Pays d'intérêt | array<enum> | Onboarding/profil | ❌ |
| Budget mensuel | int (EUR) | Onboarding/profil | ❌ |
| Domaines d'intérêt | array<string> | Orientation IA | ❌ |
| Documents | array<file> | Demandes | ❌ |
| Photo de profil | image | Profil | ❌ |

### Modules "Moi"
- **Mes favoris** : écoles + pays + bourses sauvegardés
- **Mes documents** : CV, passeport, relevés, lettres de motivation, etc. (upload + suppression)
- **Historique notifications** : 30 derniers jours
- **Paramètres** : notifs (par catégorie), confidentialité, suppression compte

---

## 5.4 M4 — Orientation IA

### Description
Module d'orientation pour aider l'utilisateur (surtout Terminale et L2/L3) à identifier des filières compatibles avec son profil, ses intérêts et sa série de bac.

### Architecture du module
1. **Questionnaire** (10-12 questions, conversationnel)
2. **Moteur de scoring** (algorithme + IA)
3. **Résultats** (3-5 filières recommandées avec explications)
4. **CTA** vers Recherche Universités ou Demande d'accompagnement

### Questions types
1. Ta série de bac (pré-rempli depuis profil si dispo)
2. Tes matières fortes (multi-select : maths, français, sciences, langues, sport, arts, etc.)
3. Tes centres d'intérêt en libre (NLP) — ex : "j'aime résoudre des problèmes, je m'intéresse à la santé"
4. Es-tu plutôt : seul/équipe • bureau/terrain • créer/exécuter • analyser/communiquer
5. Filières résilientes à l'IA — préoccupation ?
6. Pays d'études préférés (déjà dans profil)
7. Budget mensuel famille (déjà dans profil)
8. Combien d'années veux-tu étudier ? (2, 3, 5, 7+)
9. Niveau de langue (français + anglais)
10. Une chose que tu ne veux SURTOUT pas faire

### Logique de matching
- Croise les réponses avec :
  - Table `bac_interests_mapping` (séries de bac → centres d'intérêt potentiels — voir Annexe data)
  - Base filières (taxonomie 12-15 grands domaines)
  - Profil utilisateur
- Appel IA (GPT-4 ou Claude) pour générer les explications personnalisées du "pourquoi" de chaque recommandation
- Stockage du résultat dans `user_orientation_results` pour pouvoir y revenir

### Cas spéciaux à gérer
- **Filières résilientes à l'IA** : si l'utilisateur exprime cette préoccupation, prioriser les filières peu menacées (santé, métiers manuels qualifiés, ingénierie créative, métiers du soin/relationnel, etc.)
- **Filières en tension positive** : data, IA, cybersécurité, énergies renouvelables, santé spécialisée

### Critères d'acceptation
- [ ] Résultat en moins de 15 secondes après dernière réponse
- [ ] Au moins 3 filières recommandées avec explication "pourquoi cette filière te correspond"
- [ ] Chaque filière → cliquable vers liste d'écoles qui l'enseignent
- [ ] L'utilisateur peut refaire l'orientation autant de fois qu'il veut

### Prompt IA (template à utiliser)
```
Tu es un conseiller d'orientation expérimenté pour étudiants africains francophones.
Profil de l'étudiant :
- Niveau : {niveau}
- Série bac : {serie_bac}
- Matières fortes : {matieres}
- Centres d'intérêt : {interets_libre}
- Préférences : {prefs}
- Préoccupation IA : {preoccupation_ia}

Propose-lui 3 à 5 filières d'études compatibles avec son profil. Pour chaque filière :
1. Nom de la filière
2. Pourquoi elle correspond à ce profil (2 phrases max)
3. Métiers possibles à la sortie (3 exemples)
4. Résilience à l'IA (faible/moyenne/forte)
5. Pays partenaires KPB les plus pertinents pour cette filière

Réponds en JSON strict, en français. Ton chaleureux et clair, jamais condescendant.
```

---

## 5.5 M5 — Destinations

### Description
9 fiches pays avec contenu pédagogique + quiz d'éligibilité 1 clic + CTA accompagnement.

### Pays au lancement
| Pays | Rentrée | Spécificité |
|---|---|---|
| 🇫🇷 France | Septembre 2026 | **Écoles privées uniquement** au MVP (Campus France : "Bientôt disponible") |
| 🇩🇪 Allemagne | Septembre 2026 | Offre exclusive cours de langue 40 sem. |
| 🇺🇸 USA | Septembre 2026 | |
| 🇨🇦 Canada | **Janvier 2027** | Bourse McCall MacBain à mettre en avant |
| 🇲🇦 Maroc | Septembre 2026 | ISMAGI et ESA Casa partenaires |
| 🇹🇷 Turquie | Septembre 2026 | BAU Istanbul partenaire |
| 🇦🇪 EAU (Dubaï) | Septembre 2026 | GBS Dubai partenaire (anglais) |
| 🇬🇧 Royaume-Uni | **Janvier 2027** | Universités globalement |
| 🇪🇸 Espagne | Septembre 2026 | Schiller Madrid (anglais) |

### Structure d'une fiche pays
```
┌─────────────────────────────────────────────────┐
│ Hero (drapeau + image pays)                     │
│ Pays + tagline (ex: "Étudier au cœur de l'UE")  │
│ Badge rentrée + langue principale               │
├─────────────────────────────────────────────────┤
│ Bouton "Faire le quiz d'éligibilité" (gros CTA) │
├─────────────────────────────────────────────────┤
│ Section "Pourquoi ce pays ?"                    │
│ (3-5 raisons en bullets icônes)                 │
├─────────────────────────────────────────────────┤
│ Section "Comment ça se passe"                   │
│ (étapes 1-5 illustrées)                         │
├─────────────────────────────────────────────────┤
│ Section "Coûts"                                 │
│ - Frais de scolarité moyens                     │
│ - Coût de la vie mensuel                        │
│ - Visa & assurance                              │
├─────────────────────────────────────────────────┤
│ Section "Langue requise"                        │
│ - Niveau attendu                                │
│ - Tests acceptés                                │
│ - Exception si langue maternelle/scolaire       │
├─────────────────────────────────────────────────┤
│ Section "Écoles partenaires dans ce pays"       │
│ (Carrousel de cartes)                           │
├─────────────────────────────────────────────────┤
│ Section "Bourses disponibles" (si applicable)   │
├─────────────────────────────────────────────────┤
│ CTA "Demander un accompagnement"                │
│ Bouton WhatsApp en backup                       │
└─────────────────────────────────────────────────┘
```

### Quiz d'éligibilité (5-7 questions par pays)
**Logique** : 5-7 questions par pays + scoring → 3 verdicts possibles :
- ✅ **Tu es éligible** (vert) → CTA demande accompagnement
- 🟡 **Éligible sous conditions** (jaune) → liste conditions + CTA discuter avec conseiller
- ❌ **Pas éligible pour l'instant** (rouge) → explication + alternatives proposées

**Exemple France (écoles privées)** :
1. Quel est ton niveau d'études actuel ?
2. As-tu un baccalauréat (ou équivalent) ?
3. Quelles sont tes notes moyennes au bac (estimées) ?
4. Quel budget annuel (frais scolarité) peux-tu mobiliser ? (slider)
5. As-tu un parent ou tuteur en France ?
6. Quel est ton niveau de français ? (natif / courant / scolaire)
7. As-tu déjà refusé un visa ? (oui/non)

→ Voir Annexe `04_ANNEXE_DATA_SEED_PAYS.md` pour le quiz détaillé par pays.

### Critères d'acceptation
- [ ] Chaque fiche pays charge en moins de 2 secondes (cache local)
- [ ] Quiz éligibilité réalisable en moins de 90 secondes
- [ ] Verdict du quiz lié directement à la création d'une demande
- [ ] Bouton WhatsApp visible en bas de fiche pays
- [ ] Fiche France : section "Campus France" grisée avec "Disponible à partir de septembre 2026"

---

## 5.6 M6 — Recherche universités

### Description
Moteur de recherche d'établissements + programmes, avec mise en avant systématique des partenaires KPB.

### Filtres disponibles
- **Pays** (9 pays au MVP)
- **Budget annuel** (slider : 0-30 000 EUR)
- **Niveau** (Bachelor / Master / MBA / Doctorat / Autre)
- **Domaine** (12-15 catégories)
- **Langue d'enseignement** (FR / EN / FR-EN / DE / ES / AR / TR)
- **Statut partenaire** (toggle "Partenaires KPB uniquement")

### Sources de données initiales
- **748 programmes OMNES** (ECE, ESCE, HEIP, INSEEC, IUM, Sup de Pub) — fichier `OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx`
- **61 programmes** autres partenaires (ICN, Schiller, ISMAGI, ESA Casa, BAU Istanbul, GBS Dubai) — fichier `kpb_partner_schools_programs.xlsx`
- **Programmes non-partenaires** (à ajouter manuellement par admin pour les écoles tendances Allemagne, Espagne, UK, USA, Canada, Maroc, Turquie, EAU)

### Affichage liste
**Cartes empilées** avec :
- Logo école
- Nom programme
- Niveau + durée
- Frais annuels (devise locale + équivalent EUR)
- Langue d'enseignement (drapeau)
- Badge "Partenaire KPB ⭐" si applicable
- CTA "Voir détails"

### Fiche programme (détails)
```
┌─────────────────────────────────────────────────┐
│ Header : Logo + Nom programme + École           │
│ Badge Partenaire si applicable                  │
├─────────────────────────────────────────────────┤
│ Section "Le programme en bref"                  │
│ - Niveau + durée                                │
│ - Campus + pays                                 │
│ - Langue d'enseignement                         │
│ - Rentrée (date)                                │
├─────────────────────────────────────────────────┤
│ Section "Frais de scolarité"                    │
│ - Comptant + échelonné                          │
│ - Conversion FCFA approximative                 │
├─────────────────────────────────────────────────┤
│ Section "Conditions d'admission"                │
│ - Académiques                                   │
│ - Linguistiques                                 │
│ - Documents requis                              │
├─────────────────────────────────────────────────┤
│ Section "Processus de candidature"              │
│ Étapes 1-5                                      │
├─────────────────────────────────────────────────┤
│ CTA principal "M'inscrire avec KPB"             │
│ → Crée une demande pré-remplie avec ce programme│
│ Bouton secondaire WhatsApp                      │
└─────────────────────────────────────────────────┘
```

### Critères d'acceptation
- [ ] Recherche < 1 sec pour 750 programmes
- [ ] Tri par défaut : Partenaires d'abord, puis budget croissant
- [ ] Filtres persistent dans la session
- [ ] Devises affichées dans la monnaie d'origine + équivalent EUR + équivalent FCFA approximatif

---

## 5.7 M7 — Admission France écoles privées

### Description
Module dédié à la procédure d'inscription dans les écoles privées françaises pour la rentrée **septembre 2026**.

### Pourquoi un module dédié
La France = destination n°1 KPB. Procédure spécifique différente des autres pays. Mérite son propre tunnel UX.

### Structure
1. **Page d'intro France privé** : pourquoi le privé, différences avec public
2. **Étapes du processus** : 1) Choix école → 2) Dossier → 3) Admission → 4) Visa → 5) Logement → 6) Arrivée
3. **Liste des partenaires France privé** mis en avant :
   - OMNES Education (ECE, ESCE, HEIP, INSEEC, IUM, Sup de Pub)
   - IGENSIA Education
   - ICN Business School (Paris)
   - Schiller (Paris)
4. **CTA principal** : "Je commence ma procédure"

### Note importante
Le module Campus France (admission publique) doit être visible mais avec un badge "Bientôt disponible — Septembre 2026". L'utilisateur peut s'inscrire pour être notifié de l'ouverture.

---

## 5.8 M8 — Demandes d'accompagnement

### Description
Cœur business de l'app. Tunnel unifié pour soumettre une demande à KPB, peu importe le point d'entrée.

### Points d'entrée multiples
- Bouton "Demander un accompagnement" sur fiche pays
- Bouton "M'inscrire avec KPB" sur fiche programme
- CTA résultat quiz éligibilité positif
- Lien profil bourse (ex: McCall MacBain)
- CTA depuis Coach IA après recommandation
- Bouton flottant "+ Nouvelle demande" depuis l'onglet Demandes

### Formulaire de demande (5 étapes)
1. **Type de demande** : Inscription école / Bourse / Visa / Logement / Autre
2. **Contexte pré-rempli** : pays / école / programme selon le point d'entrée
3. **Mes documents** : upload CV, relevés notes, passeport (optionnel à cette étape)
4. **Message** : description libre (textarea + voice-to-text si possible)
5. **Confirmation** : récap + bouton "Soumettre"

### Après soumission
- Création d'une `Demande` avec statut `Soumise`
- Round-robin → attribution à un commercial (Jojo, Donald ou Richard)
- Notification push à l'utilisateur : "Ta demande est reçue, {commercial} va te contacter sous peu"
- Notification push au commercial : "Nouvelle demande : {type} pour {pays} de {prénom}"

### Statuts possibles
| Statut | Couleur | Description |
|---|---|---|
| 🔵 Soumise | bleu | Demande envoyée, en attente d'attribution |
| 🟣 Attribuée | violet | Un conseiller est désigné |
| 🟡 En revue | jaune | Conseiller analyse le dossier |
| 🟠 Documents manquants | orange | Besoin de pièces complémentaires |
| 🟢 En cours | vert | Traitement opérationnel |
| 🔷 Soumise à l'institution | cyan | Dossier envoyé à l'école |
| ⚪ En attente paiement | gris | Service à valider par paiement |
| ✅ Acceptée | vert foncé | Admission obtenue |
| ❌ Refusée | rouge | Admission refusée |
| 🔒 Clôturée | gris foncé | Flux terminé |

### Bouton WhatsApp backup
Sur chaque fiche demande, un bouton "Réponse rapide via WhatsApp" qui ouvre WhatsApp avec un message pré-rempli :
```
Bonjour KPB, je suis {prenom} ({user_id}), j'ai une demande #{id} pour {type}/{pays}. Pouvez-vous me répondre rapidement ? Merci !
```
Numéro WhatsApp à configurer en variable d'environnement (`KPB_WHATSAPP_NUMBER`).

### Critères d'acceptation
- [ ] Création d'une demande en < 90 secondes
- [ ] Round-robin équitable mathématiquement (compteur par commercial)
- [ ] Notification push au commercial < 5 sec après soumission
- [ ] L'utilisateur voit le statut de sa demande à tout moment dans l'onglet Demandes

---

## 5.9 M9 — Système commerciaux (round-robin + chat)

### Description
Système d'attribution équitable des leads aux 3 commerciaux KPB + chat intégré dans l'app.

### Équipe au lancement
- **Jojo** (commercial 1)
- **Donald** (commercial 2)
- **Richard** (commercial 3)

### Algorithme round-robin
**Principe** : pour chaque nouvelle demande, attribuer au prochain commercial dans la rotation.

**État stocké en DB** :
```
table: round_robin_state
- last_assigned_commercial_id: int
- updated_at: timestamp
```

**Logique** :
```
1. Récupérer last_assigned_commercial_id
2. Récupérer liste des commerciaux ACTIFS (status = 'active')
3. Identifier le prochain dans la rotation
4. Attribuer la demande à ce commercial
5. Mettre à jour last_assigned_commercial_id
```

### Règle de réattribution automatique (CRITIQUE)
**Trigger** : si un commercial ne fait **aucune interaction** sur une demande dans les **10 heures** suivant son attribution :
- La demande est **automatiquement transférée** au commercial **le plus réactif** (celui avec le temps moyen de 1ère réponse le plus court sur les 30 derniers jours)
- Notification au commercial original : "Demande #{id} transférée à {nouveau_commercial} pour non-réactivité"
- Notification au nouveau commercial : "Tu reçois une demande transférée — réagis vite !"
- Notification à l'admin : "Réattribution automatique : {ancien} → {nouveau}"

### Système d'étiquettes (liste fermée)
Chaque demande peut recevoir une étiquette par le commercial :
- 🟢 **Qualifié** : client sérieux, conversion probable
- 🔴 **Non qualifié** : pas le bon profil, à archiver
- 🟡 **En attente paiement** : devis envoyé, attente règlement
- 💎 **Converti** : a payé, client actif
- ⚫ **Perdu** : a abandonné / refusé
- 🔵 **À relancer** : pas de réponse, relance prévue

Le commercial doit aussi écrire un **motif de discussion** (court, max 100 char) qui apparaîtra devant le nom du client dans sa vue "Mes leads".

### Vue commercial — Onglet "Mes Leads"
```
┌──────────────────────────────────────────────┐
│ Filtres : Tous | Nouveaux | Aujourd'hui | ⭐ │
├──────────────────────────────────────────────┤
│ 🟢 Marie Diallo · 23 ans · L3 Économie       │
│ "Master Marketing France — budget OK"         │
│ Demande #1234 · il y a 2 h · Qualifié         │
├──────────────────────────────────────────────┤
│ 🟡 Issa Kone · 18 ans · Terminale C          │
│ "Inscription ECE Lyon — paiement à confirmer" │
│ Demande #1233 · hier · En attente paiement    │
├──────────────────────────────────────────────┤
│ 🔴 Anonyme · 16 ans                          │
│ "Demande imprécise, pas sérieuse"            │
│ Demande #1232 · il y a 3 j · Non qualifié    │
└──────────────────────────────────────────────┘
```

### Chat intégré (in-app)
- Chat en temps réel commercial ↔ client
- Support texte + image + document
- Statuts : envoyé / lu / répondu
- Notifications push des deux côtés
- Historique conservé tant que la demande n'est pas clôturée

### Stack recommandé
- **Firebase Realtime DB** ou **Supabase Realtime** pour le chat
- **Firebase Cloud Messaging (FCM)** pour notifs push

### Critères d'acceptation
- [ ] Round-robin parfaitement équilibré (vérifiable par script)
- [ ] Réattribution auto à 10h testée et fonctionnelle
- [ ] Le commercial reçoit la notif push en < 5 sec
- [ ] Étiquettes visibles par admin pour reporting
- [ ] Vue commercial = pas plus de 3 clics pour répondre à un client

---

## 5.10 M10 — Coach IA conversationnel

### Description
Chatbot IA toujours accessible via bouton flottant, qui aide l'utilisateur sur ses questions d'orientation / pays / budget.

### Quotas (logique freemium)
- **Gratuit** : 5 messages par semaine (reset le lundi 00h00 UTC+0)
- **Premium V2** : illimité (paiement à venir)

### Bouton flottant
- Position : bas droite
- Icône : 🤖 sur fond orange KPB
- Visible sur tous les écrans (sauf chat actif)
- Animation pulse douce toutes les 5 sec si l'utilisateur n'a jamais parlé au coach

### Interface chat
```
┌───────────────────────────────────────┐
│ ← Coach KPB                  3/5 cette semaine │
├───────────────────────────────────────┤
│                                       │
│ 🤖 Salut Marie ! Je suis le coach    │
│    KPB. Je peux t'aider à choisir    │
│    une école, un pays, ou comprendre │
│    ton budget. Par où veux-tu        │
│    commencer ?                       │
│                                       │
│         Quel pays choisir ? →        │
│         Combien ça coûte ? →         │
│         Comment je m'inscris ? →     │
│                                       │
└───────────────────────────────────────┘
```

### Suggestions dynamiques (boutons)
Toujours afficher 3 suggestions contextuelles selon l'écran d'origine et le profil :
- "Quel pays pour mon budget ?"
- "Les meilleures écoles tech ?"
- "Comment je m'inscris ?"
- "C'est quoi McCall MacBain ?"

### Système de prompts
**System prompt** :
```
Tu es le Coach KPB, un conseiller virtuel pour étudiants africains francophones qui veulent étudier à l'étranger.

CONTEXTE UTILISATEUR :
- Prénom : {prenom}
- Niveau : {niveau}
- Pays d'intérêt : {pays}
- Budget mensuel : {budget}
- Demandes en cours : {demandes}

RÈGLES :
1. Réponds toujours en français, ton chaleureux et direct
2. Reste factuel — si tu ne sais pas, propose à l'utilisateur de parler à un conseiller humain KPB
3. Tu connais les 9 destinations KPB (France, Allemagne, USA, Canada, Maroc, Turquie, EAU, UK, Espagne)
4. Tu connais les écoles partenaires KPB
5. Tu pousses subtilement vers la création d'une demande quand le besoin est concret
6. Tu ne donnes JAMAIS de conseils juridiques ou financiers précis (recommande un conseiller humain)
7. Tu ne mentionnes JAMAIS d'écoles concurrentes de KPB sauf si la question l'exige
8. Maximum 4 phrases par réponse (interface mobile)
9. Si l'utilisateur exprime une émotion forte ou détresse, redirige vers un humain

QUAND PROPOSER UNE DEMANDE D'ACCOMPAGNEMENT :
- L'utilisateur a un projet précis (pays + niveau + filière)
- L'utilisateur demande "comment faire concrètement"
- L'utilisateur est éligible à une bourse
- L'utilisateur a un budget cohérent avec un programme partenaire
```

### Garde-fous
- Limite de tokens par message (input < 500, output < 300)
- Filtre sur les contenus inappropriés
- Pas d'engagement contractuel par le bot
- Disclaimer en bas de chat : "Le coach IA est un assistant — pour les décisions importantes, contacte un conseiller humain KPB."

### Critères d'acceptation
- [ ] Première réponse < 4 sec
- [ ] Streaming des tokens (réponse qui s'écrit progressivement)
- [ ] Quota visible en haut de l'écran chat
- [ ] Bandeau "Premium bientôt dispo" affiché quand quota atteint
- [ ] Historique conservé 90 jours

### Stack recommandé
- **API Claude (Anthropic)** ou **OpenAI GPT-4o-mini** (rapport qualité/prix)
- Coût estimé : < 0.01 USD par message gratuit (avec gpt-4o-mini ou claude-3-5-haiku)

---

## 5.11 M11 — Simulateur de budget

### Description
Outil qui aide étudiants et parents à savoir dans quels pays ils peuvent partir étudier en fonction de leur budget familial.

### Inputs
1. **Budget total annuel disponible** (slider : 1 000 à 30 000 EUR)
2. **Durée d'études prévue** (1, 2, 3, 5 ans)
3. **Niveau visé** (Bachelor / Master / Doctorat)
4. **Tolérance prêt étudiant** (oui / non / partiellement)
5. **Travail étudiant possible ?** (oui / non / pas sûr)

### Output
**Carte par pays** avec :
- 🟢 **Accessible** (budget couvre confortablement)
- 🟡 **Tendu mais possible** (budget juste, avec travail étudiant)
- 🔴 **Inaccessible** (budget trop bas pour ce pays)

**Détail par pays** :
- Frais scolarité moyens (privé + public partenaires)
- Coût vie mensuel
- Total estimé année 1
- Total estimé cursus complet
- Possibilités de travail étudiant
- Bourses pertinentes (si applicable)

### Logique de calcul
```python
for country in 9_countries:
    tuition_min = country.min_tuition_per_year
    tuition_avg = country.avg_tuition_per_year
    living_cost = country.monthly_living_cost * 12
    total_year_avg = tuition_avg + living_cost
    total_cursus = total_year_avg * duration

    if budget_total >= total_cursus * 1.1:
        status = "Accessible"
    elif budget_total + (work_capacity * duration) >= total_cursus:
        status = "Tendu mais possible"
    else:
        status = "Inaccessible"

    # Score finance ranking
```

→ Voir données budget par pays dans `04_ANNEXE_DATA_SEED_PAYS.md`

### CTA en bas
- "Voir les écoles partenaires accessibles" → filtre direct sur Universités
- "Discuter avec un conseiller" → Coach IA ou Demande

### Critères d'acceptation
- [ ] Calcul instantané (< 500ms)
- [ ] Conversion automatique en FCFA pour utilisateurs Afrique de l'Ouest
- [ ] Les résultats peuvent être sauvegardés dans le profil
- [ ] Possibilité de générer un PDF "Mon plan de budget" partageable

---

## 5.12 M12 — Bourses

### Description
Module bourses avec **affichage discret** (pas mis en avant) et logique d'ajout dynamique par l'admin pour toute nouvelle bourse pertinente ouvrant **avant septembre 2026**.

### Stratégie
KPB ne se positionne **pas** comme spécialiste des bourses (focus business = admissions payantes). Mais le module existe pour :
1. Crédibilité (l'app couvre quand même les bourses pertinentes)
2. SEO interne et fidélisation
3. Conversion vers accompagnement KPB sur les bourses éligibles

### Au lancement (MVP)
- **1 bourse principale** : **McCall MacBain Scholarship** (McGill University, Montréal)
  - Master tous domaines
  - Couvre frais de scolarité + allocation
  - Critères : leadership, engagement communautaire, excellence académique
  - Test d'éligibilité dédié (cf. quiz pays)
  - CTA "Demander un accompagnement McCall MacBain"

### Logique d'ajout dynamique
L'admin (web app) peut ajouter de nouvelles bourses à tout moment via le back-office. Chaque bourse a :
- Nom + organisme
- Pays
- Niveau visé
- Montant / couverture
- Date d'ouverture & date limite
- Critères d'éligibilité (texte + quiz optionnel)
- Description complète
- Image / logo
- Statut : Brouillon / Active / Expirée

### Affichage in-app
- **Onglet "Bourses"** dans l'écran "Moi" ou via un sub-menu
- Pas de carrousel en accueil sauf si bourse vraiment phare (poussée par admin via notif)
- Filtres : Pays / Niveau / Domaine

### Critères d'acceptation
- [ ] Admin peut publier/dépublier une bourse en 2 minutes
- [ ] Bourse McCall MacBain présente au lancement avec test d'éligibilité fonctionnel
- [ ] Notification push automatique aux utilisateurs éligibles quand une nouvelle bourse correspond à leur profil

---

## 5.13 M13 — Notifications push + Admin cloud

### Description
Système de notifications push avec back-office web pour l'admin (Aminou) pour piloter les comms et le monitoring.

### Sources de notifications

#### Notifications transactionnelles (automatiques)
- Demande soumise → "Ta demande est bien reçue"
- Demande attribuée → "{Prénom commercial} prend en charge ta demande"
- Nouveau message commercial → "{Prénom} t'a répondu"
- Statut demande changé → "Ta demande passe en {statut}"
- Réattribution automatique → admin notifié

#### Notifications campagnes (manuelles par admin)
Catégories paramétrables :
- 📚 Nouvelle bourse disponible
- 📝 Nouvel article blog
- 🎥 Nouvelle vidéo YouTube / TikTok
- 🔴 Live à venir
- 🎓 Nouvelle école partenaire
- 💡 Astuce du jour
- 🚀 Annonce générale

### Segmentation des notifications
Quand l'admin crée une notif manuelle, il peut **choisir une cible** :
- **Tous les utilisateurs**
- **Par persona** (Étudiants / Parents / Partenaires)
- **Par niveau d'études** (Terminale / L1-L3 / M1-M2 / Doctorat)
- **Par pays d'intérêt** (ex : seulement ceux intéressés par le Canada)
- **Par centre d'intérêt** (ex : seulement ceux qui ont fait l'orientation "Tech")
- **Personnalisée** (filtre custom multi-critères)

### Sources de contenu auto-détecté (V1.1, mais à préparer)
- **YouTube API** : webhook quand une nouvelle vidéo est postée sur la chaîne KPB → notif auto
- **TikTok** : pas d'API publique fiable → upload manuel par admin
- **Live YouTube / TikTok** : déclenchement manuel par admin
- **Articles blog** : déclenchement auto à la publication

### Back-office web admin
**URL** : `admin.kpbeducation.app` (ou sous-domaine selon DNS)

**Modules du back-office** :
1. **Dashboard** : KPIs en temps réel (utilisateurs actifs, demandes du jour, taux conversion, etc.)
2. **Utilisateurs** : liste, filtres, fiches détaillées
3. **Demandes** : suivi de toutes les demandes + réassignation manuelle possible
4. **Commerciaux** : performance Jojo/Donald/Richard (temps réponse, taux conversion, leads traités)
5. **Contenus** : gestion blog, vidéos, bourses
6. **Notifications** : composer + planifier + historique
7. **Établissements** : gestion partenaires + ajout de programmes
8. **Paramètres système** : limites IA, round-robin, etc.

**Monitoring crucial pour Aminou** :
- Temps moyen de 1ère réponse par commercial
- Taux d'étiquetage par commercial
- Nombre de demandes converties par commercial
- Taux d'utilisation du Coach IA
- Top pays / écoles consultées
- Taux de complétion onboarding
- Heatmap d'usage (heures de pointe)

### Stack recommandé
- **FCM (Firebase Cloud Messaging)** pour les notifs push iOS + Android
- **Next.js / React** pour le back-office web
- **Recharts / Tremor** pour les dashboards

### Critères d'acceptation
- [ ] Délai d'arrivée des notifs < 10 sec en condition normale
- [ ] Admin peut créer une campagne en moins de 3 minutes
- [ ] Toutes les notifs sont logées (qui a reçu, qui a ouvert, qui a cliqué)
- [ ] Dashboard admin se met à jour en temps réel (websocket ou polling 30s)

---

## 5.14 M14 — Mes demandes (timeline)

### Description
Onglet permettant à l'utilisateur de suivre l'état de toutes ses demandes en cours.

### Vue liste
Cartes empilées avec :
- Type de demande (avec icône)
- Statut (badge coloré)
- Date soumission
- Conseiller attribué (avatar + prénom)
- Indicateur "Nouveau message" si non-lu

### Vue détail demande
```
┌─────────────────────────────────────────────┐
│ ← Demande #1234                             │
│ Inscription ECE Lyon — Bachelor 1           │
├─────────────────────────────────────────────┤
│ Timeline visuelle :                         │
│ ✅ Soumise (le 22/05)                       │
│ ✅ Attribuée à Jojo (le 22/05)              │
│ 🔄 En revue (depuis le 23/05)               │
│ ⏸  En cours                                 │
│ ⏸  Soumise à ECE                            │
│ ⏸  Acceptée                                 │
├─────────────────────────────────────────────┤
│ 📁 Documents (3)                            │
│ - CV.pdf                                    │
│ - Releve_terminale.pdf                      │
│ - Passeport.jpg                             │
│ [+ Ajouter un document]                     │
├─────────────────────────────────────────────┤
│ 💬 Chat avec Jojo (2 messages non lus)      │
├─────────────────────────────────────────────┤
│ Bouton WhatsApp                             │
└─────────────────────────────────────────────┘
```

### Critères d'acceptation
- [ ] Mise à jour temps réel quand statut change
- [ ] Badge rouge sur onglet Demandes si nouveau message non lu
- [ ] Upload document fonctionne avec compression auto images
- [ ] Chat conservé même après clôture demande (historique)

---

## 5.15 M15 — Exemples de parcours (V1.1)

### Description
Galerie de parcours inspirants d'étudiants africains, basée sur les **vidéos de la chaîne YouTube KPB**.

### Source de données
Fichier `Exemple_de_parcours_Vide_os.xlsx` avec :
- Titre vidéo
- Tags / métiers
- Lien YouTube
- Résumé du contenu

### Structure d'affichage
**Vue liste**, organisée par catégorie de métier :
- 🔬 Sciences & Recherche
- 💻 Tech & Informatique
- 🏥 Médecine & Santé
- ⚖️ Droit
- 💼 Business & Finance
- 🏗️ Ingénierie
- 🎨 Arts & Création
- 🌍 Autres

**Carte vidéo** :
- Thumbnail YouTube (via API : `https://img.youtube.com/vi/{video_id}/hqdefault.jpg`)
- Titre
- Tags
- Résumé court (2-3 lignes)
- Bouton "Voir sur YouTube" → ouvre l'app YouTube ou navigateur

### CTA en bas de chaque vidéo
"Tu veux suivre un parcours similaire ? Discute avec KPB →" (lance Coach IA ou crée demande)

### Extraction des `video_id`
À partir des URLs du fichier :
- `https://www.youtube.com/watch?v=XYZ` → `XYZ`
- `https://youtu.be/XYZ` → `XYZ`
- `https://youtube.com/live/XYZ` → `XYZ`

### Critères d'acceptation
- [ ] Au moins 40 vidéos importées au lancement
- [ ] Thumbnail s'affiche correctement
- [ ] Lien YouTube s'ouvre dans l'app si installée, sinon navigateur
- [ ] Tri possible par : récent / catégorie / popularité

---

## 5.16 M16 — Blog (V1.1)

### Description
Module éditorial pour publier des articles longs sur l'orientation, les pays, les bourses.

### Fonctionnalités
- Liste d'articles (avec image, titre, extrait, date, auteur)
- Catégories : Orientation, Pays, Bourses, Tips, Vie étudiante
- Fiche article (Markdown rendu + commentaires optionnels V2)
- Partage social

### Back-office
Admin peut publier un article via éditeur WYSIWYG (TipTap, Lexical ou similar).

---

## 5.17 M17 — Forum communautaire (V2)

### Description
Espace de discussion entre utilisateurs avec création libre de threads et modération IA automatique.

### Catégories obligatoires lors de la création de thread
1. **Catégorie principale** (single select) :
   - Par pays (France, Allemagne, USA, Canada, Maroc, Turquie, EAU, UK, Espagne)
   - Transverse : Admission / Visa / Logement / Vie étudiante / Bourses / Orientation
2. **Description courte** (obligatoire, 20-200 caractères)

### Modération IA automatique
À chaque post (thread ou réponse), un check IA :
- Détection spam
- Détection contenu haineux / discriminatoire
- Détection promotion de services concurrents
- Détection partage d'infos personnelles (numéros, emails)

**Verdict IA** :
- ✅ OK → publié immédiatement
- ⚠️ Suspect → publié + flagué pour review humaine
- 🚫 Refusé → bloqué + notif utilisateur

### Critères d'acceptation
- [ ] Modération IA en moins de 3 sec après envoi
- [ ] Utilisateur peut signaler un post (queue review humaine)
- [ ] Admin peut bannir un utilisateur du forum

---

## 5.18 M18 — Scraping logements France (V2)

⚠️ **À traiter avec prudence — risques juridiques**

### Stratégie alternative recommandée
Au lieu du scraping, négocier des **partenariats d'affiliation** avec :
- Studapart
- Adele
- LogementEtudiant.com
- Lokaviz

Avantages :
- API officielle = données stables
- Commission par lead
- Pas de risque juridique

### Si scraping malgré tout
- Vérifier `robots.txt` de chaque site
- Respecter les rate limits
- Ne pas reproduire la structure du site (juste lien sortant)
- Prévoir un budget maintenance fort (HTML qui change)

---

## 5.19 M19 — Coach IA Premium (V2)

### Description
Levée de la limite des 5 messages/semaine via paiement.

### Modèles tarifaires à explorer
- **Premium hebdo** : 1 000 FCFA / semaine, illimité
- **Premium mois** : 3 500 FCFA / mois, illimité
- **Premium annuel** : 30 000 FCFA / an, illimité + bonus

### Stack paiement
- **Wave** (Afrique de l'Ouest)
- **Orange Money / MTN Money**
- **Stripe** (cartes internationales)

---

# 6. SPÉCIFICATIONS TECHNIQUES

## 6.1 Stack recommandée

### Mobile
- **Flutter** ou **React Native** (Antigravity choisit selon ses préférences — Flutter recommandé pour la perf)
- Build pour Android (priorité 1) + iOS (priorité 2)

### Backend
- **Node.js + Express** ou **Python + FastAPI**
- **PostgreSQL** (DB principale)
- **Redis** (cache + sessions + queues)

### Realtime
- **Firebase Realtime DB** ou **Supabase Realtime** (chat)
- **FCM** (notifications push)

### Stockage fichiers
- **Cloudflare R2** ou **AWS S3** (documents users, photos profil)

### IA
- **Anthropic Claude (claude-3-5-haiku ou sonnet)** ou **OpenAI GPT-4o-mini**
- Pour le Coach IA + Orientation IA + Modération forum

### Auth
- **Twilio Verify** (OTP SMS)
- **Resend** (emails transactionnels)
- **Jose / jsonwebtoken** (JWT)

### Hébergement
- Backend : **Railway**, **Render** ou **Fly.io**
- DB : **Supabase** ou **Neon**
- Admin web : **Vercel**

### Monitoring
- **Sentry** (erreurs)
- **PostHog** (analytics produit)

## 6.2 Sécurité

- HTTPS partout (TLS 1.3)
- Rate limiting sur tous les endpoints (100 req/min/user par défaut)
- Validation stricte des inputs (Zod ou Pydantic)
- Sanitisation des contenus user-generated (forum, chat)
- Tokens JWT signés avec rotation
- Stockage chiffré des documents sensibles
- Pas de stockage de mots de passe (passwordless)
- Logs anonymisés (RGPD-friendly)

## 6.3 Performance

- **API p95 < 200ms** pour 95% des endpoints
- **Time to interactive mobile** < 2 sec sur 3G
- **Bundle size mobile** < 30 MB
- **Images** : lazy load + compression auto (WebP)
- **Cache local agressif** (sqlite ou Hive pour Flutter)

## 6.4 Offline-first (basique)

- L'app doit pouvoir :
  - Afficher les fiches pays consultées récemment hors ligne
  - Afficher les écoles favorites hors ligne
  - Afficher les demandes en cours hors ligne
  - Composer une demande hors ligne (sync à la reconnexion)

---

# 7. DESIGN SYSTEM (résumé)

→ Voir détails complets dans `03_ANNEXE_DESIGN_SYSTEM.md`

## 7.1 Couleurs principales

| Nom | Hex | Usage |
|---|---|---|
| **KPB Orange** | `#E8593C` | Couleur primaire, CTAs |
| **KPB Orange Light** | `#FFE8E2` | Backgrounds doux |
| **KPB Dark** | `#1A1A2E` | Textes principaux |
| **KPB Gray** | `#6B7280` | Textes secondaires |
| **KPB Light** | `#F9FAFB` | Backgrounds cards |
| **Success** | `#22C55E` | Statuts positifs |
| **Warning** | `#F59E0B` | Statuts intermédiaires |
| **Error** | `#EF4444` | Statuts négatifs |

## 7.2 Typographie

- **Police principale** : Inter ou Plus Jakarta Sans (lisibilité mobile + caractères français)
- **Hierarchy** :
  - H1 : 28px, bold
  - H2 : 22px, semibold
  - H3 : 18px, semibold
  - Body : 16px, regular
  - Caption : 14px, regular
  - Label : 12px, medium

## 7.3 Composants clés
- Cartes (border-radius 16px, shadow douce)
- Boutons primaires (orange plein, border-radius 12px)
- Inputs (border 1px, focus orange)
- Bottom nav (background blanc, icônes outline)
- Badges (border-radius 8px, padding 4px 8px)

## 7.4 Ton de voix
- Tutoiement systématique
- Phrases courtes (15 mots max)
- Pas de jargon
- Encourageant et chaleureux, jamais condescendant
- Émojis avec parcimonie (jamais en début de phrase, jamais 2 d'affilée)

---

# 8. ROADMAP & PRIORISATION

## 8.1 Sprint MVP (3 semaines réalistes)

### Semaine 1 : Foundation
- [ ] Setup infra (DB, auth, hosting)
- [ ] Module M1 (Auth OTP)
- [ ] Module M2 (Onboarding)
- [ ] Module M3 (Profil)
- [ ] Design system de base
- [ ] Seed data initiale (9 pays + partenaires)

### Semaine 2 : Cœur métier
- [ ] Module M5 (Destinations)
- [ ] Module M6 (Recherche universités)
- [ ] Module M7 (Admission France privé)
- [ ] Module M8 (Demandes d'accompagnement)
- [ ] Module M14 (Mes demandes timeline)

### Semaine 3 : Intelligence + commerciaux
- [ ] Module M4 (Orientation IA)
- [ ] Module M9 (Système commerciaux + round-robin)
- [ ] Module M10 (Coach IA)
- [ ] Module M11 (Simulateur budget)
- [ ] Module M12 (Bourses + McCall MacBain)
- [ ] Module M13 (Notifications + back-office admin)
- [ ] Tests + ajustements + déploiement

## 8.2 V1.1 (Semaines 4-7)
- [ ] M15 Exemples de parcours
- [ ] M16 Blog
- [ ] Ajout de plus d'écoles non-partenaires (recherche)
- [ ] Améliorations UX selon premiers feedbacks

## 8.3 V2 (Mois 2-3)
- [ ] M17 Forum communautaire
- [ ] M18 Logements (via partenariats, pas scraping)
- [ ] M19 Coach IA Premium (paiement)
- [ ] Version anglophone (projet séparé)

---

# 9. CRITÈRES D'ACCEPTATION GLOBAUX

## 9.1 Tests à passer avant le lancement

### Tests fonctionnels
- [ ] Un nouvel utilisateur peut créer un compte et soumettre une demande en moins de 5 minutes
- [ ] Un commercial reçoit une notif et peut répondre dans l'app
- [ ] La réattribution auto à 10h fonctionne en condition réelle
- [ ] Le Coach IA répond correctement aux 20 questions test du fichier QA
- [ ] L'orientation IA produit des résultats cohérents sur 10 profils tests

### Tests UX
- [ ] Test utilisateur avec 5 personnes (3 étudiants, 2 parents) — taux de complétion onboarding > 70%
- [ ] Temps de chargement < 3 sec sur connexion 3G dégradée
- [ ] L'app fonctionne sur Android 8+ et iOS 14+

### Tests business
- [ ] Round-robin parfaitement équilibré sur 30 demandes test
- [ ] Pipeline demande → conversion fonctionne de bout en bout
- [ ] Admin peut sortir un rapport hebdo en 2 minutes

## 9.2 Critères de qualité code (pour Antigravity)

- [ ] Code commenté en français pour la logique métier
- [ ] Architecture modulaire (un dossier par module)
- [ ] Tests unitaires sur les fonctions critiques (round-robin, scoring, etc.)
- [ ] CI/CD automatisé (build + tests sur chaque push)
- [ ] Documentation technique à jour (README + ARCHITECTURE.md)

---

# 10. POINTS D'ATTENTION CRITIQUES

## 10.1 Risques identifiés

| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| Timeline 1 semaine impossible | 🔴 Haute | 🔴 Critique | **Accepter 3 semaines pour MVP solide** |
| Coût IA dérive à grande échelle | 🟡 Moyenne | 🟠 Haut | Cache + limite tokens + modèles moins chers |
| OTP SMS coûteux en Afrique | 🟡 Moyenne | 🟡 Moyen | Tarification Twilio négociée + email fallback |
| Round-robin pas équitable | 🟢 Basse | 🟠 Haut | Tests unitaires stricts + dashboard admin |
| Scraping logements illégal | 🔴 Haute | 🟠 Haut | **Pivot vers partenariats d'affiliation** |
| Données partenaires obsolètes | 🟡 Moyenne | 🟡 Moyen | Mise à jour trimestrielle + dates de fraîcheur visibles |

## 10.2 Décisions à ne PAS modifier
- ⚠️ **L'app commerciale = la même app mobile que les étudiants** (avec rôle différent)
- ⚠️ **Téléphone + OTP = méthode principale** (pas email-first)
- ⚠️ **9 pays seulement au lancement** (pas plus, pas moins)
- ⚠️ **France privé uniquement** (pas Campus France au MVP)
- ⚠️ **Coach IA = 5 messages/semaine** (gratuit)
- ⚠️ **Round-robin Jojo → Donald → Richard** + réattribution 10h
- ⚠️ **Français only** au MVP

## 10.3 Choses à NE PAS faire
- ❌ Mettre en avant les bourses (focus business = admissions payantes)
- ❌ Mettre Campus France dans le MVP France
- ❌ Faire 1 seule app étudiant et 1 séparée commercial (1 seule app)
- ❌ Mettre l'IA en mode "expert" (toujours rediriger vers humain pour décisions critiques)
- ❌ Lancer un back-office complexe — l'admin doit pouvoir tout faire en 3 clics max
- ❌ Tomber dans le piège du "tout-faire" — chaque V doit avoir un scope tenu

---

# 11. ANNEXES À CONSULTER

Pour compléter ce document maître, lis impérativement :

1. **`01_ANNEXE_PERSONAS_USER_STORIES.md`** — Personas détaillés + user stories par module
2. **`02_ANNEXE_MODELE_DONNEES.md`** — Schéma DB complet (toutes les tables)
3. **`03_ANNEXE_DESIGN_SYSTEM.md`** — Design system détaillé
4. **`04_ANNEXE_DATA_SEED_PAYS.md`** — 9 fiches pays complètes + quizz
5. **`05_ANNEXE_DATA_SEED_PARTENAIRES.md`** — Partenaires + programmes (hors OMNES en xlsx)
6. **`06_ANNEXE_API_ENDPOINTS.md`** — Liste exhaustive des endpoints REST

---

**FIN DU DOCUMENT MAÎTRE**
