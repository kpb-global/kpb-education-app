# 🎨 ANNEXE 03 — DESIGN SYSTEM

**Référence** : Cahier des charges KPB Education V1
**Usage** : Référentiel design pour le frontend (Flutter / React Native)

---

# 1. PRINCIPES DIRECTEURS

## 1.1 Philosophie

Le design KPB Education suit 5 principes fondamentaux :

1. **Mobile-first absolu** — chaque écran est pensé pour un smartphone Android entrée de gamme
2. **Confiance & crédibilité** — un jeune Africain doit sentir qu'il a affaire à une institution sérieuse, pas à une app gadget
3. **Chaleur africaine** — le ton, les couleurs, les visuels doivent évoquer la communauté et la chaleur, pas le froid corporate
4. **Action visible** — chaque écran doit avoir un CTA évident, pour ne pas perdre l'utilisateur
5. **Simplicité radicale** — zéro élément décoratif inutile, zéro jargon

## 1.2 Inspirations

| Source | Ce qu'on emprunte |
|---|---|
| Yocket | Structure orientation + admissions |
| Revolut | Onboarding rapide, micro-interactions |
| Duolingo | Gamification légère, encouragement |
| Notion mobile | Sobriété typographique |
| Apple Health | Cartes empilées lisibles |

## 1.3 Ce qu'on EVITE

- ❌ Le tout-orange flashy (l'orange est l'accent, pas le fond)
- ❌ Les illustrations 3D génériques (préférer photos réelles d'étudiants africains)
- ❌ Les écrans surchargés
- ❌ Les animations gourmandes (cible bande passante limitée)
- ❌ Les modales bloquantes (préférer bottom sheets)

---

# 2. COULEURS

## 2.1 Palette principale

| Token | Hex | Usage |
|---|---|---|
| `--kpb-orange` | `#E8593C` | Couleur primaire de marque, CTAs, accents |
| `--kpb-orange-dark` | `#C44529` | Hover/pressed states sur orange |
| `--kpb-orange-light` | `#FFE8E2` | Backgrounds doux, badges |
| `--kpb-orange-50` | `#FFF5F2` | Backgrounds ultra légers |
| `--kpb-dark` | `#1A1A2E` | Textes principaux, headlines |
| `--kpb-dark-soft` | `#2D2D44` | Sous-titres |
| `--kpb-gray-900` | `#111827` | Textes très foncés |
| `--kpb-gray-700` | `#374151` | Textes secondaires |
| `--kpb-gray-500` | `#6B7280` | Textes tertiaires, métadonnées |
| `--kpb-gray-300` | `#D1D5DB` | Borders |
| `--kpb-gray-100` | `#F3F4F6` | Backgrounds cards |
| `--kpb-gray-50` | `#F9FAFB` | Background principal app |
| `--kpb-white` | `#FFFFFF` | Surfaces, cards |

## 2.2 Couleurs sémantiques

| Token | Hex | Usage |
|---|---|---|
| `--success` | `#22C55E` | Statuts positifs, validations |
| `--success-light` | `#DCFCE7` | Backgrounds success |
| `--warning` | `#F59E0B` | Alertes, conditions |
| `--warning-light` | `#FEF3C7` | Backgrounds warning |
| `--error` | `#EF4444` | Erreurs, refus |
| `--error-light` | `#FEE2E2` | Backgrounds error |
| `--info` | `#3B82F6` | Informations neutres |
| `--info-light` | `#DBEAFE` | Backgrounds info |

## 2.3 Couleurs par statut de demande

| Statut | Hex | Texte |
|---|---|---|
| Soumise | `#3B82F6` | Blanc |
| Attribuée | `#A855F7` | Blanc |
| En revue | `#F59E0B` | Foncé |
| Documents manquants | `#FB923C` | Foncé |
| En cours | `#22C55E` | Blanc |
| Soumise institution | `#06B6D4` | Blanc |
| En attente paiement | `#6B7280` | Blanc |
| Acceptée | `#16A34A` | Blanc |
| Refusée | `#EF4444` | Blanc |
| Clôturée | `#475569` | Blanc |

## 2.4 Mode sombre (V2 — pas au MVP)

Préparer les variables CSS/Theme pour pouvoir activer le dark mode plus tard. Ne pas le développer maintenant.

---

# 3. TYPOGRAPHIE

## 3.1 Police principale

**Inter** (Google Fonts) — pour la lisibilité mobile et le support complet des caractères français/africains.

**Alternative** : Plus Jakarta Sans (plus moderne, équivalent technique).

## 3.2 Hiérarchie typographique

| Style | Taille | Weight | Line height | Usage |
|---|---|---|---|---|
| H1 | 28px | 700 (Bold) | 36px | Titre de page principal |
| H2 | 22px | 600 (SemiBold) | 30px | Titres de section |
| H3 | 18px | 600 (SemiBold) | 26px | Titres de carte |
| H4 | 16px | 600 (SemiBold) | 24px | Sous-titres |
| Body Large | 16px | 400 (Regular) | 26px | Paragraphes principaux |
| Body | 14px | 400 (Regular) | 22px | Texte courant |
| Body Small | 13px | 400 (Regular) | 20px | Textes secondaires |
| Caption | 12px | 400 (Regular) | 18px | Métadonnées |
| Label | 12px | 500 (Medium) | 16px | Labels, badges |
| Button | 16px | 600 (SemiBold) | 24px | Texte des boutons |

## 3.3 Règles typo

- Pas plus de 60 caractères par ligne en body
- Pas plus de 3 niveaux de hiérarchie sur un même écran
- Tutoiement systématique
- Jamais de "...", utiliser un caractère ellipsis "…"
- Espaces insécables avant `:` `;` `?` `!` en français

---

# 4. ESPACEMENT & GRILLE

## 4.1 Échelle d'espacement (base 4px)

| Token | Valeur |
|---|---|
| `--spacing-0` | 0 |
| `--spacing-1` | 4px |
| `--spacing-2` | 8px |
| `--spacing-3` | 12px |
| `--spacing-4` | 16px |
| `--spacing-5` | 20px |
| `--spacing-6` | 24px |
| `--spacing-8` | 32px |
| `--spacing-10` | 40px |
| `--spacing-12` | 48px |
| `--spacing-16` | 64px |

## 4.2 Padding standards

- **Padding écran (horizontal)** : 16px sur mobile, 24px sur tablette
- **Padding cards** : 16px
- **Padding boutons** : 16px horizontal, 12px vertical
- **Padding inputs** : 16px horizontal, 14px vertical

## 4.3 Border radius

| Token | Valeur | Usage |
|---|---|---|
| `--radius-sm` | 6px | Badges, chips |
| `--radius-md` | 8px | Inputs, petits boutons |
| `--radius-lg` | 12px | Boutons principaux |
| `--radius-xl` | 16px | Cards |
| `--radius-2xl` | 24px | Modales, bottom sheets |
| `--radius-full` | 9999px | Avatars, boutons ronds |

## 4.4 Élévations / Shadows

| Token | Valeur | Usage |
|---|---|---|
| `--shadow-sm` | `0 1px 2px rgba(0,0,0,0.05)` | Hover subtil |
| `--shadow-md` | `0 4px 6px rgba(0,0,0,0.07)` | Cards |
| `--shadow-lg` | `0 10px 15px rgba(0,0,0,0.1)` | Modales |
| `--shadow-xl` | `0 20px 25px rgba(0,0,0,0.15)` | Bottom sheets |

---

# 5. COMPOSANTS

## 5.1 Boutons

### Primary (orange plein)
```
Background: var(--kpb-orange)
Texte: white
Border-radius: 12px
Padding: 16px 24px
Font: 16px SemiBold
States:
  hover: bg = orange-dark
  pressed: scale 0.98
  disabled: opacity 0.5
  loading: spinner blanc + texte masqué
```

### Secondary (outline orange)
```
Background: transparent
Border: 1.5px solid var(--kpb-orange)
Texte: var(--kpb-orange)
Padding: 14.5px 24px
```

### Ghost (texte uniquement)
```
Background: transparent
Texte: var(--kpb-orange) ou var(--kpb-dark)
Padding: 16px 24px
Hover: bg = kpb-orange-50
```

### Tertiary / Link
```
Texte: var(--kpb-orange)
Underline au hover
Pas de padding (inline)
```

### Floating Action Button (FAB)
```
Background: var(--kpb-orange)
Couleur icône: white
Taille: 56x56px
Border-radius: full
Shadow-lg
Position: fixed bottom-right (16px margins)
```

### WhatsApp button
```
Background: #25D366 (vert WhatsApp officiel)
Texte: white
Icône WhatsApp + texte "Discuter sur WhatsApp"
```

## 5.2 Inputs

### Text input
```
Background: white
Border: 1px solid var(--kpb-gray-300)
Border-radius: 8px
Padding: 14px 16px
Font: 16px Regular
Label: 12px Medium, above input, var(--kpb-gray-700)
Placeholder: var(--kpb-gray-500)
States:
  focus: border 2px solid var(--kpb-orange)
  error: border 1px solid var(--error), error message en rouge
  disabled: bg var(--kpb-gray-100), texte gray-500
```

### Select / Dropdown
```
Style identique à text input
Icône chevron-down à droite
Sur tap : bottom sheet avec options
```

### OTP input
```
6 inputs séparés
Taille: 48x56px chacun
Espacement: 8px entre
Auto-focus au précédent rempli
Style : grosse police 24px Bold centrée
```

### Slider
```
Track inactif: var(--kpb-gray-300)
Track actif: var(--kpb-orange)
Thumb: 24px, blanc avec border 2px orange et shadow
Labels min/max sous le slider
Valeur courante affichée au-dessus
```

## 5.3 Cards

### Card de base
```
Background: white
Border-radius: 16px
Padding: 16px
Shadow-md
Border: 1px solid var(--kpb-gray-100)
```

### Card pays (Destinations)
```
Hauteur: 180px
Background: image pays (cover)
Overlay: gradient bottom (transparent → noir 60%)
Contenu (overlay):
  - Drapeau emoji (top-left, 32px)
  - Nom pays (bottom-left, H3 white)
  - Badge rentrée (bottom-right, blanc/orange)
```

### Card école/programme
```
Layout horizontal:
  Logo école (56x56px, gauche)
  Contenu (droite):
    - Nom programme (H4)
    - École · Pays · Durée (Body Small gray-500)
    - Frais EUR (bold orange)
    - Badge "Partenaire ⭐" si applicable
```

### Card demande (timeline)
```
Bordure gauche colorée (4px, couleur du statut)
Padding 16px
Layout:
  - Numéro demande + Type (top)
  - Statut badge (top-right)
  - Date soumission · Conseiller avatar+prénom (middle)
  - Aperçu dernier message ou action (bottom)
  - Badge "Nouveau message" si non lu
```

### Card commercial (vue Jojo)
```
Layout horizontal:
  Indicateur étiquette (4px barre colorée à gauche)
  Avatar/initiale client
  Contenu:
    - Prénom + Âge + Niveau
    - Motif de discussion (en italique)
    - "Demande #X · il y a Yh · Étiquette"
```

## 5.4 Badges & Chips

### Badge statut
```
Background: couleur statut (background light)
Texte: couleur statut (foreground)
Padding: 4px 10px
Border-radius: 6px
Font: 12px Medium
```

### Chip filtre
```
Background: white quand inactif, var(--kpb-orange) quand actif
Border: 1px solid var(--kpb-gray-300) ou orange si actif
Texte: gray-700 ou white
Padding: 6px 12px
Border-radius: full
```

### Pill (drapeau + texte)
```
Inline-flex avec emoji + texte
Background: var(--kpb-gray-100)
Padding: 4px 8px
Border-radius: 6px
```

## 5.5 Navigation

### Bottom navigation
```
Hauteur: 64px (+ safe area iOS)
Background: white
Border-top: 1px solid var(--kpb-gray-200)
Items:
  - Icône 24x24 (outline inactif, filled actif)
  - Label 11px Medium
  - Couleur inactif: var(--kpb-gray-500)
  - Couleur actif: var(--kpb-orange)
  - Indicateur badge rouge si notif (pour onglet Demandes)
```

### Top app bar
```
Hauteur: 56px (+ safe area)
Background: white
Border-bottom: 1px solid var(--kpb-gray-200)
Contenu:
  - Bouton retour (24px) à gauche si pas accueil
  - Titre page (H4 centré ou aligné gauche)
  - Bouton action (cloche notifs, avatar…) à droite
```

### Tabs
```
Background: white
Tabs alignés à gauche, scrollables horizontalement
Tab inactif: gray-500
Tab actif: orange, underline 2px orange
Padding tab: 12px 16px
```

## 5.6 Bottom sheets (préféré aux modales)

```
Background: white
Border-radius-top: 24px
Shadow-xl
Indicateur drag (handle): 36x4px gray-300 en haut
Padding: 24px
Animation: slide-up 250ms ease-out
Backdrop: noir 50% opacity
Tap backdrop = ferme
```

## 5.7 Toasts & Snackbars

```
Position: bottom (au-dessus bottom nav)
Background: var(--kpb-dark) (default) ou var(--success/warning/error)
Texte: white
Padding: 12px 16px
Border-radius: 12px
Margin: 16px
Animation: slide-up 300ms
Auto-dismiss: 4 sec
```

## 5.8 Empty states

```
Illustration: 200px max
Titre: H3
Description: Body, gray-500
CTA: Button primary
```

## 5.9 Loading states

### Spinner
- Couleur : var(--kpb-orange)
- Taille : 24px (default), 48px (page)

### Skeleton
- Background : gradient gris animé (shimmer)
- Border-radius : matchant l'élément remplacé
- Animation : shimmer 1.5s ease-in-out infinite

### Progress bar (orientation, onboarding)
```
Hauteur: 4px
Background: var(--kpb-gray-200)
Fill: var(--kpb-orange)
Border-radius: full
Animation: width transition 300ms
```

---

# 6. ICONOGRAPHIE

## 6.1 Library recommandée

**Lucide Icons** (open source, cohérent, complet)
Fallback : Phosphor Icons

## 6.2 Tailles standards
- 16px : inline avec texte body
- 20px : inputs, petits boutons
- 24px : navigation, boutons standard
- 32px : carrousels, headers
- 48px : empty states, illustrations

## 6.3 Style
- Outline (par défaut)
- Filled (états actifs uniquement)
- Couleur héritée du parent (currentColor)

## 6.4 Mapping icônes principales

| Concept | Icône Lucide |
|---|---|
| Accueil | `home` |
| Destinations | `globe-2` |
| Universités | `graduation-cap` |
| Demandes | `inbox` |
| Moi / Profil | `user` |
| Coach IA | `sparkles` |
| Notifications | `bell` |
| Recherche | `search` |
| Filtre | `sliders-horizontal` |
| Favoris | `heart` |
| Documents | `file-text` |
| Chat | `message-circle` |
| WhatsApp | (logo officiel WhatsApp) |
| Pays | (emoji drapeau) |
| Argent / Budget | `wallet` |
| Étiquette | `tag` |
| Calendrier | `calendar` |
| Téléphone | `phone` |
| Email | `mail` |

---

# 7. ILLUSTRATIONS & IMAGES

## 7.1 Style photographique

- Photos d'**étudiants africains réels** (achetées sur Twenty20, Stocksy, ou photos KPB internes)
- Mise en scène **authentique** (campus, livres, ordinateurs)
- Lumière naturelle, pas de retouche excessive
- Diversité de genres et de morphologies

## 7.2 Style illustration

Pour les illustrations vectorielles (empty states, onboarding) :
- Style **flat** moderne
- Palette : variations d'orange KPB + grays + 1 couleur d'accent
- Pas de personnages 3D
- Style "Notion-like" minimaliste

## 7.3 Drapeaux pays

Utiliser les **emojis Unicode** pour les drapeaux (universellement supportés, légers, automatiquement à jour) :
🇫🇷 🇩🇪 🇺🇸 🇨🇦 🇲🇦 🇹🇷 🇦🇪 🇬🇧 🇪🇸

## 7.4 Logos écoles

- Format : SVG préféré, fallback PNG
- Taille : 200x200px max, fond transparent
- Hébergement : Cloudflare R2 ou S3

---

# 8. TON DE VOIX (Microcopy)

## 8.1 Principes

- **Tutoiement systématique** ("Tu veux quoi étudier ?")
- **Phrases courtes** (15 mots max idéalement)
- **Pas de jargon** ("inscription" et non "matriculation")
- **Encourageant et chaleureux**, jamais condescendant
- **Direct** ("Soumets ta demande" plutôt que "Veuillez procéder à la soumission")
- **Pas de "vous"** (sauf dans contexte ultra-formel comme footer légal)

## 8.2 Exemples de microcopy

### Erreurs
| Mauvais | Bon |
|---|---|
| "Une erreur est survenue" | "Oups, ça n'a pas marché. Réessaye dans 1 min." |
| "Champ requis" | "On a besoin de ça pour continuer" |
| "Mot de passe invalide" | "Le code n'est pas bon, vérifie tes SMS" |

### Empty states
| Contexte | Message |
|---|---|
| Pas de demande | "Tu n'as pas encore de demande. Lance-toi !" |
| Pas de favoris | "Tu n'as pas encore mis d'écoles en favoris. Explore !" |
| Pas de message | "Pas encore de message. Écris à {commercial} 👋" |

### CTA
| Mauvais | Bon |
|---|---|
| "Soumettre" | "Je soumets ma demande" |
| "Confirmer" | "C'est parti" |
| "Annuler" | "Revenir en arrière" |
| "Plus" | "Voir tout" ou "+ Nouveau" |

### Encouragements
- "Bien joué, Marie ! 🎉" (après orientation)
- "Tu y es presque" (étape onboarding)
- "Belle ambition, on t'accompagne" (création demande)

## 8.3 Émojis : règles

- **Avec parcimonie** : 1 par titre maximum, 0-1 par paragraphe
- **Jamais en début de phrase** (sauf interjection : "Bravo ! 🎉")
- **Jamais 2 d'affilée**
- **Cohérence émotionnelle** (pas de 😂 sur un sujet sérieux)
- **Drapeaux pays** : illimités dans les listes de pays

## 8.4 Tone par contexte

| Contexte | Ton |
|---|---|
| Onboarding | Accueillant, ludique |
| Orientation | Encourageant, bienveillant |
| Erreur | Calme, solution-oriented |
| Statut demande | Factuel, rassurant |
| Coach IA | Chaleureux, direct, jamais autoritaire |
| Commercial → client | Professionnel mais humain |
| Notifs push | Urgence dosée, FOMO sain |
| Footer légal | Formel (vous) |

---

# 9. RESPONSIVE / ADAPTATION

## 9.1 Breakpoints

L'app est **mobile-only**. Pas de version tablette/desktop au MVP.

Le back-office admin est **desktop-only**, breakpoints classiques :
- < 768px : pas supporté (afficher "Utilise un ordinateur")
- 768-1024px : tablette
- > 1024px : desktop (cible principale)

## 9.2 Densité d'écran

Tester sur :
- Petit Android (5"-5.5") — Tecno Spark, Itel
- Moyen (6"-6.5") — Samsung A24, Xiaomi Redmi
- Grand (6.5"+) — Samsung Galaxy S, iPhone

## 9.3 Safe areas

- Top safe area : respecter notch / encoche
- Bottom safe area : 16-20px de padding au-dessus du home indicator iOS

---

# 10. ACCESSIBILITÉ

## 10.1 Contraste

Tous les textes doivent respecter **WCAG AA** :
- Texte normal : ratio 4.5:1 minimum
- Texte grand (18px+) : ratio 3:1 minimum

Vérifier l'orange #E8593C sur fond blanc : ratio 4.7:1 ✅

## 10.2 Touch targets

- Minimum 44x44px (recommandé Apple HIG)
- Idéalement 48x48px (Material Design)

## 10.3 Sémantique

- Tous les inputs ont un label
- Les boutons icône-only ont un `aria-label` / `Semantics.label`
- Les images ont un `alt` ou `Semantics.label`
- Les états de chargement sont annoncés

## 10.4 Tailles de police dynamiques

L'app doit respecter les préférences système de taille de police (jusqu'à +30% sans casser le layout).

---

# 11. EXEMPLES D'ÉCRANS CLÉS

## 11.1 Écran Accueil (étudiant)

```
┌─────────────────────────────────────┐
│ Salut Aïcha 👋           🔔 [3]    │ ← Header
├─────────────────────────────────────┤
│                                     │
│  ┌───────────────────────────────┐ │
│  │ 💡 Bannière Coach IA          │ │
│  │ "Tu veux découvrir quoi      │ │
│  │ étudier ?" → Discuter         │ │
│  └───────────────────────────────┘ │
│                                     │
│  Actions rapides                    │
│  ┌───────┐ ┌───────┐ ┌───────┐    │
│  │ 🧭    │ │ 🎓    │ │ 💰    │    │
│  │ Orien-│ │ Trouver│ │ Simu- │   │
│  │ tation│ │ une   │ │ ler   │    │
│  │       │ │ école │ │ budget│    │
│  └───────┘ └───────┘ └───────┘    │
│                                     │
│  📍 Destinations populaires        │
│  [Carrousel 9 pays]                 │
│                                     │
│  ⭐ Écoles partenaires             │
│  [Carrousel cartes écoles]         │
│                                     │
│  💎 Bourse du moment              │
│  [Card McCall MacBain]             │
│                                     │
├─────────────────────────────────────┤
│ 🏠   🌍   🎓   💬   👤      🤖    │ ← Bottom nav + FAB Coach
└─────────────────────────────────────┘
```

## 11.2 Écran Fiche pays

```
┌─────────────────────────────────────┐
│ ← France                            │
├─────────────────────────────────────┤
│ [Image cover France]                │
│ 🇫🇷 France                          │
│ Étudier au cœur de l'Europe         │
│ 📅 Rentrée Sept 2026 · 🇫🇷 Français │
├─────────────────────────────────────┤
│ ⚠️ Procédure écoles privées        │
│    uniquement (Campus France        │
│    bientôt disponible)              │
├─────────────────────────────────────┤
│  [BOUTON ORANGE PLEIN]              │
│  Faire le quiz d'éligibilité →     │
├─────────────────────────────────────┤
│  Pourquoi la France ?              │
│  ✅ Excellence académique          │
│  ✅ Coût de vie maîtrisé           │
│  ✅ Visa post-études favorable     │
│  ✅ Diaspora africaine importante  │
│                                     │
│  Comment ça se passe                │
│  [Étapes 1-5 illustrées]            │
│                                     │
│  💰 Coûts                          │
│  - Scolarité : 5 000 - 18 000 €/an │
│  - Vie : 800 - 1 200 €/mois         │
│                                     │
│  🗣️ Langue requise                 │
│  Français B2 (DELF/DALF/TCF)        │
│                                     │
│  ⭐ Écoles partenaires (12)        │
│  [Carrousel cartes écoles]         │
│                                     │
├─────────────────────────────────────┤
│  [Demander un accompagnement]       │
│  [Bouton WhatsApp en backup]        │
└─────────────────────────────────────┘
```

---

# 12. TOKENS À EXPORTER

Pour Antigravity, livrer un fichier `design_tokens.json` :

```json
{
  "color": {
    "kpb": {
      "orange": "#E8593C",
      "orangeDark": "#C44529",
      "orangeLight": "#FFE8E2",
      "dark": "#1A1A2E",
      "gray": {
        "50": "#F9FAFB",
        "100": "#F3F4F6",
        "300": "#D1D5DB",
        "500": "#6B7280",
        "700": "#374151",
        "900": "#111827"
      }
    },
    "semantic": {
      "success": "#22C55E",
      "warning": "#F59E0B",
      "error": "#EF4444",
      "info": "#3B82F6"
    }
  },
  "spacing": [0, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64],
  "radius": {
    "sm": 6, "md": 8, "lg": 12, "xl": 16, "2xl": 24, "full": 9999
  },
  "fontSize": {
    "h1": 28, "h2": 22, "h3": 18, "h4": 16,
    "bodyLg": 16, "body": 14, "bodySm": 13,
    "caption": 12, "label": 12, "button": 16
  },
  "fontWeight": {
    "regular": 400, "medium": 500, "semibold": 600, "bold": 700
  }
}
```

---

**FIN ANNEXE 03**
