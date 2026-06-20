# 🌍 ANNEXE 04 — DATA SEED : 9 FICHES PAYS

**Référence** : Cahier des charges KPB Education V1
**Usage** : Données initiales à insérer dans la table `countries` + `country_eligibility_quizzes`
**À charger** : au déploiement initial (script de seed)

---

# Vue d'ensemble des 9 pays au lancement

| # | Pays | Code ISO-3 | Rentrée | Statut MVP | Langue principale | Partenaires |
|---|---|---|---|---|---|---|
| 1 | 🇫🇷 France | FRA | Septembre 2026 | **Privé uniquement** (Campus France bientôt) | Français | OMNES + ICN + Schiller Paris |
| 2 | 🇩🇪 Allemagne | DEU | Septembre 2026 | Programme langue dédié | Allemand (+ Anglais) | ICN Berlin + Schiller Heidelberg |
| 3 | 🇺🇸 USA | USA | Septembre 2026 | Actif | Anglais | Schiller Tampa |
| 4 | 🇨🇦 Canada | CAN | **Janvier 2027** | Bourse McCall MacBain en avant | Anglais/Français | (à compléter) |
| 5 | 🇲🇦 Maroc | MAR | Septembre 2026 | Actif | Français | ISMAGI + ESA Casablanca |
| 6 | 🇹🇷 Turquie | TUR | Septembre 2026 | Actif | Anglais/Turc | BAU Istanbul |
| 7 | 🇦🇪 EAU (Dubaï) | ARE | Septembre 2026 | Fiche basée sur GBS Dubai | Anglais | GBS Dubai |
| 8 | 🇬🇧 Royaume-Uni | GBR | **Janvier 2027** | Fiche propre, universités globalement | Anglais | (à compléter) |
| 9 | 🇪🇸 Espagne | ESP | Septembre 2026 | Fiche basée sur Schiller | Anglais | Schiller Madrid |

---

# 1. 🇫🇷 FRANCE

```yaml
code: FRA
name_fr: France
flag_emoji: 🇫🇷
tagline_fr: "Étudier au cœur de l'Europe, dans des écoles privées d'excellence"
next_intake_label: "Septembre 2026"
main_language: "Français"
avg_tuition_min_eur: 5000
avg_tuition_max_eur: 18000
monthly_living_cost_eur: 1000
mvp_note: "Écoles privées uniquement au MVP. Campus France (admission publique) marqué 'Bientôt disponible — Septembre 2026'."
```

## Description marketing

La France est une destination phare pour les études supérieures, réputée pour son excellence académique et son coût de vie maîtrisé comparé à d'autres pays européens. **Au lancement de l'app, KPB se concentre sur la procédure d'admission dans les écoles privées françaises** (OMNES Education, ICN, Schiller Paris, IGENSIA…) — la procédure Campus France pour les universités publiques sera disponible à partir de septembre 2026.

Les programmes en France sont souvent bilingues (français/anglais) et incluent des opportunités de stages, facilitant l'insertion professionnelle. Les étudiants internationaux bénéficient aussi d'aides au logement (CAF) et d'un accès au système de santé français à tarif étudiant. La diaspora africaine y est très présente, ce qui facilite l'intégration.

## Pourquoi la France ?

- 🎓 Plus de 250 ans d'excellence académique
- 💰 Frais privés accessibles (5 000 à 18 000 € / an)
- 🍞 Coût de la vie maîtrisé (~ 1 000 €/mois)
- 🌍 Diaspora africaine forte (intégration facilitée)
- 💼 Visa post-études Talent et APS jusqu'à 12 mois
- ✈️ Vols directs depuis la plupart des capitales africaines

## Conditions d'accès par niveau

### BTS / DUT (Bac+2)
- **Académique** : Baccalauréat ou équivalent
- **Langue** : DELF/DALF/TCF B2 minimum (exception si français langue maternelle ou de scolarité)
- **Visa** : visa long séjour étudiant après admission
- **Capacité financière** : ~615 €/mois (minimum exigé par l'administration française)

### Licence / Bachelor (Bac+3)
- **Académique** : Baccalauréat avec bon dossier
- **Langue** : DELF/DALF/TCF B2 (ou anglais IELTS/TOEFL pour programmes anglophones)
- **Visa** : visa long séjour étudiant
- **Capacité financière** : minimum 7 380 €/an
- **Assurance santé** : inscription obligatoire à la sécurité sociale étudiante

### Master (Bac+5)
- **Académique** : Licence (Bac+3) ou équivalent
- **Langue** : DELF B2 ou IELTS 6.5+ / TOEFL iBT 85+
- **Dossier** : lettre de motivation, CV, parfois lettre de recommandation
- **Expérience** : certaines MBA exigent expérience pro

### Doctorat (Bac+8)
- **Académique** : Master ou équivalent + excellent dossier
- **Langue** : C1 recommandé
- **Projet de recherche** : obligatoire
- **Encadrement** : accord préalable d'un directeur de thèse

## Quiz d'éligibilité France (7 questions)

```json
{
  "country_code": "FRA",
  "questions": [
    {
      "id": "q1_level",
      "text": "Quel est ton niveau d'études actuel ?",
      "type": "single_select",
      "options": [
        {"value": "terminale", "label": "Terminale (lycée)"},
        {"value": "l1_l2", "label": "L1 ou L2 (Bachelor 1-2)"},
        {"value": "l3", "label": "L3 / Licence terminée"},
        {"value": "m1_m2", "label": "M1 ou M2"},
        {"value": "autre", "label": "Autre"}
      ]
    },
    {
      "id": "q2_diploma",
      "text": "As-tu (ou auras-tu cette année) le baccalauréat ?",
      "type": "single_select",
      "options": [
        {"value": "yes_obtained", "label": "Oui, je l'ai déjà"},
        {"value": "yes_this_year", "label": "Je le passe cette année"},
        {"value": "no", "label": "Non / autre diplôme"}
      ]
    },
    {
      "id": "q3_grades",
      "text": "Quelle est ta moyenne générale estimée ?",
      "type": "single_select",
      "options": [
        {"value": "excellent", "label": "Plus de 14/20"},
        {"value": "good", "label": "Entre 12 et 14/20"},
        {"value": "average", "label": "Entre 10 et 12/20"},
        {"value": "below", "label": "Moins de 10/20"}
      ]
    },
    {
      "id": "q4_budget",
      "text": "Quel budget annuel peux-tu mobiliser (scolarité) ?",
      "type": "single_select",
      "options": [
        {"value": "low", "label": "Moins de 5 000 €"},
        {"value": "medium", "label": "5 000 à 10 000 €"},
        {"value": "high", "label": "10 000 à 20 000 €"},
        {"value": "very_high", "label": "Plus de 20 000 €"}
      ]
    },
    {
      "id": "q5_french_level",
      "text": "Quel est ton niveau de français ?",
      "type": "single_select",
      "options": [
        {"value": "native", "label": "Natif / langue maternelle"},
        {"value": "fluent", "label": "Courant (B2/C1)"},
        {"value": "intermediate", "label": "Intermédiaire (B1)"},
        {"value": "basic", "label": "Scolaire / faible"}
      ]
    },
    {
      "id": "q6_visa_history",
      "text": "As-tu déjà eu un refus de visa Schengen ?",
      "type": "single_select",
      "options": [
        {"value": "no", "label": "Non"},
        {"value": "yes_recent", "label": "Oui, il y a moins de 2 ans"},
        {"value": "yes_old", "label": "Oui, mais il y a plus de 2 ans"}
      ]
    },
    {
      "id": "q7_financial_proof",
      "text": "Peux-tu prouver des fonds d'au moins 7 380 € (ou avoir un garant en France) ?",
      "type": "single_select",
      "options": [
        {"value": "yes_self", "label": "Oui, j'ai les fonds"},
        {"value": "yes_family", "label": "Oui, via ma famille en Afrique"},
        {"value": "yes_garant_france", "label": "Oui, j'ai un garant en France"},
        {"value": "no", "label": "Non, c'est compliqué"}
      ]
    }
  ],
  "scoring_rules": {
    "eligible": "q2 in ['yes_obtained', 'yes_this_year'] AND q5 in ['native', 'fluent', 'intermediate'] AND q7 != 'no' AND q6 != 'yes_recent'",
    "eligible_with_conditions": "q2 in ['yes_obtained', 'yes_this_year'] AND (q5 == 'basic' OR q7 == 'no' OR q6 == 'yes_recent')",
    "not_eligible": "q2 == 'no' OR (q5 == 'basic' AND q7 == 'no')"
  },
  "verdicts": {
    "eligible": {
      "title": "🎉 Tu es éligible !",
      "message": "Excellent profil pour étudier en France. Lance ta demande d'accompagnement pour qu'on choisisse ensemble la meilleure école privée.",
      "cta": "Demander un accompagnement France"
    },
    "eligible_with_conditions": {
      "title": "🟡 Éligible sous conditions",
      "message": "Tu peux étudier en France mais quelques points sont à travailler. Un conseiller KPB va t'expliquer comment optimiser ton dossier.",
      "cta": "Discuter avec un conseiller"
    },
    "not_eligible": {
      "title": "💡 Pas le bon moment, mais on a des alternatives",
      "message": "Le profil exigé pour la France n'est pas encore là, mais le Maroc ou la Turquie pourraient parfaitement te convenir.",
      "cta": "Voir le Maroc et la Turquie"
    }
  }
}
```

---

# 2. 🇩🇪 ALLEMAGNE

```yaml
code: DEU
name_fr: Allemagne
flag_emoji: 🇩🇪
tagline_fr: "Universités publiques gratuites + offre exclusive cours de langue"
next_intake_label: "Septembre 2026"
main_language: "Allemand (Anglais pour certains programmes)"
avg_tuition_min_eur: 0
avg_tuition_max_eur: 1500
monthly_living_cost_eur: 992
special_offer: "Programme langue 40 sem. : 9 500 € + compte bloqué 11 904 € + 600 € inscription"
```

## Description marketing

L'Allemagne est l'un des pays les plus attractifs pour les études supérieures grâce à ses **universités publiques sans frais de scolarité** pour la majorité des programmes, et à son excellence académique reconnue mondialement.

KPB propose une **offre exclusive Allemagne** comprenant un programme intensif de langue allemande (40 semaines, A1 → C1), l'accompagnement complet pour l'admission universitaire, le visa, le logement et l'accueil sur place.

## Pourquoi l'Allemagne ?

- 💰 Études quasi gratuites dans les universités publiques (~ 0 à 1 500 €/an)
- 🏭 Excellence en ingénierie, informatique et sciences
- 💼 Visa de recherche d'emploi 18 mois après le diplôme
- 🇪🇺 Possibilité de travailler dans toute l'UE après les études
- 🚆 Au cœur de l'Europe

## Offre exclusive KPB Allemagne (cours de langue)

- **Durée** : 40 semaines (A1 → C1)
- **Niveaux A1-A2** : possibles en ligne depuis l'Afrique
- **Niveaux suivants** : en Allemagne (immersion)
- **Cours intensifs** : 30 heures/semaine
- **Classes** : max 14 étudiants
- **Inclus** : examens TELC B2 et C1, matériel pédagogique, accompagnement administratif, accueil aéroport, logement en chambre meublée
- **Tarification** :
  - Frais d'inscription : **600 €** (admission universitaire + assistance visa)
  - Programme langue 40 sem. : **9 500 €**
  - Compte bloqué (exigé pour visa) : **11 904 €** (libéré ~992 €/mois pour la vie en Allemagne)

## Conditions d'accès par niveau

### Bachelor
- Bac validé (parfois passage par Studienkolleg — année préparatoire)
- Allemand B2 (TestDaF / Goethe-Zertifikat) OU anglais pour programmes anglophones
- Compte bloqué : 11 904 € minimum

### Master
- Licence ou équivalent
- Allemand B2/C1 ou anglais TOEFL iBT 80+/IELTS 6.5+
- Lettre de motivation + CV + lettres de recommandation
- Certains programmes : GRE/GMAT

### Doctorat
- Master + excellent dossier
- Projet de recherche aligné avec un superviseur
- Accord d'un directeur de thèse

## Quiz d'éligibilité Allemagne (6 questions)

```json
{
  "country_code": "DEU",
  "questions": [
    {
      "id": "q1_level",
      "text": "Quel est ton niveau d'études actuel ?",
      "type": "single_select",
      "options": [
        {"value": "terminale", "label": "Terminale (lycée)"},
        {"value": "bachelor", "label": "Bachelor / Licence en cours ou terminée"},
        {"value": "master", "label": "Master en cours ou terminé"}
      ]
    },
    {
      "id": "q2_german_level",
      "text": "Quel est ton niveau d'allemand actuel ?",
      "type": "single_select",
      "options": [
        {"value": "advanced", "label": "B2 ou plus (certifié)"},
        {"value": "intermediate", "label": "B1 / scolaire"},
        {"value": "beginner", "label": "Débutant"},
        {"value": "none", "label": "Aucune notion"}
      ]
    },
    {
      "id": "q3_english_level",
      "text": "Et ton niveau d'anglais ?",
      "type": "single_select",
      "options": [
        {"value": "advanced", "label": "B2 ou plus"},
        {"value": "intermediate", "label": "B1 / scolaire"},
        {"value": "basic", "label": "Faible"}
      ]
    },
    {
      "id": "q4_language_track",
      "text": "Es-tu prêt(e) à suivre un programme intensif de langue allemande avant les études ?",
      "type": "single_select",
      "options": [
        {"value": "yes_full", "label": "Oui, 40 semaines complètes"},
        {"value": "yes_partial", "label": "Oui, mais le plus court possible"},
        {"value": "no_only_english", "label": "Non, je veux uniquement des programmes en anglais"}
      ]
    },
    {
      "id": "q5_blocked_account",
      "text": "Peux-tu mobiliser ~12 000 € pour un compte bloqué visa ?",
      "type": "single_select",
      "options": [
        {"value": "yes_easily", "label": "Oui, sans problème"},
        {"value": "yes_difficult", "label": "Oui, mais c'est tendu"},
        {"value": "no", "label": "Non, c'est trop"}
      ]
    },
    {
      "id": "q6_field",
      "text": "Quel domaine veux-tu étudier ?",
      "type": "single_select",
      "options": [
        {"value": "engineering", "label": "Ingénierie / Informatique"},
        {"value": "sciences", "label": "Sciences / Recherche"},
        {"value": "business", "label": "Business / Management"},
        {"value": "other", "label": "Autre"}
      ]
    }
  ],
  "scoring_rules": {
    "eligible": "(q2 == 'advanced' OR q4 != 'no_only_english') AND q5 != 'no'",
    "eligible_with_conditions": "q4 == 'yes_partial' AND q5 == 'yes_difficult'",
    "not_eligible": "q5 == 'no' AND q4 == 'no_only_english'"
  },
  "verdicts": {
    "eligible": {
      "title": "🎉 L'Allemagne t'attend",
      "message": "Profil compatible. Avec notre offre exclusive de cours de langue + accompagnement, ton projet est solide.",
      "cta": "Voir l'offre exclusive Allemagne"
    },
    "eligible_with_conditions": {
      "title": "🟡 C'est possible mais à cadrer",
      "message": "L'Allemagne est accessible, mais il faut bien dimensionner le programme langue et le budget. Parlons-en.",
      "cta": "Discuter avec un conseiller"
    },
    "not_eligible": {
      "title": "💡 L'Allemagne est tendue, regardons ailleurs",
      "message": "Sans budget pour le compte bloqué et sans envie d'apprendre l'allemand, c'est compliqué. Le Maroc ou la Turquie sont plus accessibles.",
      "cta": "Voir le Maroc et la Turquie"
    }
  }
}
```

---

# 3. 🇺🇸 USA

```yaml
code: USA
name_fr: USA
flag_emoji: 🇺🇸
tagline_fr: "Le plus grand écosystème universitaire au monde"
next_intake_label: "Septembre 2026"
main_language: "Anglais"
avg_tuition_min_eur: 15000
avg_tuition_max_eur: 50000
monthly_living_cost_eur: 1200
```

## Description marketing

Les États-Unis sont une destination rêvée pour les étudiants internationaux grâce à la diversité de leurs institutions, leurs innovations technologiques et leurs opportunités professionnelles. Les programmes intègrent souvent des opportunités de stage (OPT) qui permettent aux diplômés d'acquérir une expérience professionnelle directement liée à leurs études.

KPB accompagne ses étudiants dans la recherche d'universités, la préparation aux tests (TOEFL, IELTS, GRE, GMAT) et l'obtention du visa F-1.

## Pourquoi les USA ?

- 🏆 Universités prestigieuses (Harvard, MIT, Stanford…)
- 💼 OPT post-études jusqu'à 36 mois (STEM)
- 🌟 Diversité de programmes (community college → PhD)
- 🚀 Écosystème entrepreneurial unique
- 🌍 Diaspora africaine importante

## Conditions d'accès par niveau

### Associate Degree (community college, Bac+2)
- Diplôme de fin d'études secondaires
- TOEFL iBT 61+ / IELTS 5.5+ (option ESL possible)
- Visa F-1
- Fonds : 15 000-20 000 USD/an

### Bachelor (Licence)
- High School Diploma ou équivalent + relevés 3 dernières années
- TOEFL iBT 70-80+ / IELTS 6.0+
- Certaines universités exigent SAT/ACT
- Fonds : 20 000-50 000 USD/an

### Master
- Licence ou équivalent
- TOEFL iBT 80-90+ / IELTS 6.5+
- GRE (sciences/ingénierie) ou GMAT (business)
- Dossier complet (LM, CV, lettres recommandation)

### Doctorat (PhD)
- Master (parfois Licence très brillante)
- TOEFL iBT 90-100+ / IELTS 7.0+
- Projet de recherche + accord superviseur
- GRE souvent exigé
- Bourse intégrale fréquente

## Quiz d'éligibilité USA (6 questions)

```json
{
  "country_code": "USA",
  "questions": [
    {
      "id": "q1_level",
      "text": "Quel est ton niveau d'études actuel ?",
      "type": "single_select",
      "options": [
        {"value": "terminale", "label": "Terminale"},
        {"value": "bachelor", "label": "Bachelor / Licence"},
        {"value": "master", "label": "Master"}
      ]
    },
    {
      "id": "q2_english_level",
      "text": "Quel est ton niveau d'anglais ?",
      "type": "single_select",
      "options": [
        {"value": "native_or_scholar", "label": "Natif ou langue de scolarité"},
        {"value": "advanced", "label": "Avancé (TOEFL 80+/IELTS 6.5+)"},
        {"value": "intermediate", "label": "Intermédiaire"},
        {"value": "basic", "label": "Scolaire"}
      ]
    },
    {
      "id": "q3_budget",
      "text": "Quel budget annuel peux-tu mobiliser (scolarité + vie) ?",
      "type": "single_select",
      "options": [
        {"value": "low", "label": "Moins de 25 000 USD"},
        {"value": "medium", "label": "25 000 - 40 000 USD"},
        {"value": "high", "label": "40 000 - 60 000 USD"},
        {"value": "very_high", "label": "Plus de 60 000 USD"}
      ]
    },
    {
      "id": "q4_grades",
      "text": "Quelle est ta moyenne estimée ?",
      "type": "single_select",
      "options": [
        {"value": "excellent", "label": "GPA 3.5+ / Plus de 16/20"},
        {"value": "good", "label": "GPA 3.0-3.5 / 14-16/20"},
        {"value": "average", "label": "GPA 2.5-3.0 / 12-14/20"},
        {"value": "below", "label": "Inférieur"}
      ]
    },
    {
      "id": "q5_tests",
      "text": "As-tu déjà passé TOEFL, IELTS, SAT ou GRE ?",
      "type": "multi_select",
      "options": [
        {"value": "toefl", "label": "TOEFL"},
        {"value": "ielts", "label": "IELTS"},
        {"value": "sat", "label": "SAT"},
        {"value": "gre_gmat", "label": "GRE/GMAT"},
        {"value": "none", "label": "Aucun"}
      ]
    },
    {
      "id": "q6_visa_history",
      "text": "As-tu déjà eu un refus de visa USA ?",
      "type": "single_select",
      "options": [
        {"value": "no", "label": "Non"},
        {"value": "yes_recent", "label": "Oui, il y a moins de 2 ans"},
        {"value": "yes_old", "label": "Oui, plus de 2 ans"}
      ]
    }
  ],
  "scoring_rules": {
    "eligible": "q2 in ['native_or_scholar', 'advanced'] AND q3 in ['medium', 'high', 'very_high'] AND q4 in ['excellent', 'good']",
    "eligible_with_conditions": "(q2 == 'intermediate' OR q3 == 'low' OR q4 == 'average')",
    "not_eligible": "q3 == 'low' AND q4 == 'below'"
  },
  "verdicts": {
    "eligible": {
      "title": "🎉 Profil USA-ready",
      "message": "Tu as un profil compatible avec les universités américaines. On peut lancer la chasse aux écoles et aux bourses.",
      "cta": "Demander un accompagnement USA"
    },
    "eligible_with_conditions": {
      "title": "🟡 Quelques étapes à passer",
      "message": "Il faut probablement passer des tests (TOEFL/SAT) et optimiser ton budget. Un conseiller t'expliquera.",
      "cta": "Discuter avec un conseiller"
    },
    "not_eligible": {
      "title": "💡 Les USA sont coûteux, regardons des alternatives",
      "message": "Le Canada (cours en anglais) ou les EAU peuvent t'offrir un cursus anglophone à un coût plus accessible.",
      "cta": "Voir le Canada et les EAU"
    }
  }
}
```

---

# 4. 🇨🇦 CANADA

```yaml
code: CAN
name_fr: Canada
flag_emoji: 🇨🇦
tagline_fr: "Qualité de vie, multiculturalisme et résidence post-diplôme"
next_intake_label: "Janvier 2027"
main_language: "Anglais et Français"
avg_tuition_min_eur: 7000
avg_tuition_max_eur: 25000
monthly_living_cost_eur: 1100
featured_scholarship: "McCall MacBain Scholarship (McGill) — couvre frais + allocation"
```

## Description marketing

Le Canada est l'une des destinations les plus prisées grâce à la qualité de son système éducatif, ses campus modernes et son cadre multiculturel accueillant. Des universités comme l'Université de Toronto, McGill et UBC sont classées parmi les meilleures au monde.

Les étudiants internationaux peuvent travailler durant les études et obtenir un permis post-diplôme — souvent un chemin direct vers la résidence permanente. **À noter : la bourse McCall MacBain de McGill (Master) couvre frais + allocation et est ouverte aux candidats africains.**

## Pourquoi le Canada ?

- 🏔️ Qualité de vie exceptionnelle
- 💼 PGWP (Post-Graduation Work Permit) jusqu'à 3 ans
- 🍁 Voie facilitée vers la résidence permanente
- 🌍 Société multiculturelle accueillante
- 💎 **Bourse McCall MacBain** (McGill — Master, tous domaines)
- 🇫🇷 Université McGill / Concordia / UQAM en français possible

## Conditions d'accès par niveau

### CÉGEP (Bac+2)
- Diplôme secondaire équivalent au secondaire V québécois
- TEF/TCF (français) ou IELTS/TOEFL (anglais)
- Lettre d'acceptation du CÉGEP

### Bachelor (Licence)
- Diplôme secondaire conforme aux exigences
- IELTS 6.0+ / TOEFL iBT 80+ (anglais) ou TEF/TCF (français)
- Certains programmes : SAT ou tests supplémentaires

### Master
- Licence avec GPA 3.0/4 ou 75 % minimum
- IELTS 6.5+ / TOEFL iBT 90+
- GMAT ou GRE selon programme

### Doctorat (PhD)
- Master avec excellent dossier (publications souhaitées)
- IELTS 7.0+ / TOEFL iBT 100+
- Projet de recherche + accord superviseur

## Quiz d'éligibilité Canada (7 questions)

```json
{
  "country_code": "CAN",
  "questions": [
    {
      "id": "q1_level",
      "text": "Quel est ton niveau d'études ?",
      "type": "single_select",
      "options": [
        {"value": "terminale", "label": "Terminale"},
        {"value": "bachelor", "label": "Bachelor / Licence"},
        {"value": "master", "label": "Master"}
      ]
    },
    {
      "id": "q2_language",
      "text": "Quelle langue d'études préfères-tu ?",
      "type": "single_select",
      "options": [
        {"value": "english", "label": "Anglais (Ontario, BC, McGill anglais)"},
        {"value": "french", "label": "Français (Québec : UdeM, UQAM, Laval)"},
        {"value": "either", "label": "Peu importe"}
      ]
    },
    {
      "id": "q3_english_level",
      "text": "Quel est ton niveau d'anglais ?",
      "type": "single_select",
      "options": [
        {"value": "advanced", "label": "Avancé (IELTS 6.5+/TOEFL 90+)"},
        {"value": "intermediate", "label": "Intermédiaire"},
        {"value": "basic", "label": "Scolaire / faible"}
      ]
    },
    {
      "id": "q4_budget",
      "text": "Quel budget annuel peux-tu mobiliser ?",
      "type": "single_select",
      "options": [
        {"value": "low", "label": "Moins de 15 000 CAD"},
        {"value": "medium", "label": "15 000 - 25 000 CAD"},
        {"value": "high", "label": "25 000 - 40 000 CAD"},
        {"value": "very_high", "label": "Plus de 40 000 CAD"}
      ]
    },
    {
      "id": "q5_grades",
      "text": "Quelle est ta moyenne estimée ?",
      "type": "single_select",
      "options": [
        {"value": "excellent", "label": "Plus de 16/20 (top 10 %)"},
        {"value": "good", "label": "14-16/20"},
        {"value": "average", "label": "12-14/20"},
        {"value": "below", "label": "Moins de 12/20"}
      ]
    },
    {
      "id": "q6_scholarship_interest",
      "text": "Tu veux qu'on cherche une bourse (ex : McCall MacBain à McGill) ?",
      "type": "single_select",
      "options": [
        {"value": "yes_priority", "label": "Oui, prioritaire"},
        {"value": "yes_nice", "label": "Oui si possible"},
        {"value": "no", "label": "Non, j'ai le budget"}
      ]
    },
    {
      "id": "q7_pr_interest",
      "text": "Veux-tu envisager la résidence permanente après les études ?",
      "type": "single_select",
      "options": [
        {"value": "yes", "label": "Oui, c'est mon objectif"},
        {"value": "maybe", "label": "Peut-être"},
        {"value": "no", "label": "Non, juste les études"}
      ]
    }
  ],
  "scoring_rules": {
    "eligible": "q4 in ['medium', 'high', 'very_high'] AND q5 in ['excellent', 'good'] AND (q2 == 'french' OR q3 in ['advanced', 'intermediate'])",
    "eligible_with_conditions": "q4 == 'low' OR q5 == 'average' OR q3 == 'basic'",
    "not_eligible": "q4 == 'low' AND q5 == 'below'"
  },
  "verdicts": {
    "eligible": {
      "title": "🎉 Le Canada t'ouvre les bras",
      "message": "Excellent profil. Si tu vises McCall MacBain à McGill, on peut t'accompagner sur la candidature. La rentrée Janvier 2027 te laisse le temps.",
      "cta": "Demander un accompagnement Canada"
    },
    "eligible_with_conditions": {
      "title": "🟡 Possible avec optimisation",
      "message": "Le Canada est jouable. On peut t'orienter vers des programmes plus accessibles ou des bourses adaptées.",
      "cta": "Discuter avec un conseiller"
    },
    "not_eligible": {
      "title": "💡 Le Canada est tendu, alternatives ?",
      "message": "Avec un budget limité et un dossier moyen, regardons le Maroc ou la France privé qui sont plus accessibles.",
      "cta": "Voir le Maroc et la France"
    }
  }
}
```

---

# 5. 🇲🇦 MAROC

```yaml
code: MAR
name_fr: Maroc
flag_emoji: 🇲🇦
tagline_fr: "Études francophones de qualité, proche de chez toi"
next_intake_label: "Septembre 2026"
main_language: "Français (arabe et anglais selon programmes)"
avg_tuition_min_eur: 2500
avg_tuition_max_eur: 6000
monthly_living_cost_eur: 400
partners: ["ISMAGI", "ESA Casablanca"]
```

## Description marketing

Le Maroc est une destination idéale pour les étudiants francophones africains : coût de vie abordable, proximité culturelle, enseignement supérieur reconnu, **et beaucoup moins de complications visa que pour l'Europe**. KPB est partenaire avec ISMAGI (Rabat) et ESA Casablanca — des écoles solides avec un large catalogue Licence/Master.

## Pourquoi le Maroc ?

- 💰 Frais accessibles (2 500 à 6 000 €/an)
- 🤝 Visa généralement plus simple pour les Africains francophones
- 🛬 Vols courts depuis l'Afrique de l'Ouest (3-5h)
- 🇫🇷 Programmes francophones majoritairement
- 🌆 Vie étudiante riche (Rabat, Casablanca)

## Conditions d'accès par niveau

### Bac+2 (instituts techniques)
- Baccalauréat avec bon dossier
- Français niveau B2 recommandé
- Visa étudiant après admission

### Licence
- Bac avec notes conformes au programme
- Français B2 (anglais pour certains programmes)
- Pas de tests spécifiques (sauf ingénierie)

### Master
- Licence ou équivalent
- Français B2 ou anglais
- Lettre de motivation + CV

### Doctorat
- Master + excellent dossier
- Projet de recherche
- Accord superviseur

## Quiz d'éligibilité Maroc (5 questions)

```json
{
  "country_code": "MAR",
  "questions": [
    {
      "id": "q1_level",
      "text": "Quel est ton niveau d'études actuel ?",
      "type": "single_select",
      "options": [
        {"value": "terminale", "label": "Terminale"},
        {"value": "bachelor", "label": "Bachelor / Licence"},
        {"value": "master", "label": "Master"}
      ]
    },
    {
      "id": "q2_diploma",
      "text": "As-tu (ou auras-tu cette année) le bac ?",
      "type": "single_select",
      "options": [
        {"value": "yes_obtained", "label": "Oui, je l'ai"},
        {"value": "yes_this_year", "label": "Je le passe cette année"},
        {"value": "no", "label": "Non / autre diplôme"}
      ]
    },
    {
      "id": "q3_french_level",
      "text": "Quel est ton niveau de français ?",
      "type": "single_select",
      "options": [
        {"value": "native", "label": "Natif"},
        {"value": "fluent", "label": "Courant"},
        {"value": "intermediate", "label": "Intermédiaire"},
        {"value": "basic", "label": "Faible"}
      ]
    },
    {
      "id": "q4_budget",
      "text": "Quel budget annuel peux-tu mobiliser ?",
      "type": "single_select",
      "options": [
        {"value": "low", "label": "Moins de 3 000 €"},
        {"value": "medium", "label": "3 000 - 6 000 €"},
        {"value": "high", "label": "Plus de 6 000 €"}
      ]
    },
    {
      "id": "q5_field",
      "text": "Quel domaine veux-tu étudier ?",
      "type": "single_select",
      "options": [
        {"value": "management", "label": "Management / Business / Finance"},
        {"value": "it", "label": "Informatique / Tech / IA"},
        {"value": "engineering", "label": "Ingénierie"},
        {"value": "other", "label": "Autre"}
      ]
    }
  ],
  "scoring_rules": {
    "eligible": "q2 in ['yes_obtained', 'yes_this_year'] AND q3 in ['native', 'fluent', 'intermediate']",
    "eligible_with_conditions": "q3 == 'basic' OR q4 == 'low'",
    "not_eligible": "q2 == 'no' AND q4 == 'low'"
  },
  "verdicts": {
    "eligible": {
      "title": "🎉 Le Maroc, c'est tout à fait jouable",
      "message": "Avec ISMAGI ou ESA Casablanca, on a des programmes solides qui correspondent à ton profil.",
      "cta": "Demander un accompagnement Maroc"
    },
    "eligible_with_conditions": {
      "title": "🟡 C'est possible, parlons-en",
      "message": "Quelques détails à clarifier (budget ou langue). Un conseiller va t'orienter.",
      "cta": "Discuter avec un conseiller"
    },
    "not_eligible": {
      "title": "💡 Voyons d'autres options",
      "message": "Sans bac et avec un budget très serré, c'est difficile partout. Discutons de ton projet.",
      "cta": "Parler à un conseiller"
    }
  }
}
```

---

# 6. 🇹🇷 TURQUIE

```yaml
code: TUR
name_fr: Turquie
flag_emoji: 🇹🇷
tagline_fr: "Universités modernes, frais abordables, pont entre Europe et Asie"
next_intake_label: "Septembre 2026"
main_language: "Anglais (et turc selon programmes)"
avg_tuition_min_eur: 4000
avg_tuition_max_eur: 12000
monthly_living_cost_eur: 500
partners: ["BAU Istanbul"]
```

## Description marketing

La Turquie est devenue une destination très prisée grâce à ses universités modernes, son coût de vie abordable, et sa position stratégique entre Europe et Asie. KPB est partenaire avec **BAU Istanbul** (Bahçeşehir University), une des meilleures universités privées du pays, avec une offre complète Bachelor en anglais (Business, Engineering, Computer Science, AI, Medicine, Architecture…).

La bourse gouvernementale **Türkiye Burslari** couvre frais + hébergement + allocation pour les boursiers sélectionnés.

## Pourquoi la Turquie ?

- 💰 Frais compétitifs (4 000 à 12 000 €/an)
- 🌆 Istanbul : ville cosmopolite et abordable
- 🎓 Universités modernes (BAU, Bilkent, Bogazici…)
- 🎯 Bourse Türkiye Burslari ouverte aux Africains
- ✈️ Vols directs Turkish Airlines depuis Afrique

## Conditions d'accès par niveau

### Bac+2 (instituts techniques)
- Bac
- Turc (TÖMER) ou anglais (TOEFL iBT 60+/IELTS 5.5+)
- Année préparatoire en langue possible

### Bachelor
- Bac avec dossier conforme
- Certaines universités : YÖS (Exam for Foreign Students)
- TOEFL iBT 70+/IELTS 6.0+ ou TÖMER
- Année préparatoire de langue disponible

### Master
- Licence ou équivalent
- TOEFL iBT 75+/IELTS 6.5+ ou TÖMER
- Parfois GRE/GMAT
- Dossier complet

### Doctorat
- Master + dossier excellent
- TOEFL iBT 80+/IELTS 6.5+ ou TÖMER
- Projet de recherche

## Quiz d'éligibilité Turquie (5 questions)

```json
{
  "country_code": "TUR",
  "questions": [
    {
      "id": "q1_level",
      "text": "Quel est ton niveau d'études ?",
      "type": "single_select",
      "options": [
        {"value": "terminale", "label": "Terminale"},
        {"value": "bachelor", "label": "Bachelor / Licence"},
        {"value": "master", "label": "Master"}
      ]
    },
    {
      "id": "q2_language",
      "text": "Quelle langue d'études préfères-tu ?",
      "type": "single_select",
      "options": [
        {"value": "english", "label": "Anglais"},
        {"value": "turkish", "label": "Turc (avec année préparatoire si besoin)"},
        {"value": "either", "label": "Peu importe"}
      ]
    },
    {
      "id": "q3_english_level",
      "text": "Quel est ton niveau d'anglais ?",
      "type": "single_select",
      "options": [
        {"value": "advanced", "label": "Avancé (B2+)"},
        {"value": "intermediate", "label": "Intermédiaire (B1)"},
        {"value": "basic", "label": "Faible / scolaire"}
      ]
    },
    {
      "id": "q4_budget",
      "text": "Quel budget annuel peux-tu mobiliser ?",
      "type": "single_select",
      "options": [
        {"value": "low", "label": "Moins de 5 000 €"},
        {"value": "medium", "label": "5 000 - 10 000 €"},
        {"value": "high", "label": "Plus de 10 000 €"}
      ]
    },
    {
      "id": "q5_scholarship",
      "text": "Veux-tu qu'on cherche une bourse (Türkiye Burslari) ?",
      "type": "single_select",
      "options": [
        {"value": "yes_priority", "label": "Oui, prioritaire"},
        {"value": "yes_nice", "label": "Oui si possible"},
        {"value": "no", "label": "Non, j'ai le budget"}
      ]
    }
  ],
  "scoring_rules": {
    "eligible": "q4 in ['medium', 'high'] OR (q4 == 'low' AND q5 == 'yes_priority')",
    "eligible_with_conditions": "q3 == 'basic' AND q2 == 'english'",
    "not_eligible": "q4 == 'low' AND q5 == 'no'"
  },
  "verdicts": {
    "eligible": {
      "title": "🎉 La Turquie est faite pour toi",
      "message": "Avec BAU Istanbul et son large catalogue en anglais, ton projet est très réaliste.",
      "cta": "Demander un accompagnement Turquie"
    },
    "eligible_with_conditions": {
      "title": "🟡 Possible avec une année préparatoire",
      "message": "Une année prépa en anglais ou en turc te permettra d'entrer ensuite dans le programme visé.",
      "cta": "Discuter avec un conseiller"
    },
    "not_eligible": {
      "title": "💡 Voyons des alternatives",
      "message": "Sans budget et sans bourse, la Turquie est compliquée. Le Maroc serait plus accessible.",
      "cta": "Voir le Maroc"
    }
  }
}
```

---

# 7. 🇦🇪 EAU (DUBAÏ) — **Fiche basée sur GBS Dubai**

```yaml
code: ARE
name_fr: EAU (Dubaï)
flag_emoji: 🇦🇪
tagline_fr: "Études en anglais à Dubaï, dans une économie mondiale dynamique"
next_intake_label: "Septembre 2026 (4 intakes annuels possibles)"
main_language: "Anglais"
avg_tuition_min_eur: 6000
avg_tuition_max_eur: 12000
monthly_living_cost_eur: 1100
partners: ["GBS Dubai"]
```

## Description marketing

Étudier aux Émirats Arabes Unis à Dubaï, c'est intégrer une ville-monde où l'économie, le tourisme, la finance et la tech tirent l'Afrique et l'Asie vers le haut. **KPB est partenaire avec GBS Dubai** (Global Banking School), institution qui propose des programmes en **anglais à tous les niveaux** : du Diploma jusqu'au HND (Higher National Diploma), en passant par des programmes courts professionnalisants (ACCA, Investment Banking).

GBS Dubai propose aussi un **parcours d'apprentissage de l'anglais** pour les étudiants francophones qui veulent monter en niveau avant d'entamer un cursus académique anglophone.

## Pourquoi Dubaï ?

- 🇦🇪 Hub financier et économique mondial
- 🎓 Programmes anglophones courts et professionnalisants (1-2 ans)
- 💼 Marché du travail dynamique post-études
- ✈️ Vols directs Emirates / FlyDubai depuis l'Afrique
- 🌞 Sécurité, modernité, infrastructures
- 📅 4 intakes par an (janvier, mars, juin, septembre)

## Conditions d'accès (basées sur GBS Dubai)

### Diploma (Level 2) — 1 an
- Diplôme équivalent fin secondaire (HSC, Grade 12)
- Anglais : IELTS 4.5 / TOEFL iBT 35 / PTE 40 / Duolingo 65
- Frais : ~25 000 AED / an (~6 000 €)

### Extended Diploma (Level 3) — 1 an
- Idem ci-dessus
- Frais : ~40 000 AED / an (~10 000 €)

### HND (Higher National Diploma — Level 5) — 2 ans
- Grade 12/HSC avec minimum 50 % (ou IB 24 / GPA 2.0)
- Anglais : IELTS 5.5 / TOEFL iBT 46 / PTE 51 / Duolingo 95
- Âge minimum 17 ans
- Frais : ~40 000 AED / an

### Programmes pro (ACCA, Investment Banking, etc.)
- Selon programme — généralement Diploma ou HND validé
- Frais : 8 000 à 18 500 AED selon niveau

## Apprentissage de l'anglais à GBS Dubai
Si ton niveau d'anglais est insuffisant à l'arrivée, GBS Dubai propose des modules d'**English Pre-sessional** pour atteindre le niveau requis avant intégration du cursus.

## Quiz d'éligibilité EAU / Dubaï (5 questions)

```json
{
  "country_code": "ARE",
  "questions": [
    {
      "id": "q1_age",
      "text": "Quel est ton âge ?",
      "type": "single_select",
      "options": [
        {"value": "under_17", "label": "Moins de 17 ans"},
        {"value": "17_25", "label": "17 à 25 ans"},
        {"value": "over_25", "label": "Plus de 25 ans"}
      ]
    },
    {
      "id": "q2_diploma",
      "text": "Quel est ton dernier diplôme ?",
      "type": "single_select",
      "options": [
        {"value": "secondary", "label": "Bac / fin secondaire"},
        {"value": "diploma", "label": "Bac+2 / Diploma"},
        {"value": "bachelor", "label": "Bachelor / Licence"},
        {"value": "none", "label": "Aucun encore"}
      ]
    },
    {
      "id": "q3_english_level",
      "text": "Quel est ton niveau d'anglais ?",
      "type": "single_select",
      "options": [
        {"value": "advanced", "label": "Avancé (IELTS 5.5+)"},
        {"value": "intermediate", "label": "Intermédiaire (IELTS 4.5)"},
        {"value": "basic", "label": "Scolaire / faible"},
        {"value": "none", "label": "Aucune notion"}
      ]
    },
    {
      "id": "q4_budget",
      "text": "Quel budget annuel peux-tu mobiliser (scolarité) ?",
      "type": "single_select",
      "options": [
        {"value": "low", "label": "Moins de 25 000 AED (~6 000 €)"},
        {"value": "medium", "label": "25 000 - 50 000 AED"},
        {"value": "high", "label": "Plus de 50 000 AED"}
      ]
    },
    {
      "id": "q5_program",
      "text": "Quel type de programme te tente ?",
      "type": "single_select",
      "options": [
        {"value": "short_pro", "label": "Court et pro (ACCA, Banking)"},
        {"value": "diploma", "label": "Diploma 1-2 ans"},
        {"value": "hnd", "label": "HND 2 ans (équiv. Bac+2)"},
        {"value": "english_prep", "label": "D'abord apprendre l'anglais"}
      ]
    }
  ],
  "scoring_rules": {
    "eligible": "q1 in ['17_25', 'over_25'] AND q2 != 'none' AND q3 in ['advanced', 'intermediate'] AND q4 != 'low'",
    "eligible_with_conditions": "q3 == 'basic' OR q3 == 'none' OR q5 == 'english_prep'",
    "not_eligible": "q1 == 'under_17' OR (q2 == 'none' AND q5 != 'english_prep') OR q4 == 'low'"
  },
  "verdicts": {
    "eligible": {
      "title": "🎉 Dubaï t'attend",
      "message": "Avec GBS Dubai et son catalogue de programmes anglophones, ton projet est solide. 4 intakes par an, donc beaucoup de flexibilité.",
      "cta": "Demander un accompagnement EAU"
    },
    "eligible_with_conditions": {
      "title": "🟡 D'abord l'anglais, puis le diplôme",
      "message": "GBS Dubai propose un module Pre-sessional English. On peut t'inscrire en deux étapes : langue puis programme.",
      "cta": "Discuter avec un conseiller"
    },
    "not_eligible": {
      "title": "💡 Pas encore le bon moment",
      "message": "Sans bac ou avec un budget trop bas, l'EAU est tendu. Voyons d'autres options accessibles.",
      "cta": "Voir le Maroc et la Turquie"
    }
  }
}
```

---

# 8. 🇬🇧 ROYAUME-UNI — **Fiche propre, universités globalement**

```yaml
code: GBR
name_fr: Royaume-Uni
flag_emoji: 🇬🇧
tagline_fr: "Études dans des universités prestigieuses, anglais natif"
next_intake_label: "Janvier 2027"
main_language: "Anglais"
avg_tuition_min_eur: 13000
avg_tuition_max_eur: 35000
monthly_living_cost_eur: 1300
note: "Inscription dans les universités globalement (pas de partenariat exclusif au MVP)"
```

## Description marketing

Le Royaume-Uni reste l'une des destinations les plus prisées au monde pour ses universités prestigieuses (Oxford, Cambridge, Imperial, LSE, UCL, King's College…). Son système académique est reconnu mondialement pour sa rigueur, son approche par la recherche et son autonomie laissée aux étudiants.

**KPB t'accompagne dans la candidature aux universités britanniques de ton choix** (procédure UCAS pour Bachelor, candidature directe pour Master/PhD), depuis la sélection du programme jusqu'à l'obtention du visa Student et l'arrivée. La **Graduate Route** te permet de rester travailler 2 ans après ton diplôme.

## Pourquoi le Royaume-Uni ?

- 🏛️ Universités parmi les meilleures au monde
- 🎓 Bachelor en 3 ans (1 an de moins qu'aux USA)
- 💼 Graduate Route : 2 ans pour chercher du travail post-études
- 🌍 Anglais natif (immersion totale)
- 🇪🇺 Toujours proche de l'Europe malgré le Brexit

## Conditions d'accès par niveau

### Foundation Year (préparatoire pré-Bachelor)
- Diplôme secondaire avec dossier en deçà des critères directs
- Anglais IELTS 4.5-5.5
- Permet d'accéder ensuite au Bachelor

### Bachelor (Licence) — via UCAS
- Diplôme secondaire conforme aux exigences (équiv. A-Level)
- IELTS 6.0+ / TOEFL iBT 80+
- Certains programmes : tests spécifiques (UCAT médecine, LNAT droit)
- Frais : 12 000 - 35 000 GBP/an (international students)

### Master
- Licence ou équivalent avec moyenne d'au moins 60 % (GPA 3.0)
- IELTS 6.5+ / TOEFL iBT 90+
- MBA : parfois GMAT
- Frais : 12 000 - 45 000 GBP/an

### Doctorat (PhD)
- Master (ou Licence très brillante)
- IELTS 7.0+ / TOEFL iBT 100+
- Projet de recherche + accord superviseur
- Bourses disponibles (Commonwealth, Chevening)

## Capacité financière pour le visa Student
- Londres : 1 334 GBP/mois pour 9 mois (~12 000 GBP)
- Reste du pays : 1 023 GBP/mois pour 9 mois (~9 200 GBP)
- À justifier en plus des frais de scolarité

## Quiz d'éligibilité UK (6 questions)

```json
{
  "country_code": "GBR",
  "questions": [
    {
      "id": "q1_level",
      "text": "Quel est ton niveau d'études ?",
      "type": "single_select",
      "options": [
        {"value": "terminale", "label": "Terminale"},
        {"value": "bachelor", "label": "Bachelor / Licence"},
        {"value": "master", "label": "Master"}
      ]
    },
    {
      "id": "q2_english_level",
      "text": "Quel est ton niveau d'anglais ?",
      "type": "single_select",
      "options": [
        {"value": "advanced", "label": "Avancé (IELTS 6.5+)"},
        {"value": "intermediate", "label": "Intermédiaire (IELTS 5.5-6.0)"},
        {"value": "basic", "label": "IELTS 4.5 ou moins / scolaire"}
      ]
    },
    {
      "id": "q3_grades",
      "text": "Quelle est ta moyenne estimée ?",
      "type": "single_select",
      "options": [
        {"value": "excellent", "label": "Plus de 16/20"},
        {"value": "good", "label": "14-16/20"},
        {"value": "average", "label": "12-14/20"},
        {"value": "below", "label": "Moins de 12/20"}
      ]
    },
    {
      "id": "q4_budget",
      "text": "Quel budget annuel peux-tu mobiliser (scolarité + vie) ?",
      "type": "single_select",
      "options": [
        {"value": "low", "label": "Moins de 20 000 GBP"},
        {"value": "medium", "label": "20 000 - 35 000 GBP"},
        {"value": "high", "label": "35 000 - 50 000 GBP"},
        {"value": "very_high", "label": "Plus de 50 000 GBP"}
      ]
    },
    {
      "id": "q5_university_target",
      "text": "Quel type d'université vises-tu ?",
      "type": "single_select",
      "options": [
        {"value": "top_tier", "label": "Top tier (Oxford, Cambridge, Russell Group)"},
        {"value": "good", "label": "Bonne réputation"},
        {"value": "accessible", "label": "Plus accessible / régionale"},
        {"value": "no_pref", "label": "Pas de préférence"}
      ]
    },
    {
      "id": "q6_visa_history",
      "text": "As-tu déjà eu un refus de visa UK ?",
      "type": "single_select",
      "options": [
        {"value": "no", "label": "Non"},
        {"value": "yes_recent", "label": "Oui, il y a moins de 2 ans"},
        {"value": "yes_old", "label": "Oui, plus de 2 ans"}
      ]
    }
  ],
  "scoring_rules": {
    "eligible": "q2 in ['advanced', 'intermediate'] AND q3 in ['excellent', 'good'] AND q4 in ['medium', 'high', 'very_high'] AND q6 != 'yes_recent'",
    "eligible_with_conditions": "q2 == 'basic' OR q3 == 'average' OR q4 == 'low' OR q6 == 'yes_recent'",
    "not_eligible": "q4 == 'low' AND q3 == 'below'"
  },
  "verdicts": {
    "eligible": {
      "title": "🎉 Le UK est dans tes cordes",
      "message": "Profil cohérent. La rentrée Janvier 2027 te laisse le temps de bien préparer ta candidature UCAS et ton dossier visa.",
      "cta": "Demander un accompagnement UK"
    },
    "eligible_with_conditions": {
      "title": "🟡 Foundation Year ou prépa anglais possible",
      "message": "Une année préparatoire en UK (Foundation) ou de l'anglais en amont peut combler ce qu'il manque. On en parle ?",
      "cta": "Discuter avec un conseiller"
    },
    "not_eligible": {
      "title": "💡 Le UK est cher, alternatives ?",
      "message": "Sans budget conséquent, le UK est très tendu. Les EAU (anglais aussi) ou la Turquie sont plus accessibles.",
      "cta": "Voir les EAU et la Turquie"
    }
  }
}
```

---

# 9. 🇪🇸 ESPAGNE — **Fiche basée sur Schiller Madrid**

```yaml
code: ESP
name_fr: Espagne
flag_emoji: 🇪🇸
tagline_fr: "Études en anglais en plein cœur de Madrid"
next_intake_label: "Septembre 2026"
main_language: "Anglais"
avg_tuition_min_eur: 15000
avg_tuition_max_eur: 20000
monthly_living_cost_eur: 900
partners: ["Schiller International University - Madrid"]
```

## Description marketing

Étudier en Espagne, c'est combiner **excellence académique anglophone** et **art de vivre méditerranéen**. KPB est partenaire avec **Schiller International University** sur son campus de Madrid, université américaine accréditée proposant des programmes 100 % en anglais : International Business, International Relations, Computer Science, Applied Mathematics & AI, Marketing, Hospitality, et un MBA international.

Schiller permet aussi de **basculer entre campus** (Madrid, Paris, Heidelberg, Tampa) au cours du cursus, une flexibilité unique en Europe.

## Pourquoi l'Espagne ?

- 🇪🇸 Madrid : capitale dynamique, coût de vie modéré (~ 900 €/mois)
- 🇬🇧 Programmes 100 % en anglais (pas besoin d'espagnol au lancement)
- 🌍 Université américaine accréditée (diplôme reconnu USA + Europe)
- ✈️ Flexibilité multi-campus Schiller (Paris, Heidelberg, Tampa)
- 🇪🇺 Visa étudiant Schengen + travail post-études

## Conditions d'accès (Schiller Madrid)

### Bachelor (4 ans)
- Diplôme secondaire (high school / bac) officiel
- **Anglais** : TOEFL iBT 51, IELTS 5.5, TOEIC 650, Duolingo 95, PTE 46 (ou équivalent — exemption possible)
- Dossier : transcripts, preuve secondaire, lettre de motivation
- Frais : **15 420 €/an**

### Master / MBA (1-2 ans)
- Bachelor ou équivalent
- Évaluation de transcript selon profil international
- Anglais (preuve requise)
- Frais : 16 500 à 20 700 €/an selon programme (MBA International = 20 700 €)
- Dossier : Bachelor transcript/diplôme + application file + langue

## Programmes disponibles (Schiller Madrid)

**Bachelor (4 ans, anglais)** :
- BA in International Relations and Diplomacy
- BS in International Business
- BS in International Hospitality and Tourism Management
- BS in International Marketing
- BS in Computer Science
- BS in Applied Mathematics and AI
- BS in Business Analytics

**Master/MBA (1-2 ans, anglais)** :
- MA in International Relations and Diplomacy
- MS in Digital Marketing and E-commerce
- MS in Global Finance
- MS in Sustainability Management
- MS in Data Science
- MBA
- MBA in International Business

## Quiz d'éligibilité Espagne (6 questions)

```json
{
  "country_code": "ESP",
  "questions": [
    {
      "id": "q1_level",
      "text": "Quel est ton niveau d'études actuel ?",
      "type": "single_select",
      "options": [
        {"value": "terminale", "label": "Terminale"},
        {"value": "bachelor", "label": "Bachelor / Licence"},
        {"value": "master_or_more", "label": "Master ou plus"}
      ]
    },
    {
      "id": "q2_diploma",
      "text": "As-tu un diplôme du secondaire officiel ?",
      "type": "single_select",
      "options": [
        {"value": "yes_obtained", "label": "Oui, déjà obtenu"},
        {"value": "yes_this_year", "label": "Je l'obtiens cette année"},
        {"value": "no", "label": "Non"}
      ]
    },
    {
      "id": "q3_english_level",
      "text": "Quel est ton niveau d'anglais ?",
      "type": "single_select",
      "options": [
        {"value": "advanced", "label": "Avancé (TOEFL 51+/IELTS 5.5+/équiv.)"},
        {"value": "intermediate", "label": "Intermédiaire (TOEFL ~45)"},
        {"value": "basic", "label": "Scolaire / faible"},
        {"value": "exempt", "label": "Anglais langue maternelle ou de scolarité"}
      ]
    },
    {
      "id": "q4_budget",
      "text": "Quel budget annuel peux-tu mobiliser (scolarité) ?",
      "type": "single_select",
      "options": [
        {"value": "low", "label": "Moins de 12 000 €"},
        {"value": "medium", "label": "12 000 - 17 000 €"},
        {"value": "high", "label": "Plus de 17 000 €"}
      ]
    },
    {
      "id": "q5_field",
      "text": "Quel domaine te tente le plus ?",
      "type": "single_select",
      "options": [
        {"value": "business", "label": "Business / Finance / Marketing"},
        {"value": "tech", "label": "Computer Science / Data / AI"},
        {"value": "international", "label": "Relations Internationales / Diplomatie"},
        {"value": "hospitality", "label": "Hôtellerie / Tourisme"},
        {"value": "other", "label": "Autre"}
      ]
    },
    {
      "id": "q6_mobility",
      "text": "T'intéresse-t-il de pouvoir basculer entre campus (Madrid, Paris, Heidelberg, Tampa) ?",
      "type": "single_select",
      "options": [
        {"value": "yes_priority", "label": "Oui, c'est un gros atout"},
        {"value": "maybe", "label": "Peut-être"},
        {"value": "no", "label": "Non, je reste à Madrid"}
      ]
    }
  ],
  "scoring_rules": {
    "eligible": "q2 in ['yes_obtained', 'yes_this_year'] AND q3 in ['advanced', 'exempt'] AND q4 != 'low'",
    "eligible_with_conditions": "q3 == 'intermediate' OR q4 == 'low'",
    "not_eligible": "q2 == 'no' AND q4 == 'low'"
  },
  "verdicts": {
    "eligible": {
      "title": "🎉 Madrid t'ouvre les bras",
      "message": "Profil compatible avec Schiller Madrid. La flexibilité multi-campus te donne en plus un cursus unique en Europe.",
      "cta": "Demander un accompagnement Espagne"
    },
    "eligible_with_conditions": {
      "title": "🟡 Anglais à renforcer ou budget à ajuster",
      "message": "Schiller Madrid reste accessible, mais il faut sécuriser l'anglais (TOEFL/IELTS) ou cadrer le budget. On t'aide.",
      "cta": "Discuter avec un conseiller"
    },
    "not_eligible": {
      "title": "💡 L'Espagne est tendue, regardons ailleurs",
      "message": "Sans diplôme et avec un budget serré, l'Espagne n'est pas la meilleure option. Le Maroc ou la Turquie sont plus accessibles.",
      "cta": "Voir le Maroc et la Turquie"
    }
  }
}
```

---

# 10. Script SQL de seed (à exécuter au déploiement)

```sql
-- ===========================
-- SEED COUNTRIES
-- ===========================
INSERT INTO countries (code, name_fr, flag_emoji, tagline_fr, next_intake_label, main_language, avg_tuition_min_eur, avg_tuition_max_eur, monthly_living_cost_eur, display_order, is_active)
VALUES
  ('FRA', 'France', '🇫🇷', 'Étudier au cœur de l''Europe, dans des écoles privées d''excellence', 'Septembre 2026', 'Français', 5000, 18000, 1000, 1, true),
  ('DEU', 'Allemagne', '🇩🇪', 'Universités publiques gratuites + offre exclusive cours de langue', 'Septembre 2026', 'Allemand (Anglais)', 0, 1500, 992, 2, true),
  ('USA', 'USA', '🇺🇸', 'Le plus grand écosystème universitaire au monde', 'Septembre 2026', 'Anglais', 15000, 50000, 1200, 3, true),
  ('CAN', 'Canada', '🇨🇦', 'Qualité de vie, multiculturalisme et résidence post-diplôme', 'Janvier 2027', 'Anglais et Français', 7000, 25000, 1100, 4, true),
  ('MAR', 'Maroc', '🇲🇦', 'Études francophones de qualité, proche de chez toi', 'Septembre 2026', 'Français', 2500, 6000, 400, 5, true),
  ('TUR', 'Turquie', '🇹🇷', 'Universités modernes, frais abordables, pont entre Europe et Asie', 'Septembre 2026', 'Anglais (Turc)', 4000, 12000, 500, 6, true),
  ('ARE', 'EAU (Dubaï)', '🇦🇪', 'Études en anglais à Dubaï, dans une économie mondiale dynamique', 'Septembre 2026 (4 intakes/an)', 'Anglais', 6000, 12000, 1100, 7, true),
  ('GBR', 'Royaume-Uni', '🇬🇧', 'Études dans des universités prestigieuses, anglais natif', 'Janvier 2027', 'Anglais', 13000, 35000, 1300, 8, true),
  ('ESP', 'Espagne', '🇪🇸', 'Études en anglais en plein cœur de Madrid', 'Septembre 2026', 'Anglais', 15000, 20000, 900, 9, true);

-- ===========================
-- SEED ELIGIBILITY QUIZZES
-- À insérer ensuite : 1 quiz par pays, voir contenu JSON détaillé plus haut
-- ===========================
```

---

**FIN ANNEXE 04**
