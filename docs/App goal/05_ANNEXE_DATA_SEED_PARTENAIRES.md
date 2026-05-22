# 🏫 ANNEXE 05 — DATA SEED : ÉCOLES & PROGRAMMES PARTENAIRES

**Référence** : Cahier des charges KPB Education V1
**Usage** : Données initiales à insérer dans `partner_schools` + `programs`

---

# Vue d'ensemble

| Source | Écoles | Programmes | Format |
|---|---|---|---|
| Cette annexe | 6 écoles | 61 programmes | YAML/JSON structuré |
| Fichier OMNES (xlsx) | 6 écoles | **748 programmes** | À importer via script depuis `OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx` |
| **TOTAL** | **12 écoles** | **~810 programmes** | |

## ⚠️ Note importante sur l'import OMNES

Le fichier `OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx` contient 748 programmes répartis sur 6 écoles du groupe OMNES Education :
- **ECE** (École Centrale Électronique)
- **ESCE** (École Supérieure du Commerce Extérieur)
- **HEIP** (Hautes Études Internationales et Politiques)
- **INSEEC** (École de commerce)
- **IUM** (International University of Monaco)
- **Sup de Pub** (École de communication)

8 campus français : Paris, Lyon, Bordeaux, Beaune, Chambéry, Marseille, Rennes, Toulouse.

**Action Antigravity** : créer un script `seed_omnes.js` ou `seed_omnes.py` qui lit le xlsx et insère chaque ligne comme un programme rattaché à son école OMNES, avec :
- `school.partner_group = 'OMNES Education'`
- `school.country_id = (code='FRA')`
- `program.school_id = ` école correspondante
- `program.tuition_amount = ` colonne "Payment Comptant"
- `program.tuition_installments = ` colonne "Paiement Echelonné"
- `program.intake_date = ` colonne "Date_de_Rentrée"
- `program.language_of_instruction = ` mapper depuis colonne Langue (FR/EN/MX)
- `program.campus = ` colonne Campus

---

# 1. ICN BUSINESS SCHOOL (France / Allemagne)

```yaml
slug: icn-business-school
name: ICN Business School
country_id: # FRA pour le siège, mais aussi DEU pour Berlin
cities: [Paris, Berlin]
partner_status: partner
partner_group: Standalone
description: "Grande école de management à triple accréditation (AACSB, EQUIS, AMBA). Campus à Paris La Défense et Berlin."
is_featured: true
website_url: https://www.icn-artem.com/
source_urls:
  - https://wpapi.icn-artem.com/app/uploads/2024/09/ICN-Tuitions-2025-26.pdf
  - https://wpapi.icn-artem.com/app/uploads/2024/12/ICN_Plaquette_BBA_2024_EN_WEB.pdf
```

## Programmes ICN (8 programmes)

| # | Nom | Niveau | Campus | Durée | Langue | Frais | Devise | Période |
|---|---|---|---|---|---|---|---|---|
| 1 | International BBA | Bachelor | Paris La Défense | 4 ans | Bilingue EN/FR | 9 900 | EUR | par an |
| 2 | International BBA | Bachelor | Berlin | 4 ans | EN | 9 900 | EUR | par an |
| 3 | Bachelor in Management | Bachelor | Paris/Berlin (à confirmer) | 3 ans | FR/EN | 9 200 | EUR | par an |
| 4 | Bachelor Tech & Innovation Management | Bachelor | Paris/Berlin (à confirmer) | 3 ans | FR/EN | 8 000 | EUR | par an |
| 5 | Master in Management (Grande École) | Master | Paris/Berlin (à confirmer) | 2 ans | FR/EN | 14 500 | EUR | par an |
| 6 | MSc in International Management MIEX | Master | Paris/Berlin (à confirmer) | 2 ans | EN | 10 000 | EUR | Année 1 (Année 2 : 4 000 à 10 000 EUR partenaire) |
| 7 | MSc (DESSMI) | Master | Paris/Berlin (à confirmer) | 2 ans | EN/FR | 9 500 | EUR | Année 1 (Année 2 : 16 000 EUR ; direct M2 : 16 000 EUR) |
| 8 | PhD | PhD | Paris/Berlin (à confirmer) | Variable | EN/FR | 9 000 | EUR | par an |
| 9 | DBA | DBA | Paris/Berlin (à confirmer) | Variable | EN/FR | 30 000 | EUR | programme entier |

### Conditions communes ICN
- **Académique** : Année 1 : Bac ou équivalent. Année 2 : 1 an d'études supérieures validé.
- **Langue** : entretien/oral d'anglais à l'admission.
- **Documents** : relevés de notes, CV, lettre de motivation en anglais, dossier de candidature.
- **Process** : examen dossier + entretien + oral d'anglais.

---

# 2. SCHILLER INTERNATIONAL UNIVERSITY (Espagne / France / Allemagne / USA)

```yaml
slug: schiller-international-university
name: Schiller International University
country_id: # Plusieurs pays
cities: [Madrid, Paris, Heidelberg, Tampa]
partner_status: partner
partner_group: Standalone
description: "Université américaine accréditée avec campus européens (Madrid, Paris, Heidelberg) et campus américain (Tampa). Tous les programmes sont en anglais. Possibilité de basculer entre campus pendant le cursus."
is_featured: true
website_url: https://www.schiller.edu/
source_urls:
  - https://www.schiller.edu/admissions/tuition-and-fees/
  - https://www.schiller.edu/admissions/requirements/
```

## Programmes Schiller — Campus Européens (Madrid/Paris/Heidelberg) — 13 programmes

### Bachelor (4 ans, anglais, 15 420 € par an)
| # | Nom |
|---|---|
| 1 | BA in International Relations and Diplomacy |
| 2 | BS in International Business |
| 3 | BS in International Hospitality and Tourism Management |
| 4 | BS in International Marketing |
| 5 | BS in Computer Science |
| 6 | BS in Applied Mathematics and Artificial Intelligence |
| 7 | BS in Business Analytics |

### Master/MBA (anglais, voir détails par programme)
| # | Nom | Frais annuels |
|---|---|---|
| 8 | MA in International Relations and Diplomacy | 16 560 € |
| 9 | MS in Digital Marketing and E-commerce | 16 560 € |
| 10 | MS in Global Finance | 16 560 € |
| 11 | MS in Sustainability Management | 16 500 € |
| 12 | MS in Data Science | 16 500 € |
| 13 | MBA | 16 560 € |
| 14 | MBA in International Business | 20 700 € |

## Programmes Schiller — Campus Tampa (USA) — 14 programmes

### Bachelor (4 ans, anglais, 17 610 USD par an)
Mêmes 7 Bachelor que ci-dessus

### Master/MBA (anglais)
| # | Nom | Frais annuels |
|---|---|---|
| 8 | MA in International Relations and Diplomacy | 19 620 USD |
| 9 | MS in Digital Marketing and E-commerce | 19 620 USD |
| 10 | MS in Global Finance | 19 620 USD |
| 11 | MS in Sustainability Management | 19 410 USD |
| 12 | MS in Data Science | 19 410 USD |
| 13 | MBA | 19 620 USD |
| 14 | MBA in International Business | 24 525 USD |

### Conditions communes Schiller
- **Académique** : diplôme secondaire (Bachelor) ou Bachelor (Master) officiel
- **Langue** : TOEFL iBT 51 / IELTS 5.5 / TOEIC 650 / Duolingo 95 / PTE 46 (exemption possible)
- **Documents** : transcripts, preuve secondaire, contrat d'inscription signé
- **Process** : candidature en ligne, examen admissions, étapes visa/financières pour internationaux

---

# 3. ISMAGI (Maroc - Rabat)

```yaml
slug: ismagi
name: ISMAGI
country_id: # MAR
cities: [Rabat]
partner_status: partner
partner_group: Standalone
description: "Institut Supérieur de Management et d'Administration des Affaires. Établissement marocain offrant Licences, Masters et Cycle d'Ingénieur dans le management et l'IT."
website_url: https://ismagi.ma/
source_urls:
  - https://ismagi.ma/admission-post-bac/
  - https://ismagi.ma/frais-de-scolarite/
note: "Frais d'inscription/réinscription annuels supplémentaires : 5 000 MAD"
```

## Programmes ISMAGI (18 programmes)

### Licences Management (4 programmes, 3 ans, français, 40 000 MAD/an)
| # | Nom |
|---|---|
| 1 | Comptabilité, Contrôle et Audit |
| 2 | Marketing Digital & Développement Commercial |
| 3 | Logistique, Transport et Commerce International |
| 4 | Gestion des Ressources Humaines |

### Licences IT (4 programmes, 3 ans, français, 40 000 MAD/an)
| # | Nom |
|---|---|
| 5 | Développement Multimédia et Animation 3D |
| 6 | Blockchain et Cryptographie |
| 7 | Développement Web et Mobile |
| 8 | IoT et Systèmes Intelligents |

### Classes préparatoires (1 programme, 2 ans, français, 40 000 MAD/an)
| # | Nom |
|---|---|
| 9 | Classes préparatoires intégrées (vers ingénierie info, auto, data) |

### Cycle d'Ingénieur (2 programmes, français, 45 000 MAD/an)
| # | Nom |
|---|---|
| 10 | Ingénierie Informatique |
| 11 | Ingénierie Data Science et Biotech |

### Masters (7 programmes, français/mixte, 45 000 MAD/an)
| # | Nom |
|---|---|
| 12 | Master en Gestion Opérationnelle et Stratégies des Entreprises |
| 13 | Master en Qualité, Hygiène, Sécurité, Environnement |
| 14 | Master en Comptabilité, Contrôle et Audit |
| 15 | Master en IoT et Data Science |
| 16 | Master Fintech and Risk Management |
| 17 | Master Développement Logiciel, Mobile et IoT |
| 18 | Master Digital Marketing and Communication |

### Conditions communes ISMAGI
- **Académique** : Bac toutes séries (Licences Management) / Bac scientifique, économique ou technique (Licences IT) / Bac scientifique (Classes préparatoires)
- **Langue** : enseignement principal en français
- **Documents** : copie bac, relevés, pièces d'identité, dossier de candidature
- **Process** : examen dossier puis test écrit/oral

---

# 4. ÉCOLE SUPÉRIEURE DES AFFAIRES (ESA) CASABLANCA

```yaml
slug: esa-casablanca
name: École Supérieure des Affaires (ESA) Casablanca
country_id: # MAR
cities: [Casablanca]
partner_status: partner
partner_group: IGENSIA Education
description: "École de management basée à Casablanca, partie du groupe IGENSIA Education. Programmes Bachelor en Management et Finance."
website_url: https://www.esa-igensia.ma/
source_urls:
  - https://www.esa-igensia.ma/formations/bachelor-management
  - https://www.esa-igensia.ma/formations/bachelor-finance
note: "International : B1 5 500 EUR / 60 000 MAD ; B2-B3 5 000 EUR / 55 000 MAD. Étudiants marocains généralement 5 000 EUR / 55 000 MAD."
```

## Programmes ESA Casablanca (2 programmes)

| # | Nom | Niveau | Durée | Langue | Frais B1 | Frais B2-B3 |
|---|---|---|---|---|---|---|
| 1 | Bac+3 Gestion des entreprises - Option Management | Bachelor/Bac+3 | 3 ans | Français (~20% EN en B1, ~30% en B2/B3) | 5 500 EUR | 5 000 EUR |
| 2 | Bac+3 Gestion des entreprises - Option Finance | Bachelor/Bac+3 | 3 ans | Idem | 5 500 EUR | 5 000 EUR |

### Conditions communes ESA Casablanca
- **Académique** : Année 1 : Bac validé ou en cours. Année 2 : Bac + 1ère année de management validée. Année 3 : Bac+2 ou Bac+3 en disciplines management.
- **Langue** : enseignement en français. Voie orale seule possible avec TCF minimum 300 dans cas spécifiés.
- **Documents** : dossier candidature, relevés, entretien de motivation.
- **Process** : test écrit + oral pour Année 1 ; dossier + entretien pour admissions parallèles.
- **Intake** : Septembre.

---

# 5. BAHÇEŞEHIR UNIVERSITY (BAU) ISTANBUL

```yaml
slug: bau-istanbul
name: Bahçeşehir University (BAU) Istanbul
country_id: # TUR
cities: [Istanbul]
partner_status: partner
partner_group: Standalone
description: "L'une des meilleures universités privées turques. Programmes anglophones dans de nombreux domaines (Business, Engineering, Computer Science, AI, Medicine, Architecture, Design)."
is_featured: true
website_url: https://int.bau.edu.tr/
source_urls:
  - https://int.bau.edu.tr/programs/
  - https://int.bau.edu.tr/admission/
  - https://int.bau.edu.tr/admission/tuition-fees/
note: "Intake : Fall (Septembre) uniquement pour Undergraduate"
```

## Programmes BAU Istanbul (9 programmes — Bachelor uniquement au catalogue partagé)

| # | Nom | Famille | Durée | Langue | Frais | Devise |
|---|---|---|---|---|---|---|
| 1 | Business Administration | Business | 4 ans | Anglais | 8 500 | USD/an |
| 2 | International Trade and Business | Business | 4 ans | Anglais | 8 500 | USD/an |
| 3 | International Finance | Finance | 4 ans | Anglais | 8 500 | USD/an |
| 4 | Computer Engineering | Engineering | 4 ans | Anglais | 9 000 | USD/an |
| 5 | Software Engineering | Engineering | 4 ans | Anglais | 9 000 | USD/an |
| 6 | Artificial Intelligence Engineering | Engineering/AI | 4 ans | Anglais | 12 000 | USD/an |
| 7 | Medicine | Medicine | 6 ans | Anglais | 28 000 | USD/an |
| 8 | Architecture | Architecture | 4 ans | Anglais | 8 500 | USD/an |
| 9 | Textile and Fashion Design | Design | 4 ans | Anglais | 8 500 | USD/an |

### Conditions communes BAU Istanbul
- **Académique** : candidature en ligne ; passeport, relevés secondaires, diplôme si disponible
- **Langue** : certificat de langue non requis au stade de candidature pour beaucoup de programmes (peut être demandé à l'inscription selon la langue du programme)
- **Documents spéciaux** : lettre de motivation (Médecine), portfolio (Design/Arts sélectionnés)
- **Process** : candidature en ligne ; originaux/traductions/apostille possibles à l'inscription
- **Note** : le catalogue BAU complet est beaucoup plus large que ces 9 programmes — c'est une liste de programmes phares en anglais. À enrichir progressivement.

---

# 6. GBS DUBAI (Global Banking School - Dubaï)

```yaml
slug: gbs-dubai
name: GBS Dubai
country_id: # ARE
cities: [Dubai]
partner_status: partner
partner_group: Standalone
description: "Global Banking School à Dubaï. Programmes courts professionnalisants et HND (Higher National Diploma) dans Business, IT, Healthcare, Construction. 4 intakes par an."
is_featured: true
website_url: https://gbs.ac.ae/
source_urls:
  - https://gbs.ac.ae/fees-and-payment/
  - https://gbs.ac.ae/pages/english-requirements/
  - https://gbs.ac.ae/media/ndsb0144/gbs-dubai-admissions-policy-v2-0-oct24.pdf
note: "GBS publie bourses/réductions et options de paiement échelonné. Pour le programme Investment Banking, valider manuellement les frais avant publication."
```

## Programmes GBS Dubai (10 programmes)

### Diploma / Extended Diploma (Levels 2 & 3, 1 an, anglais)
| # | Nom | Niveau | Durée | Frais |
|---|---|---|---|---|
| 1 | International Diploma in Business | Level 2 | 1 an | 25 000 AED/an |
| 2 | International Extended Diploma in Business | Level 3 | 1 an | 40 000 AED/an |
| 3 | International Extended Diploma in IT | Level 3 | 1 an | 40 000 AED/an |

### HND (Higher National Diploma — Level 5, 2 ans, anglais, 40 000 AED/an)
| # | Nom |
|---|---|
| 4 | HND International in Business |
| 5 | HND in Digital Technologies (Cyber Security) |
| 6 | HND in Digital Technologies (Artificial Intelligence) |
| 7 | HND in Healthcare Practices (Healthcare Management) |
| 8 | HND in Construction Management |

### Programmes professionnels
| # | Nom | Niveau | Durée | Frais |
|---|---|---|---|---|
| 9 | ACCA (Association of Chartered Certified Accountants) | Professional | Variable | 8 000 - 18 500 AED selon level |
| 10 | Global Investment Banking Analyst Programme | Certificate/Short | 4 semaines | 10 000 AED (programme entier) |

### Conditions communes GBS Dubai
- **Académique** : varie selon programme et pays. HND : Grade 12/HSC minimum 50 %, IB 24, US GPA 2.0/4, âge minimum 17 ans pour pathways sélectionnés.
- **Langue (Levels 2-3)** : IELTS 4.5 / TOEFL iBT 35 / PTE 40 / Duolingo 65 ou équivalent
- **Langue (Levels 4-5 / pathways undergrad)** : IELTS 5.5 / TOEFL iBT 46 / PTE 51 / Duolingo 95 ou équivalent
- **Documents** : dossier candidature avec documents académiques
- **Process** : revue admissions ; contacter GBS/KPB pour équivalences spécifiques au pays
- **Intakes** : Janvier / Mars / Juin / Septembre (pour HND notamment)

---

# 7. SCRIPT D'IMPORT OMNES (à créer par Antigravity)

Le fichier `OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx` doit être importé automatiquement. Voici la structure d'import recommandée :

## 7.1 Schéma du fichier source

| Colonne Excel | Champ DB |
|---|---|
| Ecole / School | `partner_schools.name` (création si pas existante) |
| Type_Programme | `programs.program_family` |
| Niveau_Etude_ | `programs.degree_level` |
| Niveau Admission | `programs.admission_level` |
| Langue | `programs.language_of_instruction` (mapping FR/EN/MX) |
| Rythme | (à stocker dans `programs.internal_notes` ou un champ dédié) |
| Campus | `programs.campus` |
| NOM / NAME | `programs.name` |
| Payment Comptant | `programs.tuition_amount` |
| Paiement Echelonné (2) | `programs.tuition_installments` |
| Date_de_Rentrée | `programs.intake_date` |

## 7.2 Pseudo-code d'import

```python
import pandas as pd
from datetime import datetime

# 1. Lire le xlsx
df = pd.read_excel('OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx', sheet_name='TOUT PROGRAMME - ALL PROGRAMS')

# 2. Filtrer les lignes vides ou "Filtres appliqués"
df = df[df['Ecole / School'].isin(['ECE', 'ESCE', 'HEIP', 'INSEEC', 'IUM', 'Sup de Pub'])]

# 3. Pour chaque école unique, créer la fiche partner_school
schools = df['Ecole / School'].unique()
school_id_map = {}
for school_name in schools:
    school_id = create_or_get_school(
        name=school_name,
        slug=school_name.lower().replace(' ', '-'),
        country_id=FRA_ID,
        partner_group='OMNES Education',
        is_partner=True,
        cities=df[df['Ecole / School'] == school_name]['Campus'].unique().tolist()
    )
    school_id_map[school_name] = school_id

# 4. Pour chaque ligne, créer le programme
LANGUAGE_MAP = {'FR': 'Français', 'EN': 'Anglais', 'MX': 'Mixte FR/EN'}

for _, row in df.iterrows():
    create_program(
        school_id=school_id_map[row['Ecole / School']],
        name=row['NOM / NAME'],
        campus=row['Campus'],
        program_family=row['Type_Programme / Type of program'],
        degree_level=row['Niveau_Etude_ / Level of studies'],
        admission_level=row['Niveau Admission / Admission Level'],
        language_of_instruction=LANGUAGE_MAP.get(row['Langue / Language'], row['Langue / Language']),
        tuition_amount=row['Payment Comptant / Payment Upfront'],
        tuition_installments=row['Paiement Echelonné / With installments (2)'],
        tuition_currency='EUR',
        tuition_period='per year',
        intake_date=parse_date(row['Date_de_Rentrée / Intake Date']),
        status='active'
    )

# 5. Logger le résultat
print(f"Imported {len(df)} OMNES programs across {len(schools)} schools")
```

---

# 8. SCRIPT SQL DE SEED (extrait)

```sql
-- ===========================
-- SEED PARTNER SCHOOLS
-- ===========================
INSERT INTO partner_schools (slug, name, country_id, cities, partner_group, description, website_url, is_partner, is_featured)
VALUES
  ('icn-business-school',
   'ICN Business School',
   (SELECT id FROM countries WHERE code = 'FRA'),
   ARRAY['Paris', 'Berlin'],
   'Standalone',
   'Grande école de management à triple accréditation (AACSB, EQUIS, AMBA).',
   'https://www.icn-artem.com/',
   true,
   true),

  ('schiller-international-university',
   'Schiller International University',
   (SELECT id FROM countries WHERE code = 'ESP'), -- siège logique : Madrid
   ARRAY['Madrid', 'Paris', 'Heidelberg', 'Tampa'],
   'Standalone',
   'Université américaine accréditée avec campus en Espagne, France, Allemagne et USA. Tous les programmes en anglais.',
   'https://www.schiller.edu/',
   true,
   true),

  ('ismagi',
   'ISMAGI',
   (SELECT id FROM countries WHERE code = 'MAR'),
   ARRAY['Rabat'],
   'Standalone',
   'Institut Supérieur de Management et d''Administration des Affaires. Licences, Masters et Cycle d''Ingénieur.',
   'https://ismagi.ma/',
   true,
   false),

  ('esa-casablanca',
   'École Supérieure des Affaires (ESA) Casablanca',
   (SELECT id FROM countries WHERE code = 'MAR'),
   ARRAY['Casablanca'],
   'IGENSIA Education',
   'École de management basée à Casablanca, partie du groupe IGENSIA Education.',
   'https://www.esa-igensia.ma/',
   true,
   false),

  ('bau-istanbul',
   'Bahçeşehir University (BAU) Istanbul',
   (SELECT id FROM countries WHERE code = 'TUR'),
   ARRAY['Istanbul'],
   'Standalone',
   'Université privée turque de premier plan. Catalogue large en anglais.',
   'https://int.bau.edu.tr/',
   true,
   true),

  ('gbs-dubai',
   'GBS Dubai',
   (SELECT id FROM countries WHERE code = 'ARE'),
   ARRAY['Dubai'],
   'Standalone',
   'Global Banking School à Dubaï. Programmes courts pro et HND.',
   'https://gbs.ac.ae/',
   true,
   true);

-- ===========================
-- Ensuite, insérer programmes pour chaque école
-- (voir détail dans cette annexe pour les 61 programmes hors OMNES)
-- ===========================

-- ===========================
-- IMPORT OMNES via script (voir section 7)
-- ===========================
```

---

# 9. RÉCAPITULATIF VOLUMÉTRIE FINALE

| Source | Écoles | Programmes |
|---|---|---|
| ICN | 1 | 9 |
| Schiller (2 campus zones) | 1 | 27 |
| ISMAGI | 1 | 18 |
| ESA Casablanca | 1 | 2 |
| BAU Istanbul | 1 | 9 |
| GBS Dubai | 1 | 10 |
| **Sous-total cette annexe** | **6** | **75** |
| OMNES (depuis xlsx) | 6 | 748 |
| **TOTAL au lancement** | **12** | **~820** |

> **Note** : le décompte 75 (au lieu de 61 mentionné dans le résumé initial) vient du fait que Schiller a 14 programmes Bachelor + Master sur les campus européens + 14 sur Tampa, donc 27 en tout au lieu de 14 (le partner_schools.xlsx les avait dédupliqués différemment).

---

**FIN ANNEXE 05**
