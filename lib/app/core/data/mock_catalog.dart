// AUTO-GENERATED — KPB Education Base Orientation V2
// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';

import '../models/app_models.dart';

class MockCatalog {
  static const orientationQuestions = <OrientationQuestion>[
    OrientationQuestion(
      id: 'interests',
      prompt: LocalizedText(
          fr: 'Qu\'est-ce qui vous attire le plus ?',
          en: 'What attracts you most?'),
      multiSelect: true,
      options: [
        OrientationOption(
            id: 'tech',
            label: LocalizedText(
                fr: 'Résoudre des problèmes avec la technologie',
                en: 'Solving problems with technology'),
            weights: {'d01': 4, 'd05': 3}),
        OrientationOption(
            id: 'biz',
            label: LocalizedText(
                fr: 'Comprendre le commerce et les marchés',
                en: 'Understanding business and markets'),
            weights: {'d02': 4, 'd03': 3}),
        OrientationOption(
            id: 'health',
            label: LocalizedText(
                fr: 'Aider les personnes et améliorer leur santé',
                en: 'Helping people improve their health'),
            weights: {'d04': 4, 'd09': 1}),
        OrientationOption(
            id: 'law_pol',
            label: LocalizedText(
                fr: 'Défendre des droits et comprendre les institutions',
                en: 'Defend rights and understand institutions'),
            weights: {'d07': 4, 'd09': 2}),
        OrientationOption(
            id: 'create',
            label: LocalizedText(
                fr: 'Créer des visuels, des médias ou des expériences',
                en: 'Creating visuals, media or experiences'),
            weights: {'d06': 4, 'd11': 2}),
        OrientationOption(
            id: 'env',
            label: LocalizedText(
                fr: 'Protéger l\'environnement et travailler en agriculture',
                en: 'Protect the environment and work in agriculture'),
            weights: {'d08': 4, 'd10': 3}),
      ],
    ),
    OrientationQuestion(
      id: 'strengths',
      prompt: LocalizedText(
          fr: 'Dans quoi êtes-vous le plus à l\'aise ?',
          en: 'What are you most comfortable with?'),
      options: [
        OrientationOption(
            id: 'analysis',
            label: LocalizedText(
                fr: 'Analyse, logique et mathématiques',
                en: 'Analysis, logic and mathematics'),
            weights: {'d01': 4, 'd03': 4, 'd05': 3}),
        OrientationOption(
            id: 'communication',
            label: LocalizedText(
                fr: 'Communication, langues et persuasion',
                en: 'Communication, languages and persuasion'),
            weights: {'d06': 4, 'd02': 3, 'd07': 2}),
        OrientationOption(
            id: 'care',
            label: LocalizedText(
                fr: 'Empathie, écoute et accompagnement humain',
                en: 'Empathy, listening and human support'),
            weights: {'d04': 4, 'd09': 3}),
        OrientationOption(
            id: 'creativity',
            label: LocalizedText(
                fr: 'Créativité, design et sens esthétique',
                en: 'Creativity, design and aesthetic sense'),
            weights: {'d06': 4, 'd11': 3}),
        OrientationOption(
            id: 'leadership',
            label: LocalizedText(
                fr: 'Leadership, gestion d\'équipes et projets',
                en: 'Leadership, team and project management'),
            weights: {'d02': 4, 'd05': 2}),
      ],
    ),
    OrientationQuestion(
      id: 'goal',
      prompt: LocalizedText(
          fr: 'Quel est votre objectif principal ?',
          en: 'What is your main goal?'),
      options: [
        OrientationOption(
            id: 'global_job',
            label: LocalizedText(
                fr: 'Trouver un emploi international bien rémunéré',
                en: 'Land a well-paid international job'),
            weights: {'d01': 3, 'd02': 3, 'd03': 4}),
        OrientationOption(
            id: 'impact',
            label: LocalizedText(
                fr: 'Avoir un impact direct sur ma société',
                en: 'Have a direct impact on society'),
            weights: {'d04': 4, 'd07': 3, 'd08': 3}),
        OrientationOption(
            id: 'entrepreneur',
            label: LocalizedText(
                fr: 'Créer ma propre entreprise', en: 'Start my own business'),
            weights: {'d02': 4, 'd06': 2, 'd12': 2}),
        OrientationOption(
            id: 'research',
            label: LocalizedText(
                fr: 'Faire de la recherche ou de l\'enseignement',
                en: 'Do research or teaching'),
            weights: {'d09': 4, 'd05': 3, 'd04': 2}),
      ],
    ),
    OrientationQuestion(
      id: 'environment',
      prompt: LocalizedText(
          fr: 'Quel environnement de travail vous correspond ?',
          en: 'Which work environment suits you?'),
      options: [
        OrientationOption(
            id: 'office',
            label: LocalizedText(
                fr: 'Bureau, open space ou télétravail',
                en: 'Office, open space or remote'),
            weights: {'d01': 3, 'd02': 3, 'd03': 4}),
        OrientationOption(
            id: 'field',
            label: LocalizedText(
                fr: 'Sur le terrain, en déplacement',
                en: 'In the field, on the move'),
            weights: {'d05': 3, 'd08': 4, 'd10': 3}),
        OrientationOption(
            id: 'hospital',
            label: LocalizedText(
                fr: 'Hôpital, laboratoire ou clinique',
                en: 'Hospital, laboratory or clinic'),
            weights: {'d04': 5}),
        OrientationOption(
            id: 'studio',
            label: LocalizedText(
                fr: 'Studio, atelier ou espace créatif',
                en: 'Studio, workshop or creative space'),
            weights: {'d06': 4, 'd11': 3}),
        OrientationOption(
            id: 'intl',
            label: LocalizedText(
                fr: 'International avec voyages fréquents',
                en: 'International with frequent travel'),
            weights: {'d02': 2, 'd07': 3, 'd12': 4}),
      ],
    ),
    OrientationQuestion(
      id: 'level',
      prompt: LocalizedText(
          fr: 'Quel niveau de diplôme visez-vous ?',
          en: 'Which degree level are you targeting?'),
      options: [
        OrientationOption(
            id: 'bac3',
            label: LocalizedText(
                fr: 'Bac+3 — Licence ou Bachelor',
                en: 'Bachelor degree (3 years)'),
            weights: {'d02': 2, 'd06': 2, 'd12': 2, 'd03': 1}),
        OrientationOption(
            id: 'bac5',
            label: LocalizedText(
                fr: 'Bac+5 — Master ou Grande École',
                en: 'Master / Grande École (5 years)'),
            weights: {'d01': 2, 'd02': 2, 'd03': 2, 'd07': 2}),
        OrientationOption(
            id: 'bac8',
            label: LocalizedText(
                fr: 'Bac+8 — Doctorat ou PhD', en: 'PhD / Doctorate (8 years)'),
            weights: {'d04': 3, 'd05': 2, 'd09': 3}),
      ],
    ),
  ];

  static const fields = <FieldModel>[
    FieldModel(
      id: 'd01',
      name: LocalizedText(
          fr: 'Informatique & Intelligence Artificielle',
          en: 'Computer Science & AI'),
      description: LocalizedText(
          fr: 'Apprends à coder, créer des intelligences artificielles et sécuriser les systèmes numériques.',
          en: 'Learn to code, build AI, and protect computer systems.'),
      subjects: [
        LocalizedText(fr: 'Mathématiques', en: 'Mathematics'),
        LocalizedText(fr: 'Physique', en: 'Physics'),
        LocalizedText(fr: 'Informatique', en: 'Computer Science'),
        LocalizedText(fr: 'Anglais', en: 'English'),
        LocalizedText(fr: 'Cryptographie', en: 'Cryptography'),
        LocalizedText(fr: 'Réseaux informatiques', en: 'Computer Networks'),
      ],
      careers: [
        LocalizedText(fr: 'Entreprises privées', en: 'Private companies'),
        LocalizedText(
            fr: 'Administrations publiques', en: 'Public administrations'),
        LocalizedText(
            fr: 'Organismes de sécurité et de défense.',
            en: 'Security and defence organisations'),
        LocalizedText(fr: 'Consultant en informatique', en: 'IT consultant'),
        LocalizedText(fr: 'Ingénieur d\'affaires', en: 'Business engineer'),
        LocalizedText(
            fr: 'Ingénieur en informatique industrielle',
            en: 'Industrial IT engineer'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Apprends à coder, créer des intelligences artificielles et sécuriser les systèmes numériques',
            en: 'Learn to code, build AI, and protect computer systems.'),
      ],
      skills: [
        LocalizedText(fr: 'Analyse & logique', en: 'Analytical thinking'),
        LocalizedText(fr: 'Communication', en: 'Communication'),
        LocalizedText(fr: 'Rigueur', en: 'Rigor'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'analytique', en: 'analytical'),
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'leadership', en: 'leadership'),
        LocalizedText(fr: 'créatif', en: 'creative'),
      ],
      relatedCountryIds: ['france', 'germany', 'spain', 'usa', 'morocco'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFF233F84),
    ),
    FieldModel(
      id: 'd02',
      name: LocalizedText(
          fr: 'Gestion, Business & Management', en: 'Business & Management'),
      description: LocalizedText(
          fr: 'Pilote des projets, dirige des équipes et développe des entreprises à l\'international.',
          en: 'Run projects, lead teams, and grow businesses internationally.'),
      subjects: [
        LocalizedText(fr: 'Mathématiques', en: 'Mathematics'),
        LocalizedText(fr: 'Physique-chimie', en: 'Physics and Chemistry'),
        LocalizedText(
            fr: 'Sciences de la vie et de la terre',
            en: 'Life and Earth Sciences'),
        LocalizedText(fr: 'Français', en: 'French'),
        LocalizedText(fr: 'Sciences du sol', en: 'Soil Science'),
        LocalizedText(fr: 'Hydrologie', en: 'Hydrology'),
      ],
      careers: [
        LocalizedText(fr: 'Agriculture', en: 'Agriculture'),
        LocalizedText(fr: 'Ingénierie', en: 'Engineering'),
        LocalizedText(
            fr: 'Recherche et développement', en: 'Research and development'),
        LocalizedText(fr: 'Enseignement', en: 'Teaching'),
        LocalizedText(fr: 'Conseil', en: 'Consulting'),
        LocalizedText(
            fr: 'Établissements scolaires publics et privés',
            en: 'Public and private schools'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Pilote des projets, dirige des équipes et développe des entreprises à l\'international',
            en: 'Run projects, lead teams, and grow businesses internationally.'),
      ],
      skills: [
        LocalizedText(fr: 'Communication', en: 'Communication'),
        LocalizedText(fr: 'Rigueur', en: 'Rigor'),
        LocalizedText(fr: 'Analyse & logique', en: 'Analytical thinking'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'analytique', en: 'analytical'),
        LocalizedText(fr: 'leadership', en: 'leadership'),
      ],
      relatedCountryIds: ['france', 'germany', 'spain', 'usa', 'morocco'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFF0EA5E9),
    ),
    FieldModel(
      id: 'd03',
      name: LocalizedText(
          fr: 'Finance, Banque & Comptabilité',
          en: 'Finance, Banking & Accounting'),
      description: LocalizedText(
          fr: 'Gère les flux financiers, analyse les marchés et conseille les entreprises sur leurs investissements.',
          en: 'Manage company finances, analyse markets, and advise on investments.'),
      subjects: [
        LocalizedText(fr: 'Français', en: 'French'),
        LocalizedText(fr: 'Anglais', en: 'English'),
        LocalizedText(fr: 'Mathématiques', en: 'Mathematics'),
        LocalizedText(fr: 'Histoire.', en: 'History'),
        LocalizedText(fr: 'Microéconomie', en: 'Microeconomics'),
        LocalizedText(fr: 'Macroéconomie', en: 'Macroeconomics'),
      ],
      careers: [
        LocalizedText(fr: 'Instituts de recherche', en: 'Research institutes'),
        LocalizedText(
            fr: 'Administrations publiques', en: 'Public administrations'),
        LocalizedText(
            fr: 'Organisations internationales',
            en: 'International organisations'),
        LocalizedText(fr: 'Banques', en: 'Banks'),
        LocalizedText(fr: 'Entreprises', en: 'Companies'),
        LocalizedText(fr: 'Cabinets de conseil', en: 'Consulting firms'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Gère les flux financiers, analyse les marchés et conseille les entreprises sur leurs investissements',
            en: 'Manage company finances, analyse markets, and advise on investments.'),
      ],
      skills: [
        LocalizedText(fr: 'Communication', en: 'Communication'),
        LocalizedText(fr: 'Analyse & logique', en: 'Analytical thinking'),
        LocalizedText(fr: 'Rigueur', en: 'Rigor'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'analytique', en: 'analytical'),
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'créatif', en: 'creative'),
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
      ],
      relatedCountryIds: ['spain', 'france', 'germany', 'usa', 'morocco'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFF059669),
    ),
    FieldModel(
      id: 'd04',
      name: LocalizedText(
          fr: 'Santé & Sciences Médicales', en: 'Health & Medical Sciences'),
      description: LocalizedText(
          fr: 'Soigne, prévient les maladies et améliore la santé des populations.',
          en: 'Treat patients, prevent illness, and improve public health.'),
      subjects: [
        LocalizedText(fr: 'Français', en: 'French'),
        LocalizedText(fr: 'Anglais', en: 'English'),
        LocalizedText(fr: 'Mathématiques', en: 'Mathematics'),
        LocalizedText(
            fr: 'Sciences de la vie et de la terre',
            en: 'Life and Earth Sciences'),
        LocalizedText(fr: 'Anatomie', en: 'Anatomy'),
        LocalizedText(fr: 'Physiologie', en: 'Physiology'),
      ],
      careers: [
        LocalizedText(fr: 'Hôpitaux', en: 'Hospitals'),
        LocalizedText(fr: 'Cliniques', en: 'Clinics'),
        LocalizedText(fr: 'Cabinets médicaux', en: 'Medical practices'),
        LocalizedText(fr: 'Cabinets dentaires', en: 'Dental practices'),
        LocalizedText(fr: 'Recherche médicale', en: 'Medical research'),
        LocalizedText(fr: 'Cliniques vétérinaires', en: 'Veterinary clinics'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Soigne, prévient les maladies et améliore la santé des populations',
            en: 'Treat patients, prevent illness, and improve public health.'),
      ],
      skills: [
        LocalizedText(fr: 'Analyse & logique', en: 'Analytical thinking'),
        LocalizedText(fr: 'Communication', en: 'Communication'),
        LocalizedText(fr: 'Rigueur', en: 'Rigor'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'analytique', en: 'analytical'),
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
      ],
      relatedCountryIds: ['turkey', 'uae'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFFDB516A),
    ),
    FieldModel(
      id: 'd05',
      name: LocalizedText(
          fr: 'Ingénierie & Sciences Appliquées',
          en: 'Engineering & Applied Sciences'),
      description: LocalizedText(
          fr: 'Conçois et construis les infrastructures, machines et technologies qui façonnent le monde.',
          en: 'Design and build the roads, machines, and technologies we use every day.'),
      subjects: [
        LocalizedText(fr: 'Français', en: 'French'),
        LocalizedText(fr: 'Anglais', en: 'English'),
        LocalizedText(fr: 'Mathématiques', en: 'Mathematics'),
        LocalizedText(fr: 'Physique', en: 'Physics'),
        LocalizedText(
            fr: 'Mécanique des structures', en: 'Structural Mechanics'),
        LocalizedText(fr: 'Résistance des matériaux', en: 'Materials Science'),
      ],
      careers: [
        LocalizedText(
            fr: 'Btp (bâtiment et travaux publics)',
            en: 'Civil engineering and construction'),
        LocalizedText(fr: 'Cabinets d\'architectes', en: 'Architecture firms'),
        LocalizedText(fr: 'Bureaux d\'études', en: 'Design offices'),
        LocalizedText(
            fr: 'Administrations publiques', en: 'Public administrations'),
        LocalizedText(
            fr: 'Industries électriques', en: 'Electrical industries'),
        LocalizedText(fr: 'Recherche', en: 'Research'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Conçois et construis les infrastructures, machines et technologies qui façonnent le monde',
            en: 'Design and build the roads, machines, and technologies we use every day.'),
      ],
      skills: [
        LocalizedText(fr: 'Analyse & logique', en: 'Analytical thinking'),
        LocalizedText(fr: 'Rigueur', en: 'Rigor'),
        LocalizedText(fr: 'Créativité', en: 'Creativity'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'analytique', en: 'analytical'),
        LocalizedText(fr: 'créatif', en: 'creative'),
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
      ],
      relatedCountryIds: ['france'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFF0F766E),
    ),
    FieldModel(
      id: 'd06',
      name: LocalizedText(
          fr: 'Marketing, Communication & Arts',
          en: 'Marketing, Communication & Arts'),
      description: LocalizedText(
          fr: 'Crée des messages percutants, développe des marques et exprime ta créativité.',
          en: 'Create strong messages, grow brands, and express your creativity.'),
      subjects: [
        LocalizedText(
            fr: 'Culture générale : ouverture à d\'autres disciplines (littérature',
            en: 'General culture: exposure to other disciplines (literature'),
        LocalizedText(fr: 'philosophie', en: 'philosophy'),
        LocalizedText(fr: 'histoire…).', en: 'history…).'),
        LocalizedText(
            fr: 'Pratique artistique : dessin',
            en: 'Artistic practice: drawing'),
        LocalizedText(fr: 'peinture', en: 'painting'),
        LocalizedText(fr: 'sculpture', en: 'sculpture'),
      ],
      careers: [
        LocalizedText(
            fr: 'Création artistique : artiste peintre',
            en: 'Artistic creation: painter'),
        LocalizedText(fr: 'Sculpteur', en: 'Sculptor'),
        LocalizedText(
            fr: 'Infographiste… enseignement : professeur d\'arts plastiques',
            en: 'Graphic designer… teaching: visual arts teacher'),
        LocalizedText(
            fr: 'Interprétation musicale : orchestre',
            en: 'Musical performance: orchestra'),
        LocalizedText(
            fr: 'Soliste enseignement musical : conservatoire',
            en: 'Soloist, music teaching: conservatory'),
        LocalizedText(fr: 'Compagnies de danse', en: 'Dance companies'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Crée des messages percutants, développe des marques et exprime ta créativité',
            en: 'Create strong messages, grow brands, and express your creativity.'),
      ],
      skills: [
        LocalizedText(fr: 'Communication', en: 'Communication'),
        LocalizedText(fr: 'Rigueur', en: 'Rigor'),
        LocalizedText(fr: 'Créativité', en: 'Creativity'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'créatif', en: 'creative'),
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
        LocalizedText(fr: 'analytique', en: 'analytical'),
      ],
      relatedCountryIds: ['spain', 'france', 'germany', 'usa', 'morocco'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFFEC4899),
    ),
    FieldModel(
      id: 'd07',
      name: LocalizedText(
          fr: 'Droit & Sciences Politiques', en: 'Law & Political Science'),
      description: LocalizedText(
          fr: 'Défend les droits, négocie des traités et influence les politiques qui gouvernent les nations.',
          en: 'Defend people\'s rights and help shape the laws and agreements between countries.'),
      subjects: [
        LocalizedText(fr: 'Français', en: 'French'),
        LocalizedText(fr: 'Anglais', en: 'English'),
        LocalizedText(fr: 'Histoire', en: 'History'),
        LocalizedText(fr: 'Philosophie.', en: 'Philosophy'),
        LocalizedText(fr: 'Droit constitutionnel', en: 'Constitutional Law'),
        LocalizedText(fr: 'Droit administratif', en: 'Administrative Law'),
      ],
      careers: [
        LocalizedText(
            fr: 'Administrations publiques', en: 'Public administrations'),
        LocalizedText(
            fr: 'Collectivités territoriales', en: 'Local authorities'),
        LocalizedText(fr: 'Cabinets d\'avocats', en: 'Law firms'),
        LocalizedText(
            fr: 'Organisations internationales',
            en: 'International organisations'),
        LocalizedText(fr: 'Enseignement', en: 'Teaching'),
        LocalizedText(fr: 'Entreprises', en: 'Companies'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Défend les droits, négocie des traités et influence les politiques qui gouvernent les nations',
            en: 'Defend people\'s rights and help shape the laws and agreements between countries.'),
      ],
      skills: [
        LocalizedText(fr: 'Communication', en: 'Communication'),
        LocalizedText(fr: 'Analyse & logique', en: 'Analytical thinking'),
        LocalizedText(fr: 'Rigueur', en: 'Rigor'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'analytique', en: 'analytical'),
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
        LocalizedText(fr: 'créatif', en: 'creative'),
      ],
      relatedCountryIds: ['spain', 'france', 'germany', 'usa'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFF7C3AED),
    ),
    FieldModel(
      id: 'd08',
      name: LocalizedText(
          fr: 'Énergie, Environnement & Développement durable',
          en: 'Energy, Environment & Sustainability'),
      description: LocalizedText(
          fr: 'Préserve les ressources naturelles et développe les énergies du futur pour un monde durable.',
          en: 'Protect natural resources and develop clean energy for a sustainable world.'),
      subjects: [
        LocalizedText(fr: 'Géologie', en: 'Geology'),
        LocalizedText(fr: 'géophysique', en: 'Geophysics'),
        LocalizedText(fr: 'chimie', en: 'Chemistry'),
        LocalizedText(fr: 'physique', en: 'Physics'),
        LocalizedText(fr: 'Ingénierie pétrolière', en: 'Petroleum Engineering'),
        LocalizedText(fr: 'géologie appliquée', en: 'Applied Geology'),
      ],
      careers: [
        LocalizedText(
            fr: 'Entreprises d\'exploration et de production pétrolière',
            en: 'Oil exploration and production companies'),
        LocalizedText(
            fr: 'Entreprises spécialisées dans l\'installation et la maintenance de systèmes solaires et éoliens',
            en: 'Companies specialising in solar and wind system installation and maintenance'),
        LocalizedText(
            fr: 'Sociétés de gestion de l\'énergie',
            en: 'Energy management companies'),
        LocalizedText(
            fr: 'Organismes de recherche et développement',
            en: 'Research and development organisations'),
        LocalizedText(
            fr: 'Organisations internationales axées sur la durabilité',
            en: 'International organisations focused on sustainability'),
        LocalizedText(
            fr: 'Entreprises spécialisées dans les énergies renouvelables',
            en: 'Renewable energy companies'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Préserve les ressources naturelles et développe les énergies du futur pour un monde durable',
            en: 'Protect natural resources and develop clean energy for a sustainable world.'),
      ],
      skills: [
        LocalizedText(fr: 'Communication', en: 'Communication'),
        LocalizedText(fr: 'Analyse & logique', en: 'Analytical thinking'),
        LocalizedText(fr: 'Leadership', en: 'Leadership'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'analytique', en: 'analytical'),
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
        LocalizedText(fr: 'terrain', en: 'field-oriented'),
      ],
      relatedCountryIds: ['spain', 'france', 'germany', 'usa', 'morocco'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFF16A34A),
    ),
    FieldModel(
      id: 'd09',
      name: LocalizedText(
          fr: 'Éducation, Sciences Humaines & Langues',
          en: 'Education, Humanities & Languages'),
      description: LocalizedText(
          fr: 'Comprends les sociétés humaines, transmet le savoir et accompagne le développement des individus.',
          en: 'Understand societies, share knowledge, and support people\'s development.'),
      subjects: [
        LocalizedText(fr: 'Ancien Testament', en: 'Old Testament'),
        LocalizedText(fr: 'Nouveau Testament', en: 'New Testament'),
        LocalizedText(fr: 'Histoire de l\'Église', en: 'Church History'),
        LocalizedText(
            fr: 'Philosophie de la religion.', en: 'Philosophy of Religion'),
        LocalizedText(fr: 'Théologie biblique', en: 'Biblical Theology'),
        LocalizedText(fr: 'Théologie systématique', en: 'Systematic Theology'),
      ],
      careers: [
        LocalizedText(fr: 'Ministère pastoral', en: 'Pastoral ministry'),
        LocalizedText(fr: 'Enseignement', en: 'Teaching'),
        LocalizedText(fr: 'Conseil', en: 'Consulting'),
        LocalizedText(fr: 'Journalisme.', en: 'Journalism'),
        LocalizedText(fr: 'Recherche', en: 'Research'),
        LocalizedText(fr: 'Journalisme', en: 'Journalism'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Comprends les sociétés humaines, transmet le savoir et accompagne le développement des individus',
            en: 'Understand societies, share knowledge, and support people\'s development.'),
      ],
      skills: [
        LocalizedText(fr: 'Communication', en: 'Communication'),
        LocalizedText(fr: 'Analyse & logique', en: 'Analytical thinking'),
        LocalizedText(fr: 'Leadership', en: 'Leadership'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'analytique', en: 'analytical'),
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
        LocalizedText(fr: 'créatif', en: 'creative'),
      ],
      relatedCountryIds: ['france'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFF2D5FBA),
    ),
    FieldModel(
      id: 'd10',
      name: LocalizedText(
          fr: 'Agriculture & Agroalimentaire', en: 'Agriculture & Agri-food'),
      description: LocalizedText(
          fr: 'Nourrit les populations en optimisant la production agricole et les filières alimentaires.',
          en: 'Feed communities by improving agricultural production and food supply chains.'),
      subjects: [
        LocalizedText(fr: 'Français', en: 'French'),
        LocalizedText(fr: 'Mathématiques', en: 'Mathematics'),
        LocalizedText(fr: 'Histoire-géographie', en: 'History and Geography'),
        LocalizedText(
            fr: 'Sciences physiques et chimiques',
            en: 'Physical and Chemical Sciences'),
        LocalizedText(fr: 'Technologie boulangère', en: 'Bakery Technology'),
        LocalizedText(fr: 'Hygiène alimentaire', en: 'Food Hygiene'),
      ],
      careers: [
        LocalizedText(fr: 'Boulangeries artisanales', en: 'Artisan bakeries'),
        LocalizedText(
            fr: 'Boulangeries industrielles', en: 'Industrial bakeries'),
        LocalizedText(fr: 'Restaurants', en: 'Restaurants'),
        LocalizedText(
            fr: 'Boulangeries-pâtisseries', en: 'Bakeries and pastry shops'),
        LocalizedText(
            fr: 'Artisanat chocolatier', en: 'Artisan chocolate making'),
        LocalizedText(
            fr: 'Grandes maisons de chocolat', en: 'Premium chocolate houses'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Nourrit les populations en optimisant la production agricole et les filières alimentaires',
            en: 'Feed communities by improving agricultural production and food supply chains.'),
      ],
      skills: [
        LocalizedText(fr: 'Analyse & logique', en: 'Analytical thinking'),
        LocalizedText(fr: 'Rigueur', en: 'Rigor'),
        LocalizedText(fr: 'Créativité', en: 'Creativity'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'terrain', en: 'field-oriented'),
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
        LocalizedText(fr: 'analytique', en: 'analytical'),
      ],
      relatedCountryIds: ['france', 'germany', 'morocco'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFF84CC16),
    ),
    FieldModel(
      id: 'd11',
      name: LocalizedText(
          fr: 'Architecture, BTP & Urbanisme',
          en: 'Architecture, Construction & Urban Planning'),
      description: LocalizedText(
          fr: 'Conçois et bâtis les villes, bâtiments et infrastructures de demain.',
          en: 'Design and build tomorrow\'s cities, buildings, and infrastructure.'),
      subjects: [
        LocalizedText(fr: 'Mathématiques', en: 'Mathematics'),
        LocalizedText(fr: 'Français', en: 'French'),
        LocalizedText(fr: 'Sciences physiques', en: 'Physical Sciences'),
        LocalizedText(fr: 'Histoire-géographie', en: 'History and Geography'),
        LocalizedText(
            fr: 'Technologie de la construction',
            en: 'Construction Technology'),
        LocalizedText(fr: 'Dessin technique', en: 'Technical Drawing'),
      ],
      careers: [
        LocalizedText(
            fr: 'Bâtiment (construction de maisons',
            en: 'Building (house construction'),
        LocalizedText(fr: 'Immeubles)', en: 'Apartment buildings)'),
        LocalizedText(fr: 'Bâtiment', en: 'Building'),
        LocalizedText(fr: 'Agencement', en: 'Interior fitting'),
        LocalizedText(
            fr: 'Bâtiment (construction neuve',
            en: 'Building (new construction'),
        LocalizedText(fr: 'Rénovation)', en: 'Renovation)'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Conçois et bâtis les villes, bâtiments et infrastructures de demain',
            en: 'Design and build tomorrow\'s cities, buildings, and infrastructure.'),
      ],
      skills: [
        LocalizedText(fr: 'Communication', en: 'Communication'),
        LocalizedText(fr: 'Rigueur', en: 'Rigor'),
        LocalizedText(fr: 'Créativité', en: 'Creativity'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'terrain', en: 'field-oriented'),
        LocalizedText(fr: 'relationnel', en: 'relationship-oriented'),
        LocalizedText(fr: 'rigueur', en: 'detail-oriented'),
      ],
      relatedCountryIds: ['turkey', 'uae', 'france'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFF1E3A6E),
    ),
    FieldModel(
      id: 'd12',
      name: LocalizedText(
          fr: 'Hôtellerie, Tourisme & Luxe',
          en: 'Hospitality, Tourism & Luxury'),
      description: LocalizedText(
          fr: 'Crée des expériences inoubliables dans l\'hôtellerie, le tourisme et les industries du luxe.',
          en: 'Create memorable experiences in hospitality, tourism, and luxury industries.'),
      subjects: [
        LocalizedText(fr: 'Matières spécialisées', en: 'Specialised subjects'),
      ],
      careers: [
        LocalizedText(
            fr: 'Emploi dans le secteur', en: 'Employment in the sector'),
      ],
      dailyLife: [
        LocalizedText(
            fr: 'Crée des expériences inoubliables dans l\'hôtellerie, le tourisme et les industries du luxe',
            en: 'Create memorable experiences in hospitality, tourism, and luxury industries.'),
      ],
      skills: [
        LocalizedText(fr: 'Compétences techniques', en: 'Technical skills'),
      ],
      personalityTraits: [
        LocalizedText(fr: 'Curieux', en: 'Curious'),
      ],
      relatedCountryIds: ['spain', 'france', 'germany', 'usa'],
      relatedScholarshipIds: ['brs_001', 'brs_002', 'brs_003', 'brs_004'],
      accentColor: Color(0xFFF59E0B),
    ),
  ];

  static const countries = <CountryModel>[
    CountryModel(
      id: 'usa',
      name: LocalizedText(fr: 'États-Unis', en: 'United States'),
      whyStudy: LocalizedText(
          fr: 'Réseau universitaire mondial, diversité de programmes, carrières tech et recherche.',
          en: 'World-class universities, diverse programs, tech and research careers.'),
      tuitionRange: LocalizedText(fr: 'USD 15k–45k/an', en: 'USD 15k–45k/year'),
      livingCostRange:
          LocalizedText(fr: 'USD 900–2 000/mois', en: 'USD 900–2 000/month'),
      visaOverview: LocalizedText(
          fr: 'Visa F-1 avec preuve financière et I-20 de l\'université.',
          en: 'F-1 visa with financial proof and I-20 from university.'),
      admissionDifficulty: LocalizedText(fr: 'Élevée', en: 'High'),
      popularFieldIds: ['d01', 'd05', 'd02'],
    ),
    CountryModel(
      id: 'canada',
      name: LocalizedText(fr: 'Canada', en: 'Canada'),
      whyStudy: LocalizedText(
          fr: 'Excellente qualité de vie, parcours francophones et anglophones, immigration facilitée après études.',
          en: 'Excellent quality of life, French and English programs, facilitated post-study immigration.'),
      tuitionRange: LocalizedText(fr: 'CAD 10k–30k/an', en: 'CAD 10k–30k/year'),
      livingCostRange:
          LocalizedText(fr: 'CAD 800–1 500/mois', en: 'CAD 800–1 500/month'),
      visaOverview: LocalizedText(
          fr: 'Permis d\'études avec lettre d\'admission et preuve financière.',
          en: 'Study permit with admission letter and financial proof.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d01', 'd02', 'd09'],
    ),
    CountryModel(
      id: 'france',
      name: LocalizedText(fr: 'France', en: 'France'),
      whyStudy: LocalizedText(
          fr: 'Grande qualité académique, coûts réduits dans les universités publiques, visa simplifié via Campus France.',
          en: 'High academic quality, low costs in public universities, simplified visa via Campus France.'),
      tuitionRange:
          LocalizedText(fr: 'EUR 170–10 000/an', en: 'EUR 170–10 000/year'),
      livingCostRange:
          LocalizedText(fr: 'EUR 700–1 200/mois', en: 'EUR 700–1 200/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant via Campus France — procédure en ligne pays par pays.',
          en: 'Student visa via Campus France — online process by country.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d02', 'd03', 'd07', 'd06'],
    ),
    CountryModel(
      id: 'uk',
      name: LocalizedText(fr: 'Royaume-Uni', en: 'United Kingdom'),
      whyStudy: LocalizedText(
          fr: 'Universités classées mondialement, programmes courts et intensifs, carrières finance et tech.',
          en: 'World-ranked universities, short intensive programs, finance and tech careers.'),
      tuitionRange: LocalizedText(fr: 'GBP 12k–28k/an', en: 'GBP 12k–28k/year'),
      livingCostRange:
          LocalizedText(fr: 'GBP 900–1 800/mois', en: 'GBP 900–1 800/month'),
      visaOverview: LocalizedText(
          fr: 'Visa Student Tier 4 avec CAS de l\'université.',
          en: 'Student Tier 4 visa with university CAS.'),
      admissionDifficulty: LocalizedText(fr: 'Élevée', en: 'High'),
      popularFieldIds: ['d01', 'd03', 'd07'],
    ),
    CountryModel(
      id: 'germany',
      name: LocalizedText(fr: 'Allemagne', en: 'Germany'),
      whyStudy: LocalizedText(
          fr: 'Universités publiques quasi-gratuites, excellence technique, forte demande en ingénieurs.',
          en: 'Nearly free public universities, technical excellence, high demand for engineers.'),
      tuitionRange: LocalizedText(
          fr: 'EUR 0–3 000/an (frais de semestre)',
          en: 'EUR 0–3 000/year (semester fees)'),
      livingCostRange:
          LocalizedText(fr: 'EUR 700–1 100/mois', en: 'EUR 700–1 100/month'),
      visaOverview: LocalizedText(
          fr: 'Visa national D avec lettre d\'admission et preuves financières.',
          en: 'National D visa with admission letter and financial proof.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d05', 'd01', 'd08'],
    ),
    CountryModel(
      id: 'morocco',
      name: LocalizedText(fr: 'Maroc', en: 'Morocco'),
      whyStudy: LocalizedText(
          fr: 'Proximité géographique, coûts abordables, nombreux partenariats avec écoles françaises.',
          en: 'Geographic proximity, affordable costs, many partnerships with French schools.'),
      tuitionRange: LocalizedText(fr: 'MAD 15k–60k/an', en: 'MAD 15k–60k/year'),
      livingCostRange: LocalizedText(
          fr: 'MAD 3 000–6 000/mois', en: 'MAD 3 000–6 000/month'),
      visaOverview: LocalizedText(
          fr: 'Pas de visa requis pour ressortissants CEDEAO. Titre de séjour ensuite.',
          en: 'No visa required for ECOWAS nationals. Residence permit afterward.'),
      admissionDifficulty:
          LocalizedText(fr: 'Facile à modérée', en: 'Easy to moderate'),
      popularFieldIds: ['d02', 'd04', 'd07'],
    ),
    CountryModel(
      id: 'turkey',
      name: LocalizedText(fr: 'Turquie', en: 'Turkey'),
      whyStudy: LocalizedText(
          fr: 'Coûts très abordables, bourse gouvernementale complète (Türkiye Burslari), médecine en anglais.',
          en: 'Very affordable costs, full government scholarship (Türkiye Burslari), medicine in English.'),
      tuitionRange:
          LocalizedText(fr: 'USD 500–6 000/an', en: 'USD 500–6 000/year'),
      livingCostRange:
          LocalizedText(fr: 'USD 400–800/mois', en: 'USD 400–800/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant avec lettre d\'admission et acte de naissance.',
          en: 'Student visa with admission letter and birth certificate.'),
      admissionDifficulty: LocalizedText(fr: 'Facile', en: 'Easy'),
      popularFieldIds: ['d04', 'd02', 'd05'],
    ),
    CountryModel(
      id: 'spain',
      name: LocalizedText(fr: 'Espagne', en: 'Spain'),
      whyStudy: LocalizedText(
          fr: 'Qualité de vie élevée, coûts inférieurs à la France, programmes en anglais en augmentation.',
          en: 'High quality of life, lower costs than France, growing English-language programs.'),
      tuitionRange:
          LocalizedText(fr: 'EUR 1 000–8 000/an', en: 'EUR 1 000–8 000/year'),
      livingCostRange:
          LocalizedText(fr: 'EUR 700–1 100/mois', en: 'EUR 700–1 100/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant Schengen avec inscription et ressources suffisantes.',
          en: 'Schengen student visa with enrollment and sufficient funds.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d06', 'd02', 'd11'],
    ),
    CountryModel(
      id: 'china',
      name: LocalizedText(fr: 'Chine', en: 'China'),
      whyStudy: LocalizedText(
          fr: 'Bourses gouvernementales généreuses (HSK), hub technologique mondial, expansion économique.',
          en: 'Generous government scholarships (HSK), global tech hub, economic expansion.'),
      tuitionRange: LocalizedText(fr: 'CNY 25k–60k/an', en: 'CNY 25k–60k/year'),
      livingCostRange: LocalizedText(
          fr: 'CNY 3 000–6 000/mois', en: 'CNY 3 000–6 000/month'),
      visaOverview: LocalizedText(
          fr: 'Visa X1 avec JW202 et lettre d\'admission.',
          en: 'X1 visa with JW202 and admission letter.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d01', 'd05', 'd10'],
    ),
    CountryModel(
      id: 'uae',
      name:
          LocalizedText(fr: 'Émirats Arabes Unis', en: 'United Arab Emirates'),
      whyStudy: LocalizedText(
          fr: 'Hub international des affaires, programmes 100% anglais, connexions Afrique–Asie–Europe.',
          en: 'International business hub, 100% English programs, Africa–Asia–Europe connections.'),
      tuitionRange: LocalizedText(fr: 'AED 30k–80k/an', en: 'AED 30k–80k/year'),
      livingCostRange: LocalizedText(
          fr: 'AED 3 000–7 000/mois', en: 'AED 3 000–7 000/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant sponsorisé par l\'université.',
          en: 'Student visa sponsored by the university.'),
      admissionDifficulty: LocalizedText(fr: 'Facile', en: 'Easy'),
      popularFieldIds: ['d02', 'd03', 'd12'],
    ),
    CountryModel(
      id: 'belgium',
      name: LocalizedText(fr: 'Belgique', en: 'Belgium'),
      whyStudy: LocalizedText(
          fr: 'Porte d\'entrée de l\'Europe, coûts inférieurs à la France, programmes en français pour les étudiants d\'Afrique francophone.',
          en: 'Gateway to Europe, lower costs than France, French programs for francophone Africa.'),
      tuitionRange:
          LocalizedText(fr: 'EUR 835–4 000/an', en: 'EUR 835–4 000/year'),
      livingCostRange:
          LocalizedText(fr: 'EUR 700–1 100/mois', en: 'EUR 700–1 100/month'),
      visaOverview: LocalizedText(
          fr: 'Visa D étudiant avec lettre d\'admission et preuve financière (environ 650€/mois).',
          en: 'D student visa with admission letter and financial proof (~€650/month).'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d02', 'd04', 'd07', 'd01'],
    ),
    CountryModel(
      id: 'portugal',
      name: LocalizedText(fr: 'Portugal', en: 'Portugal'),
      whyStudy: LocalizedText(
          fr: 'Visa simplifié pour lusophones, coûts de vie bas, hub startup européen, passerelle vers le Brésil.',
          en: 'Simplified visa for Lusophone students, low living costs, European startup hub.'),
      tuitionRange:
          LocalizedText(fr: 'EUR 950–3 500/an', en: 'EUR 950–3 500/year'),
      livingCostRange:
          LocalizedText(fr: 'EUR 600–1 000/mois', en: 'EUR 600–1 000/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant portugais avec inscription et hébergement prouvé.',
          en: 'Portuguese student visa with proven enrollment and accommodation.'),
      admissionDifficulty:
          LocalizedText(fr: 'Facile à modérée', en: 'Easy to moderate'),
      popularFieldIds: ['d02', 'd06', 'd05'],
    ),
    CountryModel(
      id: 'switzerland',
      name: LocalizedText(fr: 'Suisse', en: 'Switzerland'),
      whyStudy: LocalizedText(
          fr: 'Excellence mondiale (EPFL, ETHZ), salaires post-diplôme parmi les plus élevés d\'Europe, trilinguisme.',
          en: 'World excellence (EPFL, ETHZ), top post-grad salaries in Europe, trilingualism.'),
      tuitionRange: LocalizedText(
          fr: 'CHF 500–2 500/semestre', en: 'CHF 500–2 500/semester'),
      livingCostRange: LocalizedText(
          fr: 'CHF 2 000–3 000/mois', en: 'CHF 2 000–3 000/month'),
      visaOverview: LocalizedText(
          fr: 'Permis étudiant C avec lettre d\'admission et preuve de 21 000 CHF en banque.',
          en: 'Student permit C with admission letter and proof of CHF 21,000 in bank.'),
      admissionDifficulty: LocalizedText(fr: 'Très élevée', en: 'Very high'),
      popularFieldIds: ['d01', 'd05', 'd03'],
    ),
    CountryModel(
      id: 'italy',
      name: LocalizedText(fr: 'Italie', en: 'Italy'),
      whyStudy: LocalizedText(
          fr: 'Bocconi et Politecnico reconnus mondialement, coûts inférieurs à la France, cadre de vie exceptionnel.',
          en: 'Bocconi and Politecnico world-recognized, lower costs than France, exceptional lifestyle.'),
      tuitionRange: LocalizedText(
          fr: 'EUR 900–15 000/an (selon revenu)',
          en: 'EUR 900–15 000/year (income-based)'),
      livingCostRange:
          LocalizedText(fr: 'EUR 700–1 200/mois', en: 'EUR 700–1 200/month'),
      visaOverview: LocalizedText(
          fr: 'Visa Type D étudiant avec pré-inscription et preuve de 448€/mois.',
          en: 'Type D student visa with pre-enrollment and proof of €448/month.'),
      admissionDifficulty: LocalizedText(fr: 'Modérée', en: 'Moderate'),
      popularFieldIds: ['d02', 'd06', 'd05', 'd04'],
    ),
    CountryModel(
      id: 'russia',
      name: LocalizedText(fr: 'Russie', en: 'Russia'),
      whyStudy: LocalizedText(
          fr: 'Bourses gouvernementales complètes, excellence en sciences et médecine, coûts très faibles.',
          en: 'Full government scholarships, excellence in science and medicine, very low costs.'),
      tuitionRange:
          LocalizedText(fr: 'USD 2 000–7 000/an', en: 'USD 2 000–7 000/year'),
      livingCostRange:
          LocalizedText(fr: 'USD 300–600/mois', en: 'USD 300–600/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant avec lettre d\'invitation de l\'université.',
          en: 'Student visa with university invitation letter.'),
      admissionDifficulty: LocalizedText(fr: 'Facile', en: 'Easy'),
      popularFieldIds: ['d04', 'd05', 'd01'],
    ),
    CountryModel(
      id: 'japan',
      name: LocalizedText(fr: 'Japon', en: 'Japan'),
      whyStudy: LocalizedText(
          fr: 'Bourse MEXT complète, excellence technologique, économie innovante, culture unique.',
          en: 'Full MEXT scholarship, technological excellence, innovative economy.'),
      tuitionRange:
          LocalizedText(fr: 'JPY 535k–1 800k/an', en: 'JPY 535k–1 800k/year'),
      livingCostRange: LocalizedText(
          fr: 'JPY 80 000–150 000/mois', en: 'JPY 80 000–150 000/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant avec certificat d\'éligibilité de l\'université acceptante.',
          en: 'Student visa with Certificate of Eligibility from accepting university.'),
      admissionDifficulty: LocalizedText(fr: 'Élevée', en: 'High'),
      popularFieldIds: ['d01', 'd05', 'd10'],
    ),
    CountryModel(
      id: 'saudi_arabia',
      name: LocalizedText(fr: 'Arabie Saoudite', en: 'Saudi Arabia'),
      whyStudy: LocalizedText(
          fr: 'Bourse King Abdullah complète, KAUST parmi les meilleurs mondiaux en recherche, pas de frais de scolarité.',
          en: 'Full King Abdullah scholarship, KAUST world top research, no tuition fees.'),
      tuitionRange: LocalizedText(
          fr: 'Gratuit (avec bourse)', en: 'Free (with scholarship)'),
      livingCostRange: LocalizedText(
          fr: 'SAR 2 000–4 000/mois', en: 'SAR 2 000–4 000/month'),
      visaOverview: LocalizedText(
          fr: 'Visa étudiant sponsorisé par l\'université avec lettre d\'admission officielle.',
          en: 'Student visa sponsored by university with official admission letter.'),
      admissionDifficulty: LocalizedText(fr: 'Élevée', en: 'High'),
      popularFieldIds: ['d05', 'd01', 'd09'],
    ),
  ];

  static const institutions = <InstitutionModel>[
    InstitutionModel(
      id: 'icn',
      name: LocalizedText(fr: 'ICN Business School', en: 'ICN Business School'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(
          fr: 'ICN Business School — France',
          en: 'ICN Business School — France'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat', 'DBA'],
      tuitionLabel: LocalizedText(fr: '9900 EUR/an', en: '9900 EUR/an'),
      languageRequirements:
          LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      intakePeriods: ['Annual intake / exact dates to confirm'],
      programIds: [
        'prog_001',
        'prog_002',
        'prog_003',
        'prog_004',
        'prog_005',
        'prog_006',
        'prog_007',
        'prog_008',
        'prog_009'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'schiller',
      name: LocalizedText(
          fr: 'Schiller International University',
          en: 'Schiller International University'),
      countryId: 'spain',
      location: LocalizedText(
          fr: 'Madrid / Paris / Heidelberg', en: 'Madrid / Paris / Heidelberg'),
      overview: LocalizedText(
          fr: 'Schiller International University — Espagne/France/Allemagne',
          en: 'Schiller International University — Espagne/France/Allemagne'),
      studyLevels: ['Bac+3', 'MBA'],
      tuitionLabel: LocalizedText(fr: '15420 EUR/an', en: '15420 EUR/an'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['See official intake calendar / program page'],
      programIds: [
        'prog_010',
        'prog_011',
        'prog_012',
        'prog_013',
        'prog_014',
        'prog_015',
        'prog_016',
        'prog_017',
        'prog_018',
        'prog_019',
        'prog_020',
        'prog_021',
        'prog_022',
        'prog_023',
        'prog_024',
        'prog_025',
        'prog_026',
        'prog_027',
        'prog_028',
        'prog_029',
        'prog_030',
        'prog_031',
        'prog_032',
        'prog_033',
        'prog_034',
        'prog_035',
        'prog_036',
        'prog_037'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'ismagi',
      name: LocalizedText(fr: 'ISMAGI', en: 'ISMAGI'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Rabat', en: 'Rabat'),
      overview: LocalizedText(fr: 'ISMAGI — Maroc', en: 'ISMAGI — Maroc'),
      studyLevels: ['Bac+3', 'Bac+2', 'Engineering', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      languageRequirements:
          LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      intakePeriods: ['Contact KPB / school for latest intake'],
      programIds: [
        'prog_038',
        'prog_039',
        'prog_040',
        'prog_041',
        'prog_042',
        'prog_043',
        'prog_044',
        'prog_045',
        'prog_046',
        'prog_047',
        'prog_048',
        'prog_049',
        'prog_050',
        'prog_051',
        'prog_052',
        'prog_053',
        'prog_054',
        'prog_055'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'esa_casa',
      name: LocalizedText(
          fr: 'École Supérieure des Affaires (ESA) Casablanca',
          en: 'École Supérieure des Affaires (ESA) Casablanca'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Casablanca', en: 'Casablanca'),
      overview: LocalizedText(
          fr: 'École Supérieure des Affaires (ESA) Casablanca — Maroc',
          en: 'École Supérieure des Affaires (ESA) Casablanca — Maroc'),
      studyLevels: ['Bac+3'],
      tuitionLabel: LocalizedText(fr: '5500 EUR/an', en: '5500 EUR/an'),
      languageRequirements:
          LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      intakePeriods: ['September intake'],
      programIds: ['prog_056', 'prog_057'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'bau',
      name: LocalizedText(
          fr: 'Bahçeşehir University (BAU) Istanbul',
          en: 'Bahçeşehir University (BAU) Istanbul'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
      overview: LocalizedText(
          fr: 'Bahçeşehir University (BAU) Istanbul — Turquie',
          en: 'Bahçeşehir University (BAU) Istanbul — Turquie'),
      studyLevels: ['Bac+3'],
      tuitionLabel: LocalizedText(fr: '8500 USD/an', en: '8500 USD/an'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['Undergraduate: Fall intake only'],
      programIds: [
        'prog_058',
        'prog_059',
        'prog_060',
        'prog_061',
        'prog_062',
        'prog_063',
        'prog_064',
        'prog_065',
        'prog_066'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'gbs_dubai',
      name: LocalizedText(fr: 'GBS Dubai', en: 'GBS Dubai'),
      countryId: 'uae',
      location: LocalizedText(fr: 'Dubai', en: 'Dubai'),
      overview: LocalizedText(fr: 'GBS Dubai — UAE', en: 'GBS Dubai — UAE'),
      studyLevels: ['Diplôme', 'Bac+2', 'Professional', 'Certificat'],
      tuitionLabel: LocalizedText(fr: '25000 AED/an', en: '25000 AED/an'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['Contact KPB / school for latest intake'],
      programIds: [
        'prog_067',
        'prog_068',
        'prog_069',
        'prog_070',
        'prog_071',
        'prog_072',
        'prog_073',
        'prog_074',
        'prog_075',
        'prog_076'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'ece',
      name: LocalizedText(fr: 'OMNES - ECE', en: 'OMNES - ECE'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview:
          LocalizedText(fr: 'OMNES - ECE — France', en: 'OMNES - ECE — France'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: '8.490 EUR/an', en: '8.490 EUR/an'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['Bachelor 1ère année'],
      programIds: [
        'prog_077',
        'prog_078',
        'prog_079',
        'prog_080',
        'prog_081',
        'prog_082',
        'prog_083',
        'prog_084',
        'prog_085',
        'prog_086',
        'prog_087',
        'prog_088',
        'prog_089',
        'prog_090',
        'prog_091',
        'prog_092',
        'prog_093'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'esce',
      name: LocalizedText(fr: 'OMNES - ESCE', en: 'OMNES - ESCE'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(
          fr: 'OMNES - ESCE — France', en: 'OMNES - ESCE — France'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: '9.650 EUR/an', en: '9.650 EUR/an'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['Bachelor 1ère année'],
      programIds: [
        'prog_094',
        'prog_095',
        'prog_096',
        'prog_097',
        'prog_098',
        'prog_099',
        'prog_100',
        'prog_101',
        'prog_102',
        'prog_103',
        'prog_104',
        'prog_105',
        'prog_106'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'heip',
      name: LocalizedText(fr: 'OMNES - HEIP', en: 'OMNES - HEIP'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(
          fr: 'OMNES - HEIP — France', en: 'OMNES - HEIP — France'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: '9.650 EUR/an', en: '9.650 EUR/an'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['Bachelor 1ère année'],
      programIds: [
        'prog_107',
        'prog_108',
        'prog_109',
        'prog_110',
        'prog_111',
        'prog_112'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'inseec',
      name: LocalizedText(fr: 'OMNES - INSEEC', en: 'OMNES - INSEEC'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(
          fr: 'OMNES - INSEEC — France', en: 'OMNES - INSEEC — France'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['Bachelor 1ère année'],
      programIds: [
        'prog_113',
        'prog_114',
        'prog_115',
        'prog_116',
        'prog_117',
        'prog_118',
        'prog_119',
        'prog_120',
        'prog_121',
        'prog_122',
        'prog_123',
        'prog_124',
        'prog_125',
        'prog_126',
        'prog_127',
        'prog_128',
        'prog_129',
        'prog_130',
        'prog_131',
        'prog_132',
        'prog_133',
        'prog_134',
        'prog_135',
        'prog_136',
        'prog_137',
        'prog_138',
        'prog_139',
        'prog_140',
        'prog_141',
        'prog_142',
        'prog_143',
        'prog_144',
        'prog_145'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'ium',
      name: LocalizedText(fr: 'OMNES - IUM', en: 'OMNES - IUM'),
      countryId: 'france',
      location: LocalizedText(fr: 'Monaco', en: 'Monaco'),
      overview:
          LocalizedText(fr: 'OMNES - IUM — France', en: 'OMNES - IUM — France'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: '15.050 EUR/an', en: '15.050 EUR/an'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['Bachelor 1ère année'],
      programIds: [
        'prog_146',
        'prog_147',
        'prog_148',
        'prog_149',
        'prog_150',
        'prog_151',
        'prog_152',
        'prog_153',
        'prog_154',
        'prog_155',
        'prog_156',
        'prog_157',
        'prog_158',
        'prog_159',
        'prog_160',
        'prog_161',
        'prog_162'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'sup_de_pub',
      name: LocalizedText(fr: 'OMNES - Sup de Pub', en: 'OMNES - Sup de Pub'),
      countryId: 'france',
      location: LocalizedText(fr: 'Bordeaux', en: 'Bordeaux'),
      overview: LocalizedText(
          fr: 'OMNES - Sup de Pub — France', en: 'OMNES - Sup de Pub — France'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: '8.850 EUR/an', en: '8.850 EUR/an'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Bachelor 1ère année'],
      programIds: [
        'prog_163',
        'prog_164',
        'prog_165',
        'prog_166',
        'prog_167',
        'prog_168',
        'prog_169',
        'prog_170',
        'prog_171',
        'prog_172',
        'prog_173',
        'prog_174',
        'prog_175',
        'prog_176',
        'prog_177'
      ],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'igs_rh',
      name: LocalizedText(fr: 'IGS - IGS-RH', en: 'IGS - IGS-RH'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Toulouse, Paris, Lyon', en: 'Toulouse, Paris, Lyon'),
      overview: LocalizedText(
          fr: 'IGS - IGS-RH — France', en: 'IGS - IGS-RH — France'),
      studyLevels: ['Bac+3 / Bac+5'],
      tuitionLabel: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_178', 'prog_179'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'esam',
      name: LocalizedText(fr: 'IGS - ESAM', en: 'IGS - ESAM'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris, Lyon', en: 'Paris, Lyon'),
      overview:
          LocalizedText(fr: 'IGS - ESAM — France', en: 'IGS - ESAM — France'),
      studyLevels: ['Bac+3 / Bac+5'],
      tuitionLabel: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_180', 'prog_181', 'prog_182', 'prog_183', 'prog_184'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'iscpa',
      name: LocalizedText(fr: 'IGS - ISCPA', en: 'IGS - ISCPA'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Paris, Lyon, Toulouse', en: 'Paris, Lyon, Toulouse'),
      overview:
          LocalizedText(fr: 'IGS - ISCPA — France', en: 'IGS - ISCPA — France'),
      studyLevels: ['Bac+3 / Bac+5'],
      tuitionLabel: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_185', 'prog_186', 'prog_187'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'ipi',
      name: LocalizedText(fr: 'IGS - IPI', en: 'IGS - IPI'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Toulouse, Paris, Lyon', en: 'Toulouse, Paris, Lyon'),
      overview:
          LocalizedText(fr: 'IGS - IPI — France', en: 'IGS - IPI — France'),
      studyLevels: ['Bac+3 / Bac+5'],
      tuitionLabel: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_188', 'prog_189', 'prog_190'],
      isPartner: true,
    ),
    // ── FRANCE (non-partenaires) ───────────────────────────────────────────
    InstitutionModel(
      id: 'sorbonne',
      name: LocalizedText(fr: 'Sorbonne Université', en: 'Sorbonne Université'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(
          fr: 'L\'une des universités les plus anciennes et prestigieuses au monde.',
          en: 'One of the oldest and most prestigious universities in the world.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '170–3 770 EUR/an', en: '170–3 770 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français (B2 min) / Anglais selon programme',
          en: 'French (B2 min) / English depending on program'),
      intakePeriods: ['Septembre', 'Janvier (certains masters)'],
      programIds: ['prog_s001', 'prog_s002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'paris_saclay',
      name: LocalizedText(
          fr: 'Université Paris-Saclay', en: 'Université Paris-Saclay'),
      countryId: 'france',
      location: LocalizedText(fr: 'Île-de-France', en: 'Île-de-France'),
      overview: LocalizedText(
          fr: 'Top 15 mondial en sciences, ingénierie et mathématiques (QS 2024).',
          en: 'Top 15 globally in science, engineering and mathematics (QS 2024).'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '170–3 770 EUR/an', en: '170–3 770 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_s003', 'prog_s004'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'hec_paris',
      name: LocalizedText(fr: 'HEC Paris', en: 'HEC Paris'),
      countryId: 'france',
      location: LocalizedText(fr: 'Jouy-en-Josas', en: 'Jouy-en-Josas'),
      overview: LocalizedText(
          fr: '#1 Grande École de Management en Europe. MBA, MSc Finance, Grande École.',
          en: '#1 Business School in Europe. MBA, MSc Finance, Grande École.'),
      studyLevels: ['Bac+5', 'MBA'],
      tuitionLabel: LocalizedText(
          fr: '16 700–92 000 EUR/programme', en: '16 700–92 000 EUR/program'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (GMAT ou GRE requis)',
          en: 'English (GMAT or GRE required)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_s005'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'essec',
      name: LocalizedText(
          fr: 'ESSEC Business School', en: 'ESSEC Business School'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Cergy-Pontoise / Singapore', en: 'Cergy-Pontoise / Singapore'),
      overview: LocalizedText(
          fr: 'Grande École de Commerce top 5 en France. Fort réseau Africa Alumni.',
          en: 'Top 5 French Business School. Strong Africa Alumni network.'),
      studyLevels: ['Bac+5', 'MBA', 'Bac+3'],
      tuitionLabel:
          LocalizedText(fr: '14 700–57 600 EUR/an', en: '14 700–57 600 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais + Français', en: 'English + French'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_s006'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'sciences_po',
      name: LocalizedText(fr: 'Sciences Po Paris', en: 'Sciences Po Paris'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(
          fr: 'Référence mondiale en droit, relations internationales et sciences politiques.',
          en: 'World reference in law, international relations and political science.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(
          fr: '0–13 990 EUR/an (selon revenu)',
          en: '0–13 990 EUR/yr (income-based)'),
      languageRequirements:
          LocalizedText(fr: 'Anglais + Français', en: 'English + French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_s007'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'em_lyon',
      name: LocalizedText(
          fr: 'EM Lyon Business School', en: 'EM Lyon Business School'),
      countryId: 'france',
      location: LocalizedText(fr: 'Lyon / Paris', en: 'Lyon / Paris'),
      overview: LocalizedText(
          fr: 'Première école de management en Europe pour l\'entrepreneuriat.',
          en: 'Leading European business school for entrepreneurship.'),
      studyLevels: ['Bac+5', 'MBA', 'Bac+3'],
      tuitionLabel:
          LocalizedText(fr: '10 100–49 000 EUR/an', en: '10 100–49 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais / Français', en: 'English / French'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_s008'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'grenoble_em',
      name: LocalizedText(
          fr: 'Grenoble École de Management',
          en: 'Grenoble École de Management'),
      countryId: 'france',
      location: LocalizedText(fr: 'Grenoble', en: 'Grenoble'),
      overview: LocalizedText(
          fr: 'Top 10 en France pour le Management Technologique et l\'Innovation.',
          en: 'Top 10 in France for Technology Management and Innovation.'),
      studyLevels: ['Bac+3', 'Bac+5', 'MBA'],
      tuitionLabel:
          LocalizedText(fr: '9 500–39 000 EUR/an', en: '9 500–39 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais / Français', en: 'English / French'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_s009'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'audencia',
      name: LocalizedText(
          fr: 'Audencia Business School', en: 'Audencia Business School'),
      countryId: 'france',
      location: LocalizedText(fr: 'Nantes', en: 'Nantes'),
      overview: LocalizedText(
          fr: 'Excellence en RSE et Développement Durable. Programme PGE triple accréditation.',
          en: 'Excellence in CSR and Sustainable Development. Triple-accredited PGE program.'),
      studyLevels: ['Bac+5', 'MBA'],
      tuitionLabel:
          LocalizedText(fr: '10 900–43 000 EUR/an', en: '10 900–43 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais / Français', en: 'English / French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_s010'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'insa_lyon',
      name: LocalizedText(fr: 'INSA Lyon', en: 'INSA Lyon'),
      countryId: 'france',
      location: LocalizedText(fr: 'Lyon', en: 'Lyon'),
      overview: LocalizedText(
          fr: 'Grande école d\'ingénieurs publique, frais réduits, filières bac+5 en génie civil, informatique, mécanique.',
          en: 'Public engineering school, low fees, Bac+5 programs in civil, CS and mechanical engineering.'),
      studyLevels: ['Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '600–3 770 EUR/an', en: '600–3 770 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français (C1) / Anglais', en: 'French (C1) / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_s011'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'upec',
      name: LocalizedText(
          fr: 'Université Paris-Est Créteil (UPEC)',
          en: 'Université Paris-Est Créteil'),
      countryId: 'france',
      location: LocalizedText(fr: 'Créteil', en: 'Créteil'),
      overview: LocalizedText(
          fr: 'Grande université multidisciplinaire, frais très bas, forte communauté africaine.',
          en: 'Large multidisciplinary university, very low fees, large African student community.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '170–3 770 EUR/an', en: '170–3 770 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_s012'],
      isPartner: false,
    ),
    // ── CANADA ────────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'mcgill',
      name: LocalizedText(fr: 'Université McGill', en: 'McGill University'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
      overview: LocalizedText(
          fr: 'Top 30 mondial, bilingue, forte communauté francophone, excellente en médecine, droit et ingénierie.',
          en: 'Top 30 globally, bilingual, strong francophone community, excellent in medicine, law and engineering.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'CAD 19k–42k/an', en: 'CAD 19k–42k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5+)', en: 'English (IELTS 6.5+)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_c001', 'prog_c002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'udem',
      name: LocalizedText(
          fr: 'Université de Montréal', en: 'Université de Montréal'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
      overview: LocalizedText(
          fr: 'Top 3 des universités francophones au monde. Excellente pour les étudiants d\'Afrique francophone.',
          en: 'Top 3 francophone university worldwide. Excellent for francophone African students.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'CAD 15k–27k/an', en: 'CAD 15k–27k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (TCF B2+)', en: 'French (TCF B2+)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_c003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'hec_montreal',
      name: LocalizedText(fr: 'HEC Montréal', en: 'HEC Montréal'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
      overview: LocalizedText(
          fr: '#1 École de gestion francophone en Amérique du Nord. MBA et MSc très reconnus.',
          en: '#1 Francophone business school in North America. Highly recognized MBA and MSc.'),
      studyLevels: ['Bac+3', 'Bac+5', 'MBA'],
      tuitionLabel: LocalizedText(fr: 'CAD 18k–32k/an', en: 'CAD 18k–32k/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français / Anglais selon programme',
          en: 'French / English depending on program'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_c004'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'ulaval',
      name: LocalizedText(fr: 'Université Laval', en: 'Université Laval'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Québec City', en: 'Quebec City'),
      overview: LocalizedText(
          fr: 'Première université francophone d\'Amérique. Forte en agriculture, foresterie, médecine et droit.',
          en: 'First francophone university in America. Strong in agriculture, forestry, medicine and law.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'CAD 14k–22k/an', en: 'CAD 14k–22k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (TCF B2+)', en: 'French (TCF B2+)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_c005'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'uottawa',
      name:
          LocalizedText(fr: 'Université d\'Ottawa', en: 'University of Ottawa'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Ottawa, Ontario', en: 'Ottawa, Ontario'),
      overview: LocalizedText(
          fr: 'Seule université bilingue (FR/EN) du Canada. Droit, administration publique et sciences de la santé.',
          en: 'Canada\'s only bilingual (FR/EN) university. Law, public administration and health sciences.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'CAD 26k–38k/an', en: 'CAD 26k–38k/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français ou Anglais (IELTS 6.5)',
          en: 'French or English (IELTS 6.5)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_c006'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'concordia',
      name:
          LocalizedText(fr: 'Université Concordia', en: 'Concordia University'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
      overview: LocalizedText(
          fr: 'Université anglophone dynamique à Montréal. Forte en média, arts, business et génie.',
          en: 'Dynamic English-language university in Montreal. Strong in media, arts, business and engineering.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'CAD 20k–30k/an', en: 'CAD 20k–30k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5+)', en: 'English (IELTS 6.5+)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_c007'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'uqam',
      name: LocalizedText(
          fr: 'Université du Québec à Montréal (UQAM)', en: 'UQAM'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Montréal, Québec', en: 'Montreal, Quebec'),
      overview: LocalizedText(
          fr: 'Université publique abordable. Forte en communication, arts et sciences sociales. Très accueillante pour Africa.',
          en: 'Affordable public university. Strong in communications, arts and social sciences. Very welcoming for Africa.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'CAD 13k–18k/an', en: 'CAD 13k–18k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_c008'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'usherbrooke',
      name: LocalizedText(
          fr: 'Université de Sherbrooke', en: 'Université de Sherbrooke'),
      countryId: 'canada',
      location:
          LocalizedText(fr: 'Sherbrooke, Québec', en: 'Sherbrooke, Quebec'),
      overview: LocalizedText(
          fr: 'Pionnière en co-op (alternance travail-études). Excellente en génie, médecine et environnement.',
          en: 'Pioneer in co-op (work-study). Excellent in engineering, medicine and environment.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'CAD 12k–20k/an', en: 'CAD 12k–20k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2+)', en: 'French (B2+)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_c009'],
      isPartner: false,
    ),
    // ── UK ────────────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'ucl',
      name: LocalizedText(
          fr: 'University College London (UCL)',
          en: 'University College London (UCL)'),
      countryId: 'uk',
      location: LocalizedText(fr: 'Londres', en: 'London'),
      overview: LocalizedText(
          fr: 'Top 10 mondial. Médecine, droit, architecture et sciences sociales de classe mondiale.',
          en: 'Top 10 globally. World-class medicine, law, architecture and social sciences.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'GBP 18k–35k/an', en: 'GBP 18k–35k/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (IELTS 6.5–7.0)', en: 'English (IELTS 6.5–7.0)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_uk001', 'prog_uk002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'kings_college',
      name: LocalizedText(
          fr: 'King\'s College London', en: 'King\'s College London'),
      countryId: 'uk',
      location: LocalizedText(fr: 'Londres', en: 'London'),
      overview: LocalizedText(
          fr: 'Top 40 mondial. Droit, médecine, dentisterie, sciences de la vie et humanités.',
          en: 'Top 40 globally. Law, medicine, dentistry, life sciences and humanities.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'GBP 17k–28k/an', en: 'GBP 17k–28k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_uk003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'edinburgh',
      name: LocalizedText(
          fr: 'Université d\'Édimbourg', en: 'University of Edinburgh'),
      countryId: 'uk',
      location:
          LocalizedText(fr: 'Édimbourg, Écosse', en: 'Edinburgh, Scotland'),
      overview: LocalizedText(
          fr: 'Top 30 mondial. Informatique, médecine vétérinaire, sciences et arts. Très accueillante aux étudiants internationaux.',
          en: 'Top 30 globally. CS, veterinary, sciences and arts. Very welcoming to international students.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'GBP 18k–32k/an', en: 'GBP 18k–32k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_uk004'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'manchester',
      name: LocalizedText(
          fr: 'Université de Manchester', en: 'University of Manchester'),
      countryId: 'uk',
      location: LocalizedText(fr: 'Manchester', en: 'Manchester'),
      overview: LocalizedText(
          fr: 'Top 30 mondial. Économie, ingénierie, physique (Nobel), management.',
          en: 'Top 30 globally. Economics, engineering, physics (Nobel), management.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'GBP 17k–26k/an', en: 'GBP 17k–26k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_uk005'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'warwick',
      name: LocalizedText(
          fr: 'Université de Warwick', en: 'University of Warwick'),
      countryId: 'uk',
      location: LocalizedText(fr: 'Coventry', en: 'Coventry'),
      overview: LocalizedText(
          fr: 'Top 70 mondial. Économie, mathématiques appliquées et Warwick Business School reconnus mondialement.',
          en: 'Top 70 globally. Economics, applied mathematics and world-renowned Warwick Business School.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'GBP 19k–27k/an', en: 'GBP 19k–27k/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_uk006'],
      isPartner: false,
    ),
    // ── ALLEMAGNE ─────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'tu_munich',
      name: LocalizedText(
          fr: 'TU Munich (Technische Universität München)', en: 'TU Munich'),
      countryId: 'germany',
      location: LocalizedText(fr: 'Munich', en: 'Munich'),
      overview: LocalizedText(
          fr: '#1 en ingénierie en Allemagne. Quasi-gratuit pour les non-ressortissants UE. Hub BMW, Siemens et SAP.',
          en: '#1 in engineering in Germany. Nearly free for non-EU students. Hub for BMW, Siemens and SAP.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: '0–129 EUR/semestre + 258 EUR frais',
          en: '0–129 EUR/semester + 258 EUR fees'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (IELTS 6.5) / Allemand (C1) selon programme',
          en: 'English (IELTS 6.5) / German (C1) depending on program'),
      intakePeriods: ['Octobre', 'Avril'],
      programIds: ['prog_de001', 'prog_de002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'heidelberg',
      name: LocalizedText(
          fr: 'Université de Heidelberg', en: 'Heidelberg University'),
      countryId: 'germany',
      location: LocalizedText(fr: 'Heidelberg', en: 'Heidelberg'),
      overview: LocalizedText(
          fr: 'Plus ancienne université d\'Allemagne. Excellence en médecine, biologie et droit. Nombreuses bourses DAAD.',
          en: 'Oldest university in Germany. Excellence in medicine, biology and law. Many DAAD scholarships.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: '0–1 500 EUR/an', en: '0–1 500 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Allemand (C1) / Anglais selon master',
          en: 'German (C1) / English for select masters'),
      intakePeriods: ['Octobre', 'Avril'],
      programIds: ['prog_de003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'rwth_aachen',
      name: LocalizedText(fr: 'RWTH Aachen', en: 'RWTH Aachen University'),
      countryId: 'germany',
      location: LocalizedText(fr: 'Aachen', en: 'Aachen'),
      overview: LocalizedText(
          fr: 'Top école d\'ingénieurs d\'Europe. Génie mécanique, électrique et automobile. Partennariats industriels forts.',
          en: 'Top engineering school in Europe. Mechanical, electrical and automotive engineering. Strong industry partnerships.'),
      studyLevels: ['Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: '0 EUR/semestre (+ frais admin ~260 EUR)',
          en: '0 EUR/semester (+ admin fees ~260 EUR)'),
      languageRequirements: LocalizedText(
          fr: 'Anglais ou Allemand (C1)', en: 'English or German (C1)'),
      intakePeriods: ['Octobre', 'Avril'],
      programIds: ['prog_de004'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'lmu_munich',
      name: LocalizedText(
          fr: 'LMU Munich (Ludwig-Maximilians-Universität)', en: 'LMU Munich'),
      countryId: 'germany',
      location: LocalizedText(fr: 'Munich', en: 'Munich'),
      overview: LocalizedText(
          fr: 'Top 100 mondial. Droit, médecine, économie et sciences humaines. 36 lauréats Nobel parmi ses anciens.',
          en: 'Top 100 globally. Law, medicine, economics and humanities. 36 Nobel Laureates among alumni.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: '0–400 EUR/an', en: '0–400 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Allemand (C1) / Anglais pour masters en anglais',
          en: 'German (C1) / English for English-taught masters'),
      intakePeriods: ['Octobre', 'Avril'],
      programIds: ['prog_de005'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'fu_berlin',
      name: LocalizedText(
          fr: 'Freie Universität Berlin (FU Berlin)',
          en: 'Freie Universität Berlin'),
      countryId: 'germany',
      location: LocalizedText(fr: 'Berlin', en: 'Berlin'),
      overview: LocalizedText(
          fr: 'Top 100 mondial. Hub culturel de Berlin. Sciences politiques, histoire et sciences humaines de premier plan.',
          en: 'Top 100 globally. Berlin cultural hub. Leading political science, history and humanities.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: '0 EUR/semestre (+ 325 EUR frais)',
          en: '0 EUR/semester (+ 325 EUR fees)'),
      languageRequirements: LocalizedText(
          fr: 'Allemand (C1) / Anglais pour masters',
          en: 'German (C1) / English for masters'),
      intakePeriods: ['Octobre', 'Avril'],
      programIds: ['prog_de006'],
      isPartner: false,
    ),
    // ── USA ───────────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'nyu',
      name: LocalizedText(
          fr: 'New York University (NYU)', en: 'New York University (NYU)'),
      countryId: 'usa',
      location: LocalizedText(fr: 'New York, NY', en: 'New York, NY'),
      overview: LocalizedText(
          fr: 'Top 30 aux USA. Campus en plein cœur de Manhattan. Business, arts, droit, médecine. Communauté africaine active.',
          en: 'Top 30 in the US. Campus in the heart of Manhattan. Business, arts, law, medicine. Active African community.'),
      studyLevels: ['Bac+3', 'Bac+5', 'MBA', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'USD 54 000–60 000/an', en: 'USD 54 000–60 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL 84+ / IELTS 7.0)',
          en: 'English (TOEFL 84+ / IELTS 7.0)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_us001', 'prog_us002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'boston_u',
      name: LocalizedText(fr: 'Boston University', en: 'Boston University'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Boston, MA', en: 'Boston, MA'),
      overview: LocalizedText(
          fr: 'Top 40 national. Business, communication, médecine et ingénierie. Fort soutien aux étudiants internationaux.',
          en: 'Top 40 national. Business, communications, medicine and engineering. Strong international student support.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'USD 56 000/an', en: 'USD 56 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 84+)', en: 'English (TOEFL 84+)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_us003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'howard',
      name: LocalizedText(fr: 'Howard University', en: 'Howard University'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Washington D.C.', en: 'Washington D.C.'),
      overview: LocalizedText(
          fr: 'HBCU (Historically Black College). Université de référence pour les étudiants africains aux USA. Droit, médecine, business.',
          en: 'HBCU (Historically Black College). Reference university for African students in the USA. Law, medicine, business.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'USD 28 000/an', en: 'USD 28 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 80+)', en: 'English (TOEFL 80+)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_us004'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'georgia_tech',
      name: LocalizedText(
          fr: 'Georgia Institute of Technology', en: 'Georgia Tech'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Atlanta, GA', en: 'Atlanta, GA'),
      overview: LocalizedText(
          fr: 'Top 5 en ingénierie aux USA. Très abordable comparé aux autres grandes universités américaines.',
          en: 'Top 5 engineering school in the US. Very affordable compared to other major American universities.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'USD 31 000/an (international)',
          en: 'USD 31 000/yr (international)'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 100+)', en: 'English (TOEFL 100+)'),
      intakePeriods: ['Août', 'Janvier'],
      programIds: ['prog_us005'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'arizona_state',
      name: LocalizedText(
          fr: 'Arizona State University (ASU)',
          en: 'Arizona State University (ASU)'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Tempe, AZ', en: 'Tempe, AZ'),
      overview: LocalizedText(
          fr: 'N°1 en innovation aux USA (US News). Programmes online et en présentiel. Très accueillante pour les étudiants internationaux.',
          en: '#1 in innovation in the US (US News). Online and on-campus programs. Very welcoming to international students.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'USD 29 000/an', en: 'USD 29 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 70+)', en: 'English (TOEFL 70+)'),
      intakePeriods: ['Août', 'Janvier'],
      programIds: ['prog_us006'],
      isPartner: false,
    ),
    // ── BELGIQUE ──────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'ulb',
      name: LocalizedText(fr: 'Université Libre de Bruxelles (ULB)', en: 'ULB'),
      countryId: 'belgium',
      location: LocalizedText(fr: 'Bruxelles', en: 'Brussels'),
      overview: LocalizedText(
          fr: 'Top 200 mondial. Droit, médecine, économie. Très forte communauté africaine. En plein cœur de Bruxelles (EU).',
          en: 'Top 200 globally. Law, medicine, economics. Very strong African community. In the heart of Brussels (EU).'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '835–4 175 EUR/an', en: '835–4 175 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_be001', 'prog_be002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'uclouvain',
      name: LocalizedText(
          fr: 'UCLouvain (Université catholique de Louvain)', en: 'UCLouvain'),
      countryId: 'belgium',
      location: LocalizedText(fr: 'Louvain-la-Neuve', en: 'Louvain-la-Neuve'),
      overview: LocalizedText(
          fr: 'Top 200 mondial. Excellence en médecine, ingénierie et sciences humaines. Très forte tradition de coopération avec l\'Afrique.',
          en: 'Top 200 globally. Excellence in medicine, engineering and humanities. Strong tradition of cooperation with Africa.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '992–4 175 EUR/an', en: '992–4 175 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2+)', en: 'French (B2+)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_be003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'ugent',
      name: LocalizedText(
          fr: 'Université de Gand (UGhent)', en: 'Ghent University'),
      countryId: 'belgium',
      location: LocalizedText(fr: 'Gand', en: 'Ghent'),
      overview: LocalizedText(
          fr: 'Top 100 mondial. Langue néerlandaise mais nombreux masters en anglais. Bource de développement pour étudiants africains.',
          en: 'Top 100 globally. Dutch language but many English-taught masters. Development scholarships for African students.'),
      studyLevels: ['Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '920–4 175 EUR/an', en: '920–4 175 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (IELTS 6.5) pour masters en EN',
          en: 'English (IELTS 6.5) for EN-taught masters'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_be004'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'vub',
      name: LocalizedText(fr: 'Vrije Universiteit Brussel (VUB)', en: 'VUB'),
      countryId: 'belgium',
      location: LocalizedText(fr: 'Bruxelles', en: 'Brussels'),
      overview: LocalizedText(
          fr: 'Université anglophone en plein cœur de Bruxelles. Fort en IA, ingénierie et sciences politiques. Bourses VUB Africa.',
          en: 'English-language university in the heart of Brussels. Strong in AI, engineering and political science. VUB Africa scholarships.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '992–4 175 EUR/an', en: '992–4 175 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_be005'],
      isPartner: false,
    ),
    // ── PORTUGAL ──────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'nova_lisboa',
      name: LocalizedText(
          fr: 'Universidade NOVA de Lisboa', en: 'NOVA University Lisbon'),
      countryId: 'portugal',
      location: LocalizedText(fr: 'Lisbonne', en: 'Lisbon'),
      overview: LocalizedText(
          fr: 'Top 250 mondial. Économie, droit, sciences et nova SBE (Business School) reconnue en Europe.',
          en: 'Top 250 globally. Economics, law, sciences and nova SBE (Business School) recognized across Europe.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '950–7 000 EUR/an', en: '950–7 000 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Portugais / Anglais selon programme',
          en: 'Portuguese / English depending on program'),
      intakePeriods: ['Septembre', 'Février'],
      programIds: ['prog_pt001', 'prog_pt002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'universidade_coimbra',
      name: LocalizedText(
          fr: 'Université de Coimbra', en: 'University of Coimbra'),
      countryId: 'portugal',
      location: LocalizedText(fr: 'Coimbra', en: 'Coimbra'),
      overview: LocalizedText(
          fr: 'Plus ancienne université du Portugal et du monde lusophone. Patrimoine UNESCO. Droit, médecine et ingénierie.',
          en: 'Oldest university in Portugal and the Lusophone world. UNESCO Heritage. Law, medicine and engineering.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '700–3 000 EUR/an', en: '700–3 000 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Portugais (B2) / Anglais pour masters',
          en: 'Portuguese (B2) / English for masters'),
      intakePeriods: ['Septembre', 'Février'],
      programIds: ['prog_pt003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'iscte',
      name: LocalizedText(
          fr: 'ISCTE — Iscte Business School', en: 'ISCTE Business School'),
      countryId: 'portugal',
      location: LocalizedText(fr: 'Lisbonne', en: 'Lisbon'),
      overview: LocalizedText(
          fr: 'École de management de référence au Portugal. Masters en Finance, Marketing et MBA. Hub pour PALOP.',
          en: 'Reference management school in Portugal. Masters in Finance, Marketing and MBA. Hub for PALOP countries.'),
      studyLevels: ['Bac+3', 'Bac+5', 'MBA'],
      tuitionLabel:
          LocalizedText(fr: '3 500–12 000 EUR/an', en: '3 500–12 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Portugais / Anglais', en: 'Portuguese / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_pt004'],
      isPartner: false,
    ),
    // ── SUISSE ────────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'epfl',
      name: LocalizedText(
          fr: 'EPFL — École Polytechnique Fédérale de Lausanne', en: 'EPFL'),
      countryId: 'switzerland',
      location: LocalizedText(fr: 'Lausanne', en: 'Lausanne'),
      overview: LocalizedText(
          fr: 'Top 15 mondial en ingénierie et technologie. L\'une des meilleures écoles d\'ingénieurs au monde.',
          en: 'Top 15 globally in engineering and technology. One of the best engineering schools in the world.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'CHF 730/semestre', en: 'CHF 730/semester'),
      languageRequirements: LocalizedText(
          fr: 'Anglais ou Français selon programme. IELTS 7.0+ pour masters en EN.',
          en: 'English or French depending on the program. IELTS 7.0+ for EN masters.'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ch001', 'prog_ch002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'ethz',
      name: LocalizedText(fr: 'ETH Zurich', en: 'ETH Zurich'),
      countryId: 'switzerland',
      location: LocalizedText(fr: 'Zurich', en: 'Zurich'),
      overview: LocalizedText(
          fr: 'Top 10 mondial. Science, technologie, ingénierie et mathématiques. 21 prix Nobel parmi ses anciens.',
          en: 'Top 10 globally. Science, technology, engineering and mathematics. 21 Nobel prizes among alumni.'),
      studyLevels: ['Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'CHF 730/semestre', en: 'CHF 730/semester'),
      languageRequirements: LocalizedText(
          fr: 'Anglais ou Allemand. IELTS 7.0+ pour les masters en anglais.',
          en: 'English or German. IELTS 7.0+ for English-taught masters.'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ch003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'hec_lausanne',
      name: LocalizedText(fr: 'HEC Lausanne (UNIL)', en: 'HEC Lausanne (UNIL)'),
      countryId: 'switzerland',
      location: LocalizedText(fr: 'Lausanne', en: 'Lausanne'),
      overview: LocalizedText(
          fr: 'École de commerce de référence en Suisse romande. Gestion, finance et entrepreneuriat. Langue fr ET en.',
          en: 'Reference business school in French-speaking Switzerland. Management, finance and entrepreneurship. French AND English.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: 'CHF 580/semestre', en: 'CHF 580/semester'),
      languageRequirements: LocalizedText(
          fr: 'Français (C1) ou Anglais (IELTS 7.0) selon programme',
          en: 'French (C1) or English (IELTS 7.0) depending on program'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ch004'],
      isPartner: false,
    ),
    // ── ITALIE ────────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'bocconi',
      name: LocalizedText(fr: 'Université Bocconi', en: 'Università Bocconi'),
      countryId: 'italy',
      location: LocalizedText(fr: 'Milan', en: 'Milan'),
      overview: LocalizedText(
          fr: 'Top 10 mondiale en management et économie. SDA Bocconi School of Management réputée mondialement.',
          en: 'Top 10 globally in management and economics. SDA Bocconi School of Management world-renowned.'),
      studyLevels: ['Bac+3', 'Bac+5', 'MBA'],
      tuitionLabel: LocalizedText(
          fr: '14 000–54 000 EUR/an (selon revenu)',
          en: '14 000–54 000 EUR/yr (income-based)'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL 100 / IELTS 7.0)',
          en: 'English (TOEFL 100 / IELTS 7.0)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_it001', 'prog_it002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'politecnico_milano',
      name: LocalizedText(
          fr: 'Politecnico di Milano', en: 'Politecnico di Milano'),
      countryId: 'italy',
      location: LocalizedText(fr: 'Milan', en: 'Milan'),
      overview: LocalizedText(
          fr: 'Top 10 mondial en design et ingénierie. Architecture, design industriel, ingénierie mécanique et nucléaire.',
          en: 'Top 10 globally in design and engineering. Architecture, industrial design, mechanical and nuclear engineering.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: '1 000–3 900 EUR/an (selon revenu)',
          en: '1 000–3 900 EUR/yr (income-based)'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (IELTS 6.5) pour programmes en EN',
          en: 'English (IELTS 6.5) for EN-taught programs'),
      intakePeriods: ['Septembre', 'Février'],
      programIds: ['prog_it003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'sapienza',
      name: LocalizedText(
          fr: 'Sapienza Università di Roma', en: 'Sapienza University of Rome'),
      countryId: 'italy',
      location: LocalizedText(fr: 'Rome', en: 'Rome'),
      overview: LocalizedText(
          fr: 'La plus grande université d\'Europe. Très abordable. Médecine, ingénierie, droit et architecture.',
          en: 'The largest university in Europe. Very affordable. Medicine, engineering, law and architecture.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: '1 000–2 500 EUR/an', en: '1 000–2 500 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Italien / Anglais pour masters en EN',
          en: 'Italian / English for EN masters'),
      intakePeriods: ['Octobre', 'Février'],
      programIds: ['prog_it004'],
      isPartner: false,
    ),
    // ── RUSSIE ────────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'mgu',
      name: LocalizedText(
          fr: 'Université d\'État de Moscou (MGU/Lomonossov)',
          en: 'Lomonosov Moscow State University'),
      countryId: 'russia',
      location: LocalizedText(fr: 'Moscou', en: 'Moscow'),
      overview: LocalizedText(
          fr: 'Top 100 mondial. Physique, mathématiques et chimie de renommée mondiale. Fort programme de bourses pour étudiants africains.',
          en: 'Top 100 globally. World-renowned physics, mathematics and chemistry. Strong scholarship program for African students.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'USD 3 000–8 000/an (ou bourse gratuite)',
          en: 'USD 3 000–8 000/yr (or free scholarship)'),
      languageRequirements: LocalizedText(
          fr: 'Russe (certificat requis après 1 an préparatoire) / Anglais pour certains masters',
          en: 'Russian (certificate after 1-year prep) / English for select masters'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ru001', 'prog_ru002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'spbgu',
      name: LocalizedText(
          fr: 'Université d\'État de Saint-Pétersbourg (SPbGU)',
          en: 'Saint Petersburg State University'),
      countryId: 'russia',
      location: LocalizedText(fr: 'Saint-Pétersbourg', en: 'Saint Petersburg'),
      overview: LocalizedText(
          fr: '2ème université de Russie. Droit, économie et relations internationales. Nombreux programmes en anglais. Ville magnifique.',
          en: '2nd university in Russia. Law, economics and international relations. Many English programs. Beautiful city.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'USD 2 500–6 000/an', en: 'USD 2 500–6 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Russe ou Anglais selon programme',
          en: 'Russian or English depending on program'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ru003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'peoples_friendship',
      name: LocalizedText(
          fr: 'Université de l\'Amitié des Peuples (RUDN)',
          en: 'Peoples\' Friendship University of Russia (RUDN)'),
      countryId: 'russia',
      location: LocalizedText(fr: 'Moscou', en: 'Moscow'),
      overview: LocalizedText(
          fr: 'L\'université la plus internationale de Russie. Créée pour accueillir les étudiants du monde en développement. Très forte communauté africaine.',
          en: 'Russia\'s most international university. Created for students from developing nations. Very strong African community.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'USD 2 000–5 000/an', en: 'USD 2 000–5 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Russe + 1 an préparatoire inclus / Anglais pour certains programmes',
          en: 'Russian + 1-year prep included / English for select programs'),
      intakePeriods: ['Septembre', 'Février'],
      programIds: ['prog_ru004'],
      isPartner: false,
    ),
    // ── JAPON ─────────────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'utokyo',
      name: LocalizedText(
          fr: 'Université de Tokyo (UTokyo)', en: 'University of Tokyo'),
      countryId: 'japan',
      location: LocalizedText(fr: 'Tokyo', en: 'Tokyo'),
      overview: LocalizedText(
          fr: 'Top 30 mondial. #1 en Asie. Ingénierie, médecine, économie. Bourse MEXT très compétitive (couvre tout).',
          en: 'Top 30 globally. #1 in Asia. Engineering, medicine, economics. Highly competitive MEXT scholarship (covers all).'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'JPY 535 800/an (ou bourse MEXT)',
          en: 'JPY 535 800/yr (or MEXT scholarship)'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL 79+) / Japonais pour certains programmes',
          en: 'English (TOEFL 79+) / Japanese for some programs'),
      intakePeriods: ['Avril', 'Octobre'],
      programIds: ['prog_jp001', 'prog_jp002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'osaka_u',
      name: LocalizedText(fr: 'Université d\'Osaka', en: 'Osaka University'),
      countryId: 'japan',
      location: LocalizedText(fr: 'Osaka', en: 'Osaka'),
      overview: LocalizedText(
          fr: 'Top 80 mondial. Excellence en médecine, sciences naturelles et ingénierie. Nombreux programmes en anglais via TAICOS.',
          en: 'Top 80 globally. Excellence in medicine, natural sciences and engineering. Many English programs via TAICOS.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'JPY 535 800/an (ou bourse MEXT)',
          en: 'JPY 535 800/yr (or MEXT scholarship)'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (IELTS 6.5) pour programmes TAICOS',
          en: 'English (IELTS 6.5) for TAICOS programs'),
      intakePeriods: ['Avril', 'Octobre'],
      programIds: ['prog_jp003'],
      isPartner: false,
    ),
    // ── ARABIE SAOUDITE ────────────────────────────────────────────────────────
    InstitutionModel(
      id: 'kaust',
      name: LocalizedText(
          fr: 'KAUST (King Abdullah University of Science and Technology)',
          en: 'KAUST'),
      countryId: 'saudi_arabia',
      location: LocalizedText(fr: 'Thuwal (Jeddah)', en: 'Thuwal (Jeddah)'),
      overview: LocalizedText(
          fr: 'Top 100 mondial en recherche. 100% internationaux. Bourses complètes (logement + salaire + santé). 100% anglais.',
          en: 'Top 100 globally in research. 100% international. Full scholarships (housing + stipend + health). 100% English.'),
      studyLevels: ['Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'Gratuit + bourse complète', en: 'Free + full scholarship'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (IELTS 6.5 ou TOEFL 79)',
          en: 'English (IELTS 6.5 or TOEFL 79)'),
      intakePeriods: ['Août'],
      programIds: ['prog_sa001', 'prog_sa002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'kfu',
      name: LocalizedText(
          fr: 'King Faisal University (KFU)', en: 'King Faisal University'),
      countryId: 'saudi_arabia',
      location: LocalizedText(fr: 'Al-Ahsa', en: 'Al-Ahsa'),
      overview: LocalizedText(
          fr: 'Université publique saoudienne avec bourses pour étudiants de pays OCI (Organisation Coopération Islamique). Agriculture, médecine, ingénierie.',
          en: 'Saudi public university with scholarships for OIC country students. Agriculture, medicine, engineering.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'Gratuit pour boursiers OCI',
          en: 'Free for OIC scholarship holders'),
      languageRequirements: LocalizedText(
          fr: 'Arabe / Anglais selon programme',
          en: 'Arabic / English depending on program'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_sa003'],
      isPartner: false,
    ),
    // ── MAROC (supplémentaires) ────────────────────────────────────────────────
    InstitutionModel(
      id: 'um5',
      name: LocalizedText(
          fr: 'Université Mohammed V (UM5) Rabat',
          en: 'Mohammed V University Rabat'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Rabat', en: 'Rabat'),
      overview: LocalizedText(
          fr: 'Première université publique du Maroc. Droit, médecine, économie et lettres. Frais très abordables pour africains.',
          en: 'First public university in Morocco. Law, medicine, economics and letters. Very affordable for African students.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'MAD 600–2 000/an', en: 'MAD 600–2 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français (B2) / Arabe', en: 'French (B2) / Arabic'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma001'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'mundiapolis',
      name: LocalizedText(
          fr: 'Université Mundiapolis', en: 'Mundiapolis University'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Casablanca', en: 'Casablanca'),
      overview: LocalizedText(
          fr: 'Université privée dynamique, orientée vers les métiers du numérique, du business et du droit. Très ouverte aux sub-sahariens.',
          en: 'Dynamic private university, focused on digital, business and law careers. Very welcoming to sub-Saharan students.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: 'MAD 32 000–55 000/an', en: 'MAD 32 000–55 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français (B2) / Anglais', en: 'French (B2) / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'uir',
      name: LocalizedText(
          fr: 'Université Internationale de Rabat (UIR)',
          en: 'International University of Rabat'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Rabat', en: 'Rabat'),
      overview: LocalizedText(
          fr: 'Université innovante en partenariat avec grandes écoles françaises. Ingénierie, management et digital.',
          en: 'Innovative university partnered with French grandes écoles. Engineering, management and digital.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: 'MAD 45 000–70 000/an', en: 'MAD 45 000–70 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma003'],
      isPartner: false,
    ),
    // ── TURQUIE (supplémentaires) ─────────────────────────────────────────────
    InstitutionModel(
      id: 'istanbul_u',
      name: LocalizedText(
          fr: 'Université d\'Istanbul', en: 'Istanbul University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
      overview: LocalizedText(
          fr: 'Plus ancienne université de Turquie. Droit, médecine et littérature. Bourse Türkiye Burslari couvre tout.',
          en: 'Oldest university in Turkey. Law, medicine and literature. Türkiye Burslari scholarship covers everything.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'USD 500–3 000/an (ou bourse Türkiye Burslari)',
          en: 'USD 500–3 000/yr (or Türkiye Burslari)'),
      languageRequirements: LocalizedText(
          fr: 'Turc (après année préparatoire) / Anglais pour certains masters',
          en: 'Turkish (after prep year) / English for select masters'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_tr001'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'bogazici',
      name: LocalizedText(fr: 'Université Boğaziçi', en: 'Boğaziçi University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
      overview: LocalizedText(
          fr: '#1 en Turquie selon de nombreux classements. Enseignement 100% en anglais. Sciences, ingénierie et économie.',
          en: '#1 in Turkey by many rankings. 100% English-medium instruction. Sciences, engineering and economics.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'USD 1 000–4 000/an', en: 'USD 1 000–4 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL 80+ / IELTS 6.5)',
          en: 'English (TOEFL 80+ / IELTS 6.5)'),
      intakePeriods: ['Septembre', 'Février'],
      programIds: ['prog_tr002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'metu',
      name: LocalizedText(
          fr: 'Middle East Technical University (METU/ODTÜ)',
          en: 'Middle East Technical University (METU)'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Ankara', en: 'Ankara'),
      overview: LocalizedText(
          fr: 'Top école d\'ingénieurs de Turquie. 100% anglais. Très forte en génie civil, aérospatiale et TIC.',
          en: 'Top engineering school in Turkey. 100% English. Very strong in civil, aerospace and ICT engineering.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'USD 800–3 000/an', en: 'USD 800–3 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL 79 / IELTS 6.5)',
          en: 'English (TOEFL 79 / IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_tr003'],
      isPartner: false,
    ),
    // ── CHINE (supplémentaires) ───────────────────────────────────────────────
    InstitutionModel(
      id: 'tsinghua',
      name: LocalizedText(fr: 'Université Tsinghua', en: 'Tsinghua University'),
      countryId: 'china',
      location: LocalizedText(fr: 'Pékin', en: 'Beijing'),
      overview: LocalizedText(
          fr: '#1 en Chine. Top 20 mondial en ingénierie. Nombreux programmes en anglais pour masters. Bourse chinoise HSK.',
          en: '#1 in China. Top 20 globally in engineering. Many English-taught master programs. Chinese HSK scholarship.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'CNY 26 000–45 000/an (ou bourse CSC)',
          en: 'CNY 26 000–45 000/yr (or CSC scholarship)'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (IELTS 6.5) pour programmes EN / Chinois (HSK 5) pour programmes CN',
          en: 'English (IELTS 6.5) for EN programs / Chinese (HSK 5) for CN programs'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_cn001', 'prog_cn002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'fudan',
      name: LocalizedText(fr: 'Université Fudan', en: 'Fudan University'),
      countryId: 'china',
      location: LocalizedText(fr: 'Shanghai', en: 'Shanghai'),
      overview: LocalizedText(
          fr: 'Top 30 en Asie. Médecine, économie et droit de référence en Chine. Fort programme Fudan-Africa.',
          en: 'Top 30 in Asia. Medicine, economics and law of reference in China. Strong Fudan-Africa program.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'CNY 24 000–38 000/an', en: 'CNY 24 000–38 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais ou Chinois selon programme',
          en: 'English or Chinese depending on program'),
      intakePeriods: ['Septembre', 'Mars'],
      programIds: ['prog_cn003'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'bnu',
      name: LocalizedText(
          fr: 'Université Normale de Beijing (BNU)',
          en: 'Beijing Normal University'),
      countryId: 'china',
      location: LocalizedText(fr: 'Pékin', en: 'Beijing'),
      overview: LocalizedText(
          fr: 'Spécialisée en éducation et humanités. Nombreuses bourses pour étudiants africains. Langue d\'enseignement CN ou EN.',
          en: 'Specialized in education and humanities. Many scholarships for African students. Teaching language CN or EN.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'CNY 20 000–30 000/an (ou bourse HSK)',
          en: 'CNY 20 000–30 000/yr (or HSK scholarship)'),
      languageRequirements: LocalizedText(
          fr: 'Chinois (HSK 4+) / Anglais pour certains masters',
          en: 'Chinese (HSK 4+) / English for select masters'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_cn004'],
      isPartner: false,
    ),
    // ── MAROC (Privées supplémentaires) ─────────────────────────────────────────
    InstitutionModel(
      id: 'emines',
      name: LocalizedText(
          fr: 'EMINES - School of Industrial Management (UM6P)',
          en: 'EMINES - School of Industrial Management (UM6P)'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Benguérir', en: 'Benguerir'),
      overview: LocalizedText(
          fr: 'École d\'ingénieurs d\'excellence de l\'UM6P. Forte employabilité et partenariats industriels (OCP).',
          en: 'Top engineering school of UM6P. High employability and industry partnerships (OCP).'),
      studyLevels: ['Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'MAD 75 000/an (Bourses dispo)',
          en: 'MAD 75 000/yr (Scholarships info)'),
      languageRequirements: LocalizedText(
          fr: 'Français / Anglais (B2+)', en: 'French / English (B2+)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma_priv001'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'uiz_priv',
      name: LocalizedText(
          fr: 'Universiapolis - Université Internationale d\'Agadir',
          en: 'Universiapolis - International University of Agadir'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Agadir', en: 'Agadir'),
      overview: LocalizedText(
          fr: '1er campus intégré au Maroc. Ingénierie, Management, Tourisme. Fort accueil des étudiants subsahariens.',
          en: '1st integrated campus in Morocco. Engineering, Management, Tourism. Strong welcome for sub-Saharan students.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: 'MAD 35 000–50 000/an', en: 'MAD 35 000–50 000/yr'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma_priv002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'upm',
      name: LocalizedText(
          fr: 'Université Privée de Marrakech (UPM)',
          en: 'Private University of Marrakech (UPM)'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Marrakech', en: 'Marrakesh'),
      overview: LocalizedText(
          fr: 'Cadre exceptionnel. Forte en Hôtellerie, Management, et Santé. Reconnue par l\'État.',
          en: 'Exceptional setting. Strong in Hospitality, Management, and Health. State-recognized.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: 'MAD 45 000–60 000/an', en: 'MAD 45 000–60 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma_priv003'],
      isPartner: false,
    ),
    // ── TURQUIE (Privées supplémentaires) ───────────────────────────────────────
    InstitutionModel(
      id: 'bilkent',
      name: LocalizedText(fr: 'Bilkent University', en: 'Bilkent University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Ankara', en: 'Ankara'),
      overview: LocalizedText(
          fr: 'Université privée de très haut niveau, 100% en anglais. Incubateur de talents en tech et sciences.',
          en: 'Top-tier private university, 100% in English. Talent incubator for tech and sciences.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'USD 8 500/an (bourses au mérite)',
          en: 'USD 8 500/yr (merit scholarships)'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL / IELTS)', en: 'English (TOEFL / IELTS)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_tr_priv001'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'sabanci',
      name: LocalizedText(fr: 'Sabancı University', en: 'Sabancı University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
      overview: LocalizedText(
          fr: 'Système innovant sans départements fixes la 1ère année. Top recherche. Bourses généreuses pour étudiants internationaux.',
          en: 'Innovative system with no fixed departments in 1st year. Top research. Generous scholarships for intl students.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'USD 19 500/an', en: 'USD 19 500/yr'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['Septembre', 'Février'],
      programIds: ['prog_tr_priv002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'koc',
      name: LocalizedText(fr: 'Koç University', en: 'Koç University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
      overview: LocalizedText(
          fr: 'L\'une des universités privées les plus prestigieuses et sélectives de Turquie. Réseau Alumni très puissant.',
          en: 'One of the most prestigious and selective private universities in Turkey. Very powerful Alumni network.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'USD 21 000/an', en: 'USD 21 000/yr'),
      languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_tr_priv003'],
      isPartner: false,
    ),
    // ── USA (Privées supplémentaires) ───────────────────────────────────────────
    InstitutionModel(
      id: 'babson',
      name: LocalizedText(fr: 'Babson College', en: 'Babson College'),
      countryId: 'usa',
      location: LocalizedText(
          fr: 'Wellesley, MA (Boston)', en: 'Wellesley, MA (Boston)'),
      overview: LocalizedText(
          fr: '#1 Mondial pour l\'Entrepreneuriat. Programmes très orientés action et business familial.',
          en: '#1 Globally for Entrepreneurship. Highly action-oriented programs and family business focus.'),
      studyLevels: ['Bac+3', 'MBA'],
      tuitionLabel: LocalizedText(fr: 'USD 55 000/an', en: 'USD 55 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL 100 / IELTS 7.0)',
          en: 'English (TOEFL 100 / IELTS 7.0)'),
      intakePeriods: ['Août', 'Janvier'],
      programIds: ['prog_us_priv001'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'scad',
      name: LocalizedText(
          fr: 'Savannah College of Art and Design (SCAD)',
          en: 'Savannah College of Art and Design (SCAD)'),
      countryId: 'usa',
      location: LocalizedText(
          fr: 'Savannah, GA / Atlanta / Lacoste',
          en: 'Savannah, GA / Atlanta / Lacoste'),
      overview: LocalizedText(
          fr: 'Référence mondiale pour les Arts, le Design, l\'Animation et la Mode. Équipements de pointe.',
          en: 'World reference for Arts, Design, Animation and Fashion. State-of-the-art equipment.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'USD 39 000/an', en: 'USD 39 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL 85 / IELTS 6.5)',
          en: 'English (TOEFL 85 / IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_us_priv002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'gwu',
      name: LocalizedText(
          fr: 'George Washington University',
          en: 'George Washington University'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Washington D.C.', en: 'Washington D.C.'),
      overview: LocalizedText(
          fr: 'Idéalement située au centre du pouvoir américain. Top pour les Relations Internationales, Politique et Droit.',
          en: 'Ideally located in the center of American power. Top for International Relations, Politics and Law.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'USD 60 000/an', en: 'USD 60 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 90)', en: 'English (TOEFL 90)'),
      intakePeriods: ['Août'],
      programIds: ['prog_us_priv003'],
      isPartner: false,
    ),
    // ── CANADA (Privées / Indépendantes supplémentaires) ────────────────────────
    InstitutionModel(
      id: 'twu',
      name: LocalizedText(
          fr: 'Trinity Western University', en: 'Trinity Western University'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Langley, BC', en: 'Langley, BC'),
      overview: LocalizedText(
          fr: 'La plus grande université chrétienne privée du Canada. Petites classes, forte attention à l\'étudiant.',
          en: 'The largest private Christian university in Canada. Small classes, strong student focus.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'CAD 22 000/an', en: 'CAD 22 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre', 'Janvier', 'Mai'],
      programIds: ['prog_ca_priv001'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'fdu_vancouver',
      name: LocalizedText(
          fr: 'Fairleigh Dickinson University - Vancouver',
          en: 'Fairleigh Dickinson University - Vancouver'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Vancouver, BC', en: 'Vancouver, BC'),
      overview: LocalizedText(
          fr: 'Campus canadien d\'une université américaine. Diplôme US et permis de travail post-diplôme canadien (PGWP).',
          en: 'Canadian campus of an American university. US degree and Canadian post-graduation work permit (PGWP).'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'CAD 25 000/an', en: 'CAD 25 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
      intakePeriods: ['Septembre', 'Janvier', 'Mai'],
      programIds: ['prog_ca_priv002'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'ucw',
      name: LocalizedText(
          fr: 'University Canada West (UCW)',
          en: 'University Canada West (UCW)'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Vancouver, BC', en: 'Vancouver, BC'),
      overview: LocalizedText(
          fr: 'Université privée focus Business et Tech. Très populaire pour son MBA accessible et son accompagnement.',
          en: 'Private university focused on Business and Tech. Very popular for its accessible MBA and support.'),
      studyLevels: ['Bac+3', 'MBA'],
      tuitionLabel: LocalizedText(
          fr: 'CAD 20 000–38 000/programme', en: 'CAD 20 000–38 000/program'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Octobre', 'Janvier', 'Avril', 'Juillet'],
      programIds: ['prog_ca_priv003'],
      isPartner: false,
    ),
    // ── FRANCE (Privées / Écoles supplémentaires non-OMNES/IGS) ───────────────
    InstitutionModel(
      id: 'skema',
      name: LocalizedText(
          fr: 'SKEMA Business School', en: 'SKEMA Business School'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Paris / Lille / Sophia Antipolis',
          en: 'Paris / Lille / Sophia Antipolis'),
      overview: LocalizedText(
          fr: 'Top 10 Business School française. Campuses mondiaux (USA, Chine, Brésil, Afrique du Sud).',
          en: 'Top 10 French Business School. Global campuses (USA, China, Brazil, South Africa).'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: '12 000–18 000 EUR/an', en: '12 000–18 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais / Français', en: 'English / French'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_fr_priv001', 'prog_skema_mim'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'edhec',
      name: LocalizedText(
          fr: 'EDHEC Business School', en: 'EDHEC Business School'),
      countryId: 'france',
      location:
          LocalizedText(fr: 'Lille / Nice / Paris', en: 'Lille / Nice / Paris'),
      overview: LocalizedText(
          fr: 'Excellence mondiale en Finance (Top 5 FT). Triple accréditation. Fort placement en banque.',
          en: 'Global excellence in Finance (Top 5 FT). Triple-accredited. Strong placement in investment banking.'),
      studyLevels: ['Bac+3', 'Bac+5', 'MBA'],
      tuitionLabel:
          LocalizedText(fr: '15 000–25 000 EUR/an', en: '15 000–25 000 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (GMAT souvent requis pour masters)',
          en: 'English (GMAT often req. for masters)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_priv002', 'prog_edhec_bba'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'epita',
      name: LocalizedText(fr: 'EPITA', en: 'EPITA'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Paris / Lyon / Toulouse', en: 'Paris / Lyon / Toulouse'),
      overview: LocalizedText(
          fr: 'École d\'ingénieurs en intelligence informatique. Cybersécurité, IA, développement. Très pragmatique.',
          en: 'Engineering school in computer intelligence. Cybersecurity, AI, development. Very pragmatic.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: '9 900 EUR/an', en: '9 900 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français (B2) / Anglais pour programmes inter',
          en: 'French (B2) / English for intl programs'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_priv003', 'prog_epita_cs'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'epitech_paris',
      name: LocalizedText(fr: "Epitech Paris", en: "Epitech Paris"),
      countryId: 'france',
      location: LocalizedText(fr: "Paris (Kremlin-Bicêtre)", en: "Paris (Kremlin-Bicêtre)"),
      overview: LocalizedText(
          fr: "L'école de l'expertise informatique et de l'innovation. Pédagogie active par projets, sans cours magistraux.",
          en: "The school of IT expertise and innovation. Active project-based learning, no lectures."),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: "8 500–10 900 EUR/an", en: "8,500–10,900 EUR/yr"),
      languageRequirements: LocalizedText(fr: "Français / Anglais", en: "French / English"),
      intakePeriods: ['Septembre', 'Mars'],
      programIds: ['prog_epitech_msc'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'rubika_val',
      name: LocalizedText(fr: "Rubika", en: "Rubika"),
      countryId: 'france',
      location: LocalizedText(fr: "Valenciennes / Montréal", en: "Valenciennes / Montreal"),
      overview: LocalizedText(
          fr: "École de référence mondiale pour le Jeu Vidéo, l'Animation 3D et le Design Industriel.",
          en: "World reference school for Video Games, 3D Animation, and Industrial Design."),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: "9 200–11 500 EUR/an", en: "9,200–11,500 EUR/yr"),
      languageRequirements: LocalizedText(fr: "Français (portfolio requis)", en: "French (portfolio required)"),
      intakePeriods: ['Septembre'],
      programIds: ['prog_rubika_master'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'isg_paris',
      name: LocalizedText(fr: "ISG International Business School", en: "ISG International Business School"),
      countryId: 'france',
      location: LocalizedText(fr: "Paris", en: "Paris"),
      overview: LocalizedText(
          fr: "Grande école de commerce internationale. Programmes Luxury Management, Sport Business et double diplômes.",
          en: "International business school. Programs in Luxury Management, Sport Business and double degrees."),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: "9 800–12 500 EUR/an", en: "9,800–12,500 EUR/yr"),
      languageRequirements: LocalizedText(fr: "Français / Anglais", en: "French / English"),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_isg_bba'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'em_lyon_casablanca',
      name: LocalizedText(
          fr: 'emlyon business school - Casablanca',
          en: 'emlyon business school - Casablanca'),
      countryId: 'morocco',
      location:
          LocalizedText(fr: 'Casablanca (Marina)', en: 'Casablanca (Marina)'),
      overview: LocalizedText(
          fr: 'Campus marocain de la prestigieuse école lyonnaise. Top Management, Entrepreneuriat et Innovation.',
          en: 'Moroccan campus of the prestigious Lyon business school. Top Management, Entrepreneurship and Innovation.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Global BBA'],
      tuitionLabel: LocalizedText(
          fr: 'MAD 85 000–110 000/an', en: 'MAD 85 000–110 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français / Anglais (B2+)', en: 'French / English (B2+)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma_priv_emlyon'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'esca_casablanca',
      name: LocalizedText(
          fr: 'ESCA Ecole de Management', en: 'ESCA School of Management'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Casablanca', en: 'Casablanca'),
      overview: LocalizedText(
          fr: 'N°1 en Afrique selon Eduniversal. Accréditée AACSB. Forte ouverture internationale.',
          en: 'N°1 in Africa by Eduniversal. AACSB accredited. Strong international focus.'),
      studyLevels: ['Bac+3', 'Bac+5', 'MBA'],
      tuitionLabel:
          LocalizedText(fr: 'MAD 65 000–85 000/an', en: 'MAD 65 000–85 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_ma_priv_esca'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'ege_rabat',
      name: LocalizedText(
          fr: 'EGE Rabat - École de Gouvernance et d\'Économie',
          en: 'EGE Rabat'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Rabat', en: 'Rabat'),
      overview: LocalizedText(
          fr: 'Pôle d\'excellence de l\'UM6P en sciences politiques et économie. Partenariats avec Sciences Po Paris.',
          en: 'UM6P excellence hub for political science and economics. Partnerships with Sciences Po Paris.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'MAD 70 000/an', en: 'MAD 70 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français / Anglais (C1)', en: 'French / English (C1)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma_priv_ege'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'upf_fes',
      name: LocalizedText(
          fr: 'Université Privée de Fès (UPF)',
          en: 'Private University of Fez'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Fès', en: 'Fez'),
      overview: LocalizedText(
          fr: 'Forte en Ingénierie, Architecture et Business. Reconnue par l\'État avec diplôme équivalent au public.',
          en: 'Strong in Engineering, Architecture and Business. State-recognized with equivalent diploma to public sector.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: 'MAD 40 000–55 000/an', en: 'MAD 40 000–55 000/yr'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma_priv_upf'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'bahcesehir',
      name: LocalizedText(
          fr: 'Bahçeşehir University (BAU)', en: 'Bahçeşehir University (BAU)'),
      countryId: 'turkey',
      location:
          LocalizedText(fr: 'Istanbul (Besiktas)', en: 'Istanbul (Besiktas)'),
      overview: LocalizedText(
          fr: '"Cœur d\'Istanbul". Très internationale, campuses mondiaux. N°1 en design et média en Turquie.',
          en: '"The Heart of Istanbul". Highly international, global campuses. N°1 in design and media in Turkey.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'USD 5 000–8 000/an', en: 'USD 5 000–8 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL 79) / Turc', en: 'English (TOEFL 79) / Turkish'),
      intakePeriods: ['Septembre', 'Février'],
      programIds: ['prog_tr_priv_bau'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'yeditepe',
      name: LocalizedText(fr: 'Yeditepe University', en: 'Yeditepe University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
      overview: LocalizedText(
          fr: 'L\'une des plus grandes universités privées. Campus vert. Excellence en médecine et dentisterie.',
          en: 'One of the largest private universities. Green campus. Excellence in medicine and dentistry.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'USD 4 000–25 000/an (Médecine)',
          en: 'USD 4 000–25 000/yr (Medicine)'),
      languageRequirements:
          LocalizedText(fr: 'Anglais / Turc', en: 'English / Turkish'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_tr_priv_yeditepe'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'osyegin',
      name: LocalizedText(fr: 'Özyeğin University', en: 'Ozyegin University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
      overview: LocalizedText(
          fr: 'Top Entrepreneurial University. Campus moderne. 100% Anglais. Gastronomie, Aviation et Business.',
          en: 'Top Entrepreneurial University. Modern campus. 100% English. Gastronomy, Aviation and Business.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: 'USD 6 000–12 000/an', en: 'USD 6 000–12 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_tr_priv_ozyegin'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'ucla',
      name: LocalizedText(
          fr: 'University of California, Los Angeles (UCLA)', en: 'UCLA'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Los Angeles, CA', en: 'Los Angeles, CA'),
      overview: LocalizedText(
          fr: 'L\'une des meilleures universités publiques au monde. Cinéma, Ingénierie, Psychologie et Business de haut niveau.',
          en: 'One of the best public universities worldwide. Top-tier Film, Engineering, Psychology and Business.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(
          fr: 'USD 42 000/an (non-résidents)',
          en: 'USD 42 000/yr (non-residents)'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (TOEFL 100+ / IELTS 7.0)',
          en: 'English (TOEFL 100+ / IELTS 7.0)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_us_ucla'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'penn_state',
      name: LocalizedText(
          fr: 'Pennsylvania State University (Penn State)', en: 'Penn State'),
      countryId: 'usa',
      location: LocalizedText(fr: 'State College, PA', en: 'State College, PA'),
      overview: LocalizedText(
          fr: 'Prestigieuse université publique de recherche. Très forte en Ingénierie pétrolière, Météorologie et Business.',
          en: 'Prestigious public research university. Very strong in Petroleum Engineering, Meteorology and Business.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'USD 35 000/an', en: 'USD 35 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 80)', en: 'English (TOEFL 80)'),
      intakePeriods: ['Août', 'Janvier'],
      programIds: ['prog_us_pennstate'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'spelman',
      name: LocalizedText(fr: 'Spelman College', en: 'Spelman College'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Atlanta, GA', en: 'Atlanta, GA'),
      overview: LocalizedText(
          fr: '#1 HBCU pour femmes. Excellence académique et leadership féminin noir aux USA.',
          en: '#1 HBCU for women. Academic excellence and black female leadership in the US.'),
      studyLevels: ['Bac+3'],
      tuitionLabel: LocalizedText(fr: 'USD 28 000/an', en: 'USD 28 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 80)', en: 'English (TOEFL 80)'),
      intakePeriods: ['Août'],
      programIds: ['prog_us_spelman'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'york_u',
      name: LocalizedText(fr: 'Université York', en: 'York University'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Toronto, Ontario', en: 'Toronto, Ontario'),
      overview: LocalizedText(
          fr: '3ème plus grande université du Canada. Schulich School of Business de renommée mondiale. Très diverse.',
          en: '3rd largest university in Canada. World-renowned Schulich School of Business. Very diverse.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'CAD 28 000–35 000/an', en: 'CAD 28 000–35 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre', 'Janvier', 'Mai'],
      programIds: ['prog_ca_york'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'moncton',
      name: LocalizedText(
          fr: 'Université de Moncton', en: 'Université de Moncton'),
      countryId: 'canada',
      location: LocalizedText(
          fr: 'Moncton, Nouveau-Brunswick', en: 'Moncton, New Brunswick'),
      overview: LocalizedText(
          fr: 'Plus grande université francophone hors Québec. Très abordable. Excellente pour les étudiants d\'Afrique de l\'Ouest.',
          en: 'Largest francophone university outside Quebec. Very affordable. Excellent for West African students.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: 'CAD 12 000–15 000/an', en: 'CAD 12 000–15 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_ca_moncton'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'dalhousie',
      name:
          LocalizedText(fr: 'Dalhousie University', en: 'Dalhousie University'),
      countryId: 'canada',
      location: LocalizedText(
          fr: 'Halifax, Nouvelle-Écosse', en: 'Halifax, Nova Scotia'),
      overview: LocalizedText(
          fr: 'Membre du U15 (recherche). Forte en Sciences de la mer, Médecine et Droit. Très bon accueil international.',
          en: 'Member of U15 (research). Strong in Ocean Sciences, Medicine and Law. Very welcoming to international students.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel:
          LocalizedText(fr: 'CAD 20 000–26 000/an', en: 'CAD 20 000–26 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_ca_dal'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'audencia',
      name: LocalizedText(
          fr: 'Audencia Business School', en: 'Audencia Business School'),
      countryId: 'france',
      location: LocalizedText(fr: 'Nantes / Paris', en: 'Nantes / Paris'),
      overview: LocalizedText(
          fr: 'Top 10 école de commerce en France. Triple accréditation (EQUIS, AACSB, AMBA). Forte sur la RSE et le Management.',
          en: 'Top 10 business schools in France. Triple accreditation (EQUIS, AACSB, AMBA). Focused on CSR and Management.'),
      studyLevels: ['Bachelor', 'Master', 'MBA'],
      tuitionLabel:
          LocalizedText(fr: '9 500–16 000 EUR/an', en: '9 500–16 000 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français / Anglais (B2+)', en: 'French / English (B2+)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_fr_audencia'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'neoma',
      name: LocalizedText(
          fr: 'NEOMA Business School', en: 'NEOMA Business School'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Reims / Rouen / Paris', en: 'Reims / Rouen / Paris'),
      overview: LocalizedText(
          fr: 'Grande École de commerce. Très forte en Finance, Marketing et Supply Chain. Campus digitaux innovants.',
          en: 'Leading Business School. Strong in Finance, Marketing and Supply Chain. Innovative digital campuses.'),
      studyLevels: ['Bachelor', 'Master', 'MS'],
      tuitionLabel:
          LocalizedText(fr: '10 000–15 000 EUR/an', en: '10 000–15 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_neoma'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'kedge',
      name: LocalizedText(
          fr: 'KEDGE Business School', en: 'KEDGE Business School'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Marseille / Bordeaux / Paris',
          en: 'Marseille / Bordeaux / Paris'),
      overview: LocalizedText(
          fr: 'Leader en Supply Chain et Design Culture. Fortement implantée à l\'international (Sénégal, Chine).',
          en: 'Leader in Supply Chain and Culture Design. Strong international presence (Senegal, China).'),
      studyLevels: ['Bachelor', 'MSc', 'EBP'],
      tuitionLabel:
          LocalizedText(fr: '9 000–14 000 EUR/an', en: '9 000–14 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_fr_kedge'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'mundiapolis',
      name: LocalizedText(
          fr: 'Université Mundiapolis', en: 'Mundiapolis University'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Casablanca', en: 'Casablanca'),
      overview: LocalizedText(
          fr: 'Pionnière de l\'enseignement privé au Maroc. Multidisciplinaire : Santé, Ingénierie, Business et Droit.',
          en: 'Pioneer of private education in Morocco. Multidisciplinary: Health, Engineering, Business and Law.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel:
          LocalizedText(fr: 'MAD 55 000–75 000/an', en: 'MAD 55 000–75 000/yr'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma_priv_mundia'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'upm_marrakech',
      name: LocalizedText(
          fr: 'Université Privée de Marrakech (UPM)',
          en: 'Private University of Marrakech'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Marrakech', en: 'Marrakech'),
      overview: LocalizedText(
          fr: 'Campus d\'excellence en Afrique du Nord. Pôle hôtellerie, sport, santé et digital de premier plan.',
          en: 'Excellence campus in North Africa. Leading hub for hospitality, sports, health and digital studies.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Exécutif'],
      tuitionLabel:
          LocalizedText(fr: 'MAD 45 000–65 000/an', en: 'MAD 45 000–65 000/yr'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_ma_priv_upm'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'asu',
      name: LocalizedText(
          fr: 'Arizona State University (ASU)', en: 'Arizona State University'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Tempe, AZ', en: 'Tempe, AZ'),
      overview: LocalizedText(
          fr: 'Élue #1 pour l\'innovation aux USA. Très forte en Tech, Business et Design durable.',
          en: '#1 for innovation in the US. Strong in Tech, Business and Sustainable Design.'),
      studyLevels: ['Bac+3', 'Bac+5', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'USD 30 000/an', en: 'USD 30 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 80)', en: 'English (TOEFL 80)'),
      intakePeriods: ['Août', 'Janvier'],
      programIds: ['prog_us_asu'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'ohio_state',
      name: LocalizedText(
          fr: 'Ohio State University', en: 'Ohio State University'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Columbus, OH', en: 'Columbus, OH'),
      overview: LocalizedText(
          fr: 'L\'une des plus grandes universités des USA. Excellence en Médecine, Ingénierie et Sport.',
          en: 'One of the largest universities in the US. Excellence in Medicine, Engineering and Athletics.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'USD 33 000/an', en: 'USD 33 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 79)', en: 'English (TOEFL 79)'),
      intakePeriods: ['Août'],
      programIds: ['prog_us_osu'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'msu',
      name: LocalizedText(
          fr: 'Michigan State University', en: 'Michigan State University'),
      countryId: 'usa',
      location: LocalizedText(fr: 'East Lansing, MI', en: 'East Lansing, MI'),
      overview: LocalizedText(
          fr: 'Pionnière de la recherche agronomique. Très forte en Communication et Sciences sociales.',
          en: 'Pioneer in agricultural research. Strong in Communications and Social Sciences.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'USD 40 000/an', en: 'USD 40 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Août', 'Janvier'],
      programIds: ['prog_us_msu'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'bc_poly',
      name: LocalizedText(
          fr: 'British Columbia Institute of Technology (BCIT)',
          en: 'British Columbia Institute of Technology'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Burnaby, BC', en: 'Burnaby, BC'),
      overview: LocalizedText(
          fr: 'Focus sur l\'employabilité immédiate. Très forte en Informatique et Génie civil.',
          en: 'Focus on immediate employability. Strong in Computer Science and Civil Engineering.'),
      studyLevels: ['Diploma', 'Bac+3'],
      tuitionLabel: LocalizedText(fr: 'CAD 18 000/an', en: 'CAD 18 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_ca_bcit'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'seneca',
      name: LocalizedText(fr: 'Seneca Polytechnic', en: 'Seneca Polytechnic'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Toronto, Ontario', en: 'Toronto, Ontario'),
      overview: LocalizedText(
          fr: 'Leader canadien de l\'enseignement polytechnique. Plus de 190 programmes innovants.',
          en: 'Canadian leader in polytechnic education. Over 190 innovative programs.'),
      studyLevels: ['Diploma', 'Bac+3'],
      tuitionLabel: LocalizedText(fr: 'CAD 16 000/an', en: 'CAD 16 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.0)', en: 'English (IELTS 6.0)'),
      intakePeriods: ['Septembre', 'Janvier', 'Mai'],
      programIds: ['prog_ca_seneca'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'skema_bus',
      name: LocalizedText(
          fr: 'SKEMA Business School', en: 'SKEMA Business School'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Lille / Sophia Antipolis / Paris',
          en: 'Lille / Sophia Antipolis / Paris'),
      overview: LocalizedText(
          fr: 'École de commerce globale. Présente sur 5 continents. Très forte en Finance de marché.',
          en: 'Global business school. Present on 5 continents. Very strong in Market Finance.'),
      studyLevels: ['BBA', 'Master', 'PhD'],
      tuitionLabel:
          LocalizedText(fr: '12 000–18 000 EUR/an', en: '12 000–18 000 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français / Anglais (B2+)', en: 'French / English (B2+)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_skema'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'ieseg',
      name: LocalizedText(
          fr: 'IÉSEG School of Management', en: 'IÉSEG School of Management'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Lille / Paris-La Défense', en: 'Lille / Paris-La Défense'),
      overview: LocalizedText(
          fr: 'Top 10 business schools. 100% des programmes sont en anglais. Très internationale.',
          en: 'Top 10 business schools. 100% of programs are in English. Highly international.'),
      studyLevels: ['Bachelor', 'Master'],
      tuitionLabel:
          LocalizedText(fr: '11 000–15 000 EUR/an', en: '11 000–15 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_it_ieseg'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'esc_clermont',
      name: LocalizedText(
          fr: 'Groupe ESC Clermont', en: 'ESC Clermont Business School'),
      countryId: 'france',
      location: LocalizedText(fr: 'Clermont-Ferrand', en: 'Clermont-Ferrand'),
      overview: LocalizedText(
          fr: 'École historique accréditée AACSB. Accompagnement très personnalisé des étudiants internationaux.',
          en: 'Historic AACSB accredited school. Highly personalized support for international students.'),
      studyLevels: ['Bachelor', 'PGE', 'MSc'],
      tuitionLabel:
          LocalizedText(fr: '8 500–12 000 EUR/an', en: '8 500–12 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_fr_clermont'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'montpellier_bs',
      name: LocalizedText(
          fr: 'Montpellier Business School (MBS)',
          en: 'Montpellier Business School'),
      countryId: 'france',
      location: LocalizedText(fr: 'Montpellier', en: 'Montpellier'),
      overview: LocalizedText(
          fr: 'École engagée sur l\'inclusion et la diversité. Très forte en Entrepreneuriat.',
          en: 'School committed to inclusion and diversity. Very strong in Entrepreneurship.'),
      studyLevels: ['Bachelor', 'Master', 'PhD'],
      tuitionLabel:
          LocalizedText(fr: '10 000–14 000 EUR/an', en: '10 000–14 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_mbs'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'edhec',
      name: LocalizedText(
          fr: 'EDHEC Business School', en: 'EDHEC Business School'),
      countryId: 'france',
      location:
          LocalizedText(fr: 'Lille / Nice / Paris', en: 'Lille / Nice / Paris'),
      overview: LocalizedText(
          fr: 'Leader mondial en Finance. "Non sibi sed omnibus". Top 5 école de commerce en France.',
          en: 'World leader in Finance. "Not for self but for all". Top 5 business schools in France.'),
      studyLevels: ['Bachelor', 'MSc', 'Global MBA'],
      tuitionLabel:
          LocalizedText(fr: '15 000–25 000 EUR/an', en: '15 000–25 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (C1)', en: 'English (C1)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_edhec'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'icn_bus',
      name: LocalizedText(fr: 'ICN Business School', en: 'ICN Business School'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Nancy / Paris / Berlin', en: 'Nancy / Paris / Berlin'),
      overview: LocalizedText(
          fr: 'Membre de la Conférence des Grandes Écoles. Pédagogie Artem (Art, Tech, Management).',
          en: 'Member of CGE. Artem pedagogy (Art, Tech, Management).'),
      studyLevels: ['Bachelor', 'PGE', 'MSc'],
      tuitionLabel:
          LocalizedText(fr: '9 000–12 000 EUR/an', en: '9 000–12 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_icn'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'koc_uni',
      name: LocalizedText(fr: 'Koç University', en: 'Koç University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
      overview: LocalizedText(
          fr: 'Université de recherche d\'élite. Partenariats mondiaux. Très sélective. Campus exceptionnel.',
          en: 'Elite research university. Global partnerships. Highly selective. Exceptional campus.'),
      studyLevels: ['Bac+3', 'Bac+5', 'PhD'],
      tuitionLabel:
          LocalizedText(fr: 'USD 19 000–25 000/an', en: 'USD 19 000–25 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 80+)', en: 'English (TOEFL 80+)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_tr_koc'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'bilkent',
      name: LocalizedText(fr: 'Bilkent University', en: 'Bilkent University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Ankara', en: 'Ankara'),
      overview: LocalizedText(
          fr: 'Première université privée de Turquie. Excellence en Ingénierie, Management et Humanités.',
          en: 'Turkey\'s first private university. Excellence in Engineering, Management and Humanities.'),
      studyLevels: ['Bac+3', 'Bac+5', 'PhD'],
      tuitionLabel:
          LocalizedText(fr: 'USD 12 000–15 000/an', en: 'USD 12 000–15 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais (Bilkent PAE)', en: 'English (Bilkent PAE)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_tr_bilkent'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'em_normandie',
      name: LocalizedText(
          fr: 'EM Normandie Business School',
          en: 'EM Normandie Business School'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'Caen / Le Havre / Paris', en: 'Caen / Le Havre / Paris'),
      overview: LocalizedText(
          fr: 'École de commerce triplement accréditée. Forte sur la logistique portuaire et le digital.',
          en: 'Triple accredited business school. Strong in port logistics and digital business.'),
      studyLevels: ['Bachelor', 'PGE', 'MSc'],
      tuitionLabel:
          LocalizedText(fr: '8 500–13 000 EUR/an', en: '8 500–13 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_fr_emnorm'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'bsb_dijon',
      name: LocalizedText(
          fr: 'BSB - Burgundy School of Business',
          en: 'BSB - Burgundy School of Business'),
      countryId: 'france',
      location: LocalizedText(fr: 'Dijon / Lyon', en: 'Dijon / Lyon'),
      overview: LocalizedText(
          fr: 'Top 15 école de management. Leader mondial dans le management du Vin et Spiritueux (School of Wine).',
          en: 'Top 15 management school. World leader in Wine & Spirits Management (School of Wine).'),
      studyLevels: ['Bachelor', 'Master', 'MS'],
      tuitionLabel:
          LocalizedText(fr: '9 000–15 000 EUR/an', en: '9 000–15 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_bsb'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'excelia',
      name: LocalizedText(
          fr: 'Excelia Business School', en: 'Excelia Business School'),
      countryId: 'france',
      location: LocalizedText(
          fr: 'La Rochelle / Tours / Orléans',
          en: 'La Rochelle / Tours / Orleans'),
      overview: LocalizedText(
          fr: 'École engagée dans le développement durable. Spécialisée en Tourisme, Transport et Business.',
          en: 'School committed to sustainable development. Specialized in Tourism, Transport and Business.'),
      studyLevels: ['Bachelor', 'Master', 'MSc'],
      tuitionLabel:
          LocalizedText(fr: '8 000–13 000 EUR/an', en: '8 000–13 000 EUR/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_fr_excelia'],
      isPartner: true,
    ),
    // Final Batch to reach 200+
    InstitutionModel(
      id: 'scpo_paris',
      name: LocalizedText(fr: 'Sciences Po Paris', en: 'Sciences Po Paris'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(
          fr: 'Université de recherche internationale en sciences humaines et sociales. Très prestigieuse.',
          en: 'International research university in the humanities and social sciences. Highly prestigious.'),
      studyLevels: ['Bachelor', 'Master', 'PhD'],
      tuitionLabel: LocalizedText(fr: '0–14 000 EUR/an', en: '0–14 000 EUR/yr'),
      languageRequirements: LocalizedText(
          fr: 'Français (C1) / Anglais (C1)', en: 'French (C1) / English (C1)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_scpo'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'dauphine',
      name: LocalizedText(
          fr: 'Université Paris-Dauphine', en: 'Paris-Dauphine University'),
      countryId: 'france',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(
          fr: 'Spécialisée en organisation et décision. Forte en Finance, Économie et Droit.',
          en: 'Specialized in organizational and decision-making sciences. Strong in Finance, Economics, and Law.'),
      studyLevels: ['L3', 'Master', 'PhD'],
      tuitionLabel: LocalizedText(fr: 'Public (Euros)', en: 'Public (Euros)'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2+)', en: 'French (B2+)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_fr_dauphine'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'temple_u',
      name: LocalizedText(fr: 'Temple University', en: 'Temple University'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Philadelphia, PA', en: 'Philadelphia, PA'),
      overview: LocalizedText(
          fr: 'Grande université publique. Très forte en Communication et Médias.',
          en: 'Large public university. Very strong in Media and Communications.'),
      studyLevels: ['Bachelor', 'Master'],
      tuitionLabel: LocalizedText(fr: 'USD 30 000/an', en: 'USD 30 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 79)', en: 'English (TOEFL 79)'),
      intakePeriods: ['Août'],
      programIds: ['prog_us_temple'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'pitt_u',
      name: LocalizedText(
          fr: 'University of Pittsburgh', en: 'University of Pittsburgh'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Pittsburgh, PA', en: 'Pittsburgh, PA'),
      overview: LocalizedText(
          fr: 'Recherche médicale de pointe. Très forte en Pharmacie et Ingénierie.',
          en: 'Leading medical research. Very strong in Pharmacy and Engineering.'),
      studyLevels: ['Bachelor', 'Master'],
      tuitionLabel: LocalizedText(fr: 'USD 34 000/an', en: 'USD 34 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 80)', en: 'English (TOEFL 80)'),
      intakePeriods: ['Août'],
      programIds: ['prog_us_pitt'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'buffalo_u',
      name: LocalizedText(
          fr: 'University at Buffalo (SUNY)', en: 'University at Buffalo'),
      countryId: 'usa',
      location: LocalizedText(fr: 'Buffalo, NY', en: 'Buffalo, NY'),
      overview: LocalizedText(
          fr: 'Top public university in New York state. Strong Architecture and Engineering.',
          en: 'Top public university in New York state. Strong Architecture and Engineering.'),
      studyLevels: ['Bachelor', 'Master'],
      tuitionLabel: LocalizedText(fr: 'USD 28 000/an', en: 'USD 28 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (TOEFL 70)', en: 'English (TOEFL 70)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_us_buffalo'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'queens_u',
      name: LocalizedText(fr: 'Queen\'s University', en: 'Queen\'s University'),
      countryId: 'canada',
      location: LocalizedText(fr: 'Kingston, Ontario', en: 'Kingston, Ontario'),
      overview: LocalizedText(
          fr: 'Haut niveau académique. Très forte en Business et Santé.',
          en: 'High academic standard. Very strong in Business and Health.'),
      studyLevels: ['Bachelor', 'Master'],
      tuitionLabel: LocalizedText(fr: 'CAD 35 000/an', en: 'CAD 35 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 7.0)', en: 'English (IELTS 7.0)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ca_queens'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'western_u',
      name: LocalizedText(fr: 'Western University', en: 'Western University'),
      countryId: 'canada',
      location: LocalizedText(fr: 'London, Ontario', en: 'London, Ontario'),
      overview: LocalizedText(
          fr: 'Ivey Business School de renommée mondiale. Campus magnifique.',
          en: 'Home to the world-renowned Ivey Business School. Beautiful campus.'),
      studyLevels: ['Bachelor', 'Master'],
      tuitionLabel: LocalizedText(fr: 'CAD 32 000/an', en: 'CAD 32 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Anglais (IELTS 6.5)', en: 'English (IELTS 6.5)'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ca_western'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'sherbrooke',
      name: LocalizedText(
          fr: 'Université de Sherbrooke', en: 'University of Sherbrooke'),
      countryId: 'canada',
      location:
          LocalizedText(fr: 'Sherbrooke, Québec', en: 'Sherbrooke, Quebec'),
      overview: LocalizedText(
          fr: 'Pionnière de l\'apprentissage expérientiel. Très forte en Génie.',
          en: 'Pioneer of experiential learning. Very strong in Engineering.'),
      studyLevels: ['Bac', 'Master'],
      tuitionLabel: LocalizedText(fr: 'CAD 18 000/an', en: 'CAD 18 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2)', en: 'French (B2)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_ca_sherb'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'u_laval',
      name: LocalizedText(fr: 'Université Laval', en: 'Laval University'),
      countryId: 'canada',
      location:
          LocalizedText(fr: 'Québec City, Québec', en: 'Quebec City, Quebec'),
      overview: LocalizedText(
          fr: 'Première université francophone d\'Amérique. Excellence dans tous les domaines.',
          en: 'First francophone university in America. Excellence in all fields.'),
      studyLevels: ['Bac', 'Master', 'Doctorat'],
      tuitionLabel: LocalizedText(fr: 'CAD 20 000/an', en: 'CAD 20 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français (B2+)', en: 'French (B2+)'),
      intakePeriods: ['Septembre', 'Janvier'],
      programIds: ['prog_ca_laval'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'esith_casablanca',
      name: LocalizedText(fr: 'ESITH Casablanca', en: 'ESITH Casablanca'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Casablanca', en: 'Casablanca'),
      overview: LocalizedText(
          fr: 'École supérieure des industries du textile et de l\'habillement. Très forte insertion.',
          en: 'Higher school of textile and clothing industries. Very high job placement rate.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'MAD 35 000/an', en: 'MAD 35 000/yr'),
      languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma_priv_esith'],
      isPartner: false,
    ),
    InstitutionModel(
      id: 'uaem_casablanca',
      name: LocalizedText(
          fr: 'Université Aéronautique et de Management',
          en: 'Aerospace & Management University'),
      countryId: 'morocco',
      location: LocalizedText(fr: 'Casablanca', en: 'Casablanca'),
      overview: LocalizedText(
          fr: 'Spécialisée en aéronautique et management industriel.',
          en: 'Specialized in aerospace and industrial management.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'MAD 60 000/an', en: 'MAD 60 000/yr'),
      languageRequirements:
          LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_ma_priv_uaem'],
      isPartner: true,
    ),
    InstitutionModel(
      id: 'izu_turkey',
      name: LocalizedText(
          fr: 'Istanbul Sabahattin Zaim University (IZU)',
          en: 'Istanbul Sabahattin Zaim University'),
      countryId: 'turkey',
      location: LocalizedText(fr: 'Istanbul', en: 'Istanbul'),
      overview: LocalizedText(
          fr: 'Université thématique forte en finance islamique et sciences sociales.',
          en: 'Thematic university strong in Islamic finance and social sciences.'),
      studyLevels: ['Bac+3', 'Bac+5'],
      tuitionLabel: LocalizedText(fr: 'USD 3 000/an', en: 'USD 3 000/yr'),
      languageRequirements: LocalizedText(
          fr: 'Anglais / Turc / Arabe', en: 'English / Turkish / Arabic'),
      intakePeriods: ['Septembre'],
      programIds: ['prog_tr_priv_izu'],
      isPartner: true,
    ),
    // Final Batch to 200
    InstitutionModel(
        id: 'centrale_casablanca',
        name:
            LocalizedText(fr: 'Centrale Casablanca', en: 'Centrale Casablanca'),
        countryId: 'morocco',
        location: LocalizedText(fr: 'Bouskoura', en: 'Bouskoura'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs généraliste d\'élite. Modèle français.',
            en: 'Elite generalist engineering school. French model.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: 'MAD 100 000/an', en: 'MAD 100 000/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français (C1)', en: 'French (C1)'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_ma_priv_centrale'],
        isPartner: false),
    InstitutionModel(
        id: 'uir_rabat',
        name: LocalizedText(
            fr: 'Université Internationale de Rabat (UIR)',
            en: 'International University of Rabat'),
        countryId: 'morocco',
        location: LocalizedText(fr: 'Rabat', en: 'Rabat'),
        overview: LocalizedText(
            fr: 'Première université en partenariat public-privé. Très haute qualité.',
            en: 'First public-private partnership university. Very high quality.'),
        studyLevels: ['Bac+3', 'Bac+5'],
        tuitionLabel: LocalizedText(fr: 'MAD 72 000/an', en: 'MAD 72 000/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_ma_priv_uir'],
        isPartner: true),
    InstitutionModel(
        id: 'mundi_casa',
        name: LocalizedText(
            fr: 'Université Mundiapolis', en: 'Mundiapolis University'),
        countryId: 'morocco',
        location: LocalizedText(fr: 'Casablanca', en: 'Casablanca'),
        overview: LocalizedText(
            fr: 'Pionnière de l\'enseignement privé. Multidisciplinaire.',
            en: 'Pioneer of private education. Multidisciplinary.'),
        studyLevels: ['Bac+3', 'Bac+5'],
        tuitionLabel: LocalizedText(fr: 'MAD 60 000/an', en: 'MAD 60 000/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_ma_priv_mundia'],
        isPartner: true),
    InstitutionModel(
        id: 'upm_marra',
        name: LocalizedText(
            fr: 'Université Privée de Marrakech',
            en: 'Private University of Marrakech'),
        countryId: 'morocco',
        location: LocalizedText(fr: 'Marrakech', en: 'Marrakech'),
        overview: LocalizedText(
            fr: 'Campus d\'excellence multidisciplinaire.',
            en: 'Multidisciplinary campus of excellence.'),
        studyLevels: ['Bac+3', 'Bac+5'],
        tuitionLabel: LocalizedText(fr: 'MAD 50 000/an', en: 'MAD 50 000/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_ma_priv_upm'],
        isPartner: true),
    InstitutionModel(
        id: 'escp_paris',
        name: LocalizedText(
            fr: 'ESCP Business School', en: 'ESCP Business School'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris', en: 'Paris'),
        overview: LocalizedText(
            fr: 'La plus ancienne école de commerce au monde. Multi-campus.',
            en: 'The world\'s first business school. Multi-campus.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '18 000 EUR/an', en: '18 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_escp', 'prog_escp_mim'],
        isPartner: true),
    InstitutionModel(
        id: 'em_lyon',
        name: LocalizedText(
            fr: 'emlyon business school', en: 'emlyon business school'),
        countryId: 'france',
        location: LocalizedText(fr: 'Lyon', en: 'Lyon'),
        overview: LocalizedText(
            fr:
                'École de management prestigieuse. Focus sur l\'entrepreneuriat.',
            en: 'Prestigious management school. Focus on entrepreneurship.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '16 000 EUR/an', en: '16 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_emlyon', 'prog_s008'],
        isPartner: true),
    InstitutionModel(
        id: 'edhec_bus',
        name: LocalizedText(
            fr: 'EDHEC Business School', en: 'EDHEC Business School'),
        countryId: 'france',
        location: LocalizedText(fr: 'Lille', en: 'Lille'),
        overview: LocalizedText(
            fr: 'Top 5 école de commerce. Leader en Finance.',
            en: 'Top 5 business school. Leader in Finance.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '15 000 EUR/an', en: '15 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_edhec', 'prog_edhec_bba'],
        isPartner: true),
    InstitutionModel(
        id: 'audencia_bus',
        name: LocalizedText(fr: 'Audencia', en: 'Audencia'),
        countryId: 'france',
        location: LocalizedText(fr: 'Nantes', en: 'Nantes'),
        overview: LocalizedText(
            fr: 'Top école de commerce. Forte sur la RSE.',
            en: 'Top business school. Strong on CSR.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '14 000 EUR/an', en: '14 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_audencia'],
        isPartner: true),
    InstitutionModel(
        id: 'neoma_bus',
        name: LocalizedText(fr: 'NEOMA', en: 'NEOMA'),
        countryId: 'france',
        location: LocalizedText(fr: 'Reims', en: 'Reims'),
        overview: LocalizedText(
            fr: 'Top 10 école de commerce.', en: 'Top 10 business school.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '13 500 EUR/an', en: '13 500 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_neoma'],
        isPartner: true),
    InstitutionModel(
        id: 'kedge_bus',
        name: LocalizedText(fr: 'KEDGE', en: 'KEDGE'),
        countryId: 'france',
        location: LocalizedText(fr: 'Marseille', en: 'Marseille'),
        overview: LocalizedText(
            fr: 'Leader en Supply Chain.', en: 'Leader in Supply Chain.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '12 000 EUR/an', en: '12 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_kedge'],
        isPartner: true),
    InstitutionModel(
        id: 'skema_bs',
        name: LocalizedText(fr: 'SKEMA', en: 'SKEMA'),
        countryId: 'france',
        location: LocalizedText(fr: 'Lille', en: 'Lille'),
        overview: LocalizedText(
            fr: 'Global business school.', en: 'Global business school.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '14 500 EUR/an', en: '14 500 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_skema'],
        isPartner: true),
    InstitutionModel(
        id: 'ieseg_bs',
        name: LocalizedText(fr: 'IÉSEG', en: 'IÉSEG'),
        countryId: 'france',
        location: LocalizedText(fr: 'Lille', en: 'Lille'),
        overview: LocalizedText(
            fr: 'Top business school. 100% Anglais.',
            en: 'Top business school. 100% English.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '13 000 EUR/an', en: '13 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_ieseg'],
        isPartner: false),
    InstitutionModel(
        id: 'esc_clermont_bs',
        name: LocalizedText(fr: 'ESC Clermont', en: 'ESC Clermont'),
        countryId: 'france',
        location: LocalizedText(fr: 'Clermont', en: 'Clermont'),
        overview: LocalizedText(
            fr: 'École de management humaine.',
            en: 'Human-sized management school.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '9 000 EUR/an', en: '9 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_esc_clermont'],
        isPartner: true),
    InstitutionModel(
        id: 'mbs_france',
        name: LocalizedText(fr: 'Montpellier BS', en: 'Montpellier BS'),
        countryId: 'france',
        location: LocalizedText(fr: 'Montpellier', en: 'Montpellier'),
        overview: LocalizedText(
            fr: 'Engagée sur la diversité.', en: 'Committed to diversity.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '12 500 EUR/an', en: '12 500 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_mbs'],
        isPartner: false),
    InstitutionModel(
        id: 'icn_france',
        name:
            LocalizedText(fr: 'ICN Business School', en: 'ICN Business School'),
        countryId: 'france',
        location: LocalizedText(fr: 'Nancy', en: 'Nancy'),
        overview: LocalizedText(
            fr: 'Pédagogie innovante Art/Tech.',
            en: 'Innovative Art/Tech pedagogy.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '10 500 EUR/an', en: '10 500 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_icn'],
        isPartner: true),
    InstitutionModel(
        id: 'rennes_sb',
        name: LocalizedText(
            fr: 'Rennes School of Business', en: 'Rennes School of Business'),
        countryId: 'france',
        location: LocalizedText(fr: 'Rennes', en: 'Rennes'),
        overview: LocalizedText(
            fr: 'L\'école la plus internationale de France.',
            en: 'The most international school in France.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '11 500 EUR/an', en: '11 500 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_rennes'],
        isPartner: true),
    InstitutionModel(
        id: 'tbs_education',
        name: LocalizedText(fr: 'TBS Education', en: 'TBS Education'),
        countryId: 'france',
        location: LocalizedText(fr: 'Toulouse', en: 'Toulouse'),
        overview: LocalizedText(
            fr: 'Top école de commerce. Forte en Marketing.',
            en: 'Top business school. Strong in Marketing.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '12 000 EUR/an', en: '12 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_tbs'],
        isPartner: true),
    InstitutionModel(
        id: 'em_strasbourg',
        name: LocalizedText(fr: 'EM Strasbourg', en: 'EM Strasbourg'),
        countryId: 'france',
        location: LocalizedText(fr: 'Strasbourg', en: 'Strasbourg'),
        overview: LocalizedText(
            fr: 'École de management au cœur de l\'université.',
            en: 'Management school at the heart of the university.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel:
            LocalizedText(fr: 'Public / Privé', en: 'Public / Private'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_stras'],
        isPartner: false),
    InstitutionModel(
        id: 'psb_paris',
        name: LocalizedText(
            fr: 'Paris School of Business', en: 'Paris School of Business'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris', en: 'Paris'),
        overview: LocalizedText(
            fr: 'École de commerce cosmopolite.',
            en: 'Cosmopolitan business school.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '10 000 EUR/an', en: '10 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_psb'],
        isPartner: true),
    InstitutionModel(
        id: 'isc_paris',
        name: LocalizedText(fr: 'ISC Paris', en: 'ISC Paris'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris', en: 'Paris'),
        overview: LocalizedText(
            fr: 'Focus sur l\'action et les associations.',
            en: 'Focus on action and student clubs.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '9 500 EUR/an', en: '9 500 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_isc'],
        isPartner: false),
    InstitutionModel(
        id: 'isg_paris',
        name: LocalizedText(fr: 'ISG Paris', en: 'ISG Paris'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris', en: 'Paris'),
        overview: LocalizedText(
            fr: 'Portée internationale et business.',
            en: 'International scope and business.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '10 000 EUR/an', en: '10 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_isg'],
        isPartner: false),
    InstitutionModel(
        id: 'esce_paris',
        name:
            LocalizedText(fr: 'ESCE International Business School', en: 'ESCE'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris', en: 'Paris'),
        overview: LocalizedText(
            fr: 'Spécialisée en commerce international.',
            en: 'Specialized in international business.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '11 000 EUR/an', en: '11 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_esce'],
        isPartner: true),
    InstitutionModel(
        id: 'ebs_paris',
        name: LocalizedText(fr: 'European Business School', en: 'EBS Paris'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris', en: 'Paris'),
        overview: LocalizedText(
            fr: 'École de management internationale.',
            en: 'International management school.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '10 500 EUR/an', en: '10 500 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_ebs'],
        isPartner: false),
    InstitutionModel(
        id: 'inseec_grande_ecole',
        name: LocalizedText(fr: 'INSEEC Grande Ecole', en: 'INSEEC'),
        countryId: 'france',
        location: LocalizedText(fr: 'Bordeaux / Paris', en: 'Bordeaux / Paris'),
        overview: LocalizedText(
            fr: 'Grande école de commerce multidisciplinaire.',
            en: 'Multidisciplinary business school.'),
        studyLevels: ['Master'],
        tuitionLabel: LocalizedText(fr: '11 000 EUR/an', en: '11 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_inseec'],
        isPartner: true),
    InstitutionModel(
        id: 'estaca',
        name: LocalizedText(fr: 'ESTACA', en: 'ESTACA'),
        countryId: 'france',
        location: LocalizedText(fr: 'Saint-Quentin / Laval', en: 'SQ / Laval'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs transports (Auto, Aero, Rail).',
            en: 'Engineering school for transport (Auto, Aero, Rail).'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '8 500 EUR/an', en: '8 500 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_estaca'],
        isPartner: false),
    InstitutionModel(
        id: 'esme_sudria',
        name: LocalizedText(fr: 'ESME Sudria', en: 'ESME Sudria'),
        countryId: 'france',
        location: LocalizedText(
            fr: 'Paris / Lyon / Lille', en: 'Paris / Lyon / Lille'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs généraliste.',
            en: 'Generalist engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '9 000 EUR/an', en: '9 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_esme'],
        isPartner: true),
    InstitutionModel(
        id: 'epita_it',
        name: LocalizedText(fr: 'EPITA', en: 'EPITA'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris', en: 'Paris'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs en informatique.',
            en: 'IT engineering school.'),
        studyLevels: ['Bac+3', 'Bac+5'],
        tuitionLabel: LocalizedText(fr: '10 000 EUR/an', en: '10 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_epita'],
        isPartner: true),
    InstitutionModel(
        id: 'ipsa_aero',
        name: LocalizedText(fr: 'IPSA', en: 'IPSA'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris / Toulouse', en: 'Paris / Toulouse'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs aéronautique et spatiale.',
            en: 'Aeronautics and space engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '9 500 EUR/an', en: '9 500 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_ipsa'],
        isPartner: true),
    InstitutionModel(
        id: 'ece_paris',
        name: LocalizedText(fr: 'ECE Paris', en: 'ECE Paris'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris / Lyon', en: 'Paris / Lyon'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs du numérique.',
            en: 'Digital engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '10 000 EUR/an', en: '10 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_ece'],
        isPartner: true),
    InstitutionModel(
        id: 'efi_it',
        name: LocalizedText(fr: 'EFREI Paris', en: 'EFREI Paris'),
        countryId: 'france',
        location: LocalizedText(fr: 'Villejuif', en: 'Villejuif'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs généraliste du numérique.',
            en: 'Generalist digital engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '9 800 EUR/an', en: '9 800 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_efrei'],
        isPartner: true),
    InstitutionModel(
        id: 'esiea_it',
        name: LocalizedText(fr: 'ESIEA', en: 'ESIEA'),
        countryId: 'france',
        location: LocalizedText(
            fr: 'Paris / Ivry / Laval', en: 'Paris / Ivry / Laval'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs en informatique et systèmes.',
            en: 'IT and systems engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '9 200 EUR/an', en: '9 200 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_esiea'],
        isPartner: false),
    InstitutionModel(
        id: 'eisti_it',
        name: LocalizedText(fr: 'CY Tech (ex-EISTI)', en: 'CY Tech'),
        countryId: 'france',
        location: LocalizedText(fr: 'Cergy / Pau', en: 'Cergy / Pau'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs math-info.',
            en: 'Math-IT engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: 'Privé', en: 'Private'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_cytech'],
        isPartner: false),
    InstitutionModel(
        id: 'hei_lille',
        name: LocalizedText(fr: 'HEI Lille (Junia)', en: 'HEI Lille'),
        countryId: 'france',
        location: LocalizedText(fr: 'Lille', en: 'Lille'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs généraliste catholique.',
            en: 'Generalist catholic engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '8 000 EUR/an', en: '8 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_hei'],
        isPartner: true),
    InstitutionModel(
        id: 'isen_lille',
        name: LocalizedText(fr: 'ISEN Lille (Junia)', en: 'ISEN Lille'),
        countryId: 'france',
        location: LocalizedText(fr: 'Lille', en: 'Lille'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs de l\'électronique et du numérique.',
            en: 'Electronics and digital engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '8 000 EUR/an', en: '8 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_isen'],
        isPartner: true),
    InstitutionModel(
        id: 'isa_lille',
        name: LocalizedText(fr: 'ISA Lille (Junia)', en: 'ISA Lille'),
        countryId: 'france',
        location: LocalizedText(fr: 'Lille', en: 'Lille'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs pour l\'agriculture et l\'agroalimentaire.',
            en: 'Agriculture and food engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '7 500 EUR/an', en: '7 500 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_isa'],
        isPartner: true),
    InstitutionModel(
        id: 'eseo_angers',
        name: LocalizedText(fr: 'ESEO', en: 'ESEO'),
        countryId: 'france',
        location: LocalizedText(
            fr: 'Angers / Paris / Dijon', en: 'Angers / Paris / Dijon'),
        overview: LocalizedText(
            fr: 'Grande école d\'ingénieurs généralistes du numérique.',
            en: 'Large digital engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '8 800 EUR/an', en: '8 800 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_eseo'],
        isPartner: true),
    InstitutionModel(
        id: 'esigelec_rouen',
        name: LocalizedText(fr: 'ESIGELEC', en: 'ESIGELEC'),
        countryId: 'france',
        location: LocalizedText(fr: 'Rouen / Poitiers', en: 'Rouen / Poitiers'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs des systèmes intelligents et connectés.',
            en: 'Intelligent and connected systems engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '8 500 EUR/an', en: '8 500 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_esigelec'],
        isPartner: true),
    InstitutionModel(
        id: 'esivall_paris',
        name: LocalizedText(fr: 'ESIEA Paris', en: 'ESIEA Paris'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris', en: 'Paris'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs tech.', en: 'Tech engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '9 000 EUR/an', en: '9 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_esiea_p'],
        isPartner: false),
    InstitutionModel(
        id: 'eurecom_sofia',
        name: LocalizedText(fr: 'EURECOM', en: 'EURECOM'),
        countryId: 'france',
        location: LocalizedText(fr: 'Biot (Sophia Antipolis)', en: 'Biot'),
        overview: LocalizedText(
            fr: 'École de pointe en télécoms et cybersécurité. 100% Anglais.',
            en: 'Advanced school in telecoms and cybersecurity. 100% English.'),
        studyLevels: ['Master'],
        tuitionLabel: LocalizedText(
            fr: '12 000 EUR/an (hors UE)', en: '12 000 EUR/yr (non-EU)'),
        languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_eurecom'],
        isPartner: false),
    InstitutionModel(
        id: 'devinci_paris',
        name: LocalizedText(
            fr: 'Pôle Léonard de Vinci', en: 'Pôle Léonard de Vinci'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris La Défense', en: 'Paris La Défense'),
        overview: LocalizedText(
            fr: 'Campus regroupant management, ingénierie et digital.',
            en: 'Campus combining management, engineering and digital.'),
        studyLevels: ['Bac+3', 'Bac+5'],
        tuitionLabel: LocalizedText(fr: '10 000 EUR/an', en: '10 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_devinci'],
        isPartner: true),
    InstitutionModel(
        id: 'leonardo_it',
        name: LocalizedText(fr: 'IIM Digital School', en: 'IIM Digital School'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris La Défense', en: 'Paris La Défense'),
        overview: LocalizedText(
            fr: 'École du web et du digital.', en: 'Web and digital school.'),
        studyLevels: ['Bac+3', 'Bac+5'],
        tuitionLabel: LocalizedText(fr: '9 000 EUR/an', en: '9 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_iim'],
        isPartner: true),
    InstitutionModel(
        id: 'emlv_bus',
        name: LocalizedText(fr: 'EMLV Business School', en: 'EMLV'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris La Défense', en: 'Paris La Défense'),
        overview: LocalizedText(
            fr: 'École de management post-bac.',
            en: 'Post-bac management school.'),
        studyLevels: ['Bachelor', 'PGE', 'MSc'],
        tuitionLabel: LocalizedText(fr: '10 500 EUR/an', en: '10 500 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_emlv'],
        isPartner: true),
    InstitutionModel(
        id: 'esilv_ing',
        name: LocalizedText(fr: 'ESILV Engineering School', en: 'ESILV'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris La Défense', en: 'Paris La Défense'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs généraliste.',
            en: 'Generalist engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '10 000 EUR/an', en: '10 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_esilv'],
        isPartner: true),
    InstitutionModel(
        id: 'isep_paris',
        name: LocalizedText(fr: 'ISEP', en: 'ISEP'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris', en: 'Paris'),
        overview: LocalizedText(
            fr: 'Grande école d\'ingénieurs du numérique.',
            en: 'Large digital engineering school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: '9 800 EUR/an', en: '9 800 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_isep'],
        isPartner: false),
    InstitutionModel(
        id: 'eisti_pau',
        name: LocalizedText(fr: 'CY Tech Pau', en: 'CY Tech Pau'),
        countryId: 'france',
        location: LocalizedText(fr: 'Pau', en: 'Pau'),
        overview: LocalizedText(
            fr: 'Campus Sud-Ouest de CY Tech.',
            en: 'South-West campus of CY Tech.'),
        studyLevels: ['Bac+5'],
        tuitionLabel:
            LocalizedText(fr: 'Public / Privé', en: 'Public / Private'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_cy_pau'],
        isPartner: false),
    InstitutionModel(
        id: 'mines_albi',
        name: LocalizedText(fr: 'IMT Mines Albi', en: 'IMT Mines Albi'),
        countryId: 'france',
        location: LocalizedText(fr: 'Albi', en: 'Albi'),
        overview: LocalizedText(
            fr: 'École d\'ingénieurs généraliste publique.',
            en: 'Public generalist engineering school.'),
        studyLevels: ['Bac+5', 'MSc'],
        tuitionLabel: LocalizedText(fr: 'Public (Euros)', en: 'Public (Euros)'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_mines_albi'],
        isPartner: false),
    InstitutionModel(
        id: 'mines_ales',
        name: LocalizedText(fr: 'IMT Mines Alès', en: 'IMT Mines Alès'),
        countryId: 'france',
        location: LocalizedText(fr: 'Alès', en: 'Alès'),
        overview: LocalizedText(
            fr: 'Prestigieuse école des Mines française.',
            en: 'Prestigious French Mines school.'),
        studyLevels: ['Bac+5'],
        tuitionLabel: LocalizedText(fr: 'Public (Euros)', en: 'Public (Euros)'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_mines_ales'],
        isPartner: false),
    InstitutionModel(
        id: 'mines_nantes',
        name: LocalizedText(
            fr: 'IMT Atlantique (ex-Mines Nantes)', en: 'IMT Atlantique'),
        countryId: 'france',
        location: LocalizedText(fr: 'Nantes / Brest', en: 'Nantes / Brest'),
        overview: LocalizedText(
            fr: 'Grande école d\'ingénieurs de premier rang.',
            en: 'First-rank engineering school.'),
        studyLevels: ['Bac+5', 'MSc', 'PhD'],
        tuitionLabel: LocalizedText(
            fr: 'Public (non-EU fees apply)', en: 'Public (non-EU fees)'),
        languageRequirements:
            LocalizedText(fr: 'Anglais / Français', en: 'English / French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_imt_at'],
        isPartner: false),
    InstitutionModel(
        id: 'icn_berlin',
        name: LocalizedText(fr: 'ICN Berlin Campus', en: 'ICN Berlin'),
        countryId: 'france',
        location: LocalizedText(fr: 'Berlin, Germany', en: 'Berlin, Germany'),
        overview: LocalizedText(
            fr: 'Campus allemand de l\'école française.',
            en: 'German campus of the French school.'),
        studyLevels: ['Bachelor', 'MSc'],
        tuitionLabel: LocalizedText(fr: '10 000 EUR/an', en: '10 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_icn_berlin'],
        isPartner: true),
    InstitutionModel(
        id: 'skema_raleigh',
        name: LocalizedText(fr: 'SKEMA Raleigh Campus', en: 'SKEMA Raleigh'),
        countryId: 'france',
        location: LocalizedText(fr: 'Raleigh, USA', en: 'Raleigh, USA'),
        overview: LocalizedText(
            fr: 'Campus US au cœur du Research Triangle Park.',
            en: 'US campus in the heart of Research Triangle Park.'),
        studyLevels: ['BBA', 'Master'],
        tuitionLabel: LocalizedText(fr: '15 000 EUR/an', en: '15 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_skema_us'],
        isPartner: true),
    InstitutionModel(
        id: 'skema_suzhou',
        name: LocalizedText(fr: 'SKEMA Suzhou Campus', en: 'SKEMA Suzhou'),
        countryId: 'france',
        location: LocalizedText(fr: 'Suzhou, China', en: 'Suzhou, China'),
        overview: LocalizedText(
            fr: 'Campus chinois proche de Shanghai.',
            en: 'Chinese campus near Shanghai.'),
        studyLevels: ['BBA', 'Master'],
        tuitionLabel: LocalizedText(fr: '13 000 EUR/an', en: '13 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Anglais / Chinois', en: 'English / Chinese'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_skema_cn'],
        isPartner: true),
    InstitutionModel(
        id: 'kedge_dakar',
        name:
            LocalizedText(fr: 'KEDGE Business School Dakar', en: 'KEDGE Dakar'),
        countryId: 'france',
        location: LocalizedText(fr: 'Dakar, Senegal', en: 'Dakar, Senegal'),
        overview: LocalizedText(
            fr: 'Campus africain de KEDGE.', en: 'African campus of KEDGE.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel:
            LocalizedText(fr: 'Local Currency Fees', en: 'Local Currency Fees'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_kedge_sn'],
        isPartner: true),
    InstitutionModel(
        id: 'audencia_shenzhen',
        name: LocalizedText(fr: 'SABS Shenzhen', en: 'SABS Shenzhen'),
        countryId: 'france',
        location: LocalizedText(fr: 'Shenzhen, China', en: 'Shenzhen, China'),
        overview: LocalizedText(
            fr: 'Partenariat Audencia-Shenzhen University.',
            en: 'Audencia-Shenzhen University partnership.'),
        studyLevels: ['Master', 'DBA'],
        tuitionLabel: LocalizedText(fr: 'Intl Fees', en: 'Intl Fees'),
        languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_audencia_cn'],
        isPartner: true),
    InstitutionModel(
        id: 'essec_singapour',
        name: LocalizedText(fr: 'ESSEC Asia-Pacific', en: 'ESSEC Asia-Pacific'),
        countryId: 'france',
        location: LocalizedText(fr: 'Singapore', en: 'Singapore'),
        overview: LocalizedText(
            fr: 'Campus d\'excellence en Asie.',
            en: 'Excellence campus in Asia.'),
        studyLevels: ['Bachelor', 'Master', 'MBA'],
        tuitionLabel: LocalizedText(fr: 'Intl Fees', en: 'Intl Fees'),
        languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
        intakePeriods: ['Août'],
        programIds: ['prog_fr_essec_sg'],
        isPartner: false),
    InstitutionModel(
        id: 'edhec_london',
        name: LocalizedText(fr: 'EDHEC London', en: 'EDHEC London'),
        countryId: 'france',
        location: LocalizedText(fr: 'London, UK', en: 'London, UK'),
        overview: LocalizedText(
            fr: 'Spécialisé en finance de marché.',
            en: 'Specialized in market finance.'),
        studyLevels: ['MSc', 'PhD'],
        tuitionLabel: LocalizedText(fr: 'Intl Fees', en: 'Intl Fees'),
        languageRequirements: LocalizedText(fr: 'Anglais', en: 'English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_edhec_uk'],
        isPartner: false),
    InstitutionModel(
        id: 'tbs_barcelona',
        name: LocalizedText(fr: 'TBS Barcelona', en: 'TBS Barcelona'),
        countryId: 'france',
        location: LocalizedText(fr: 'Barcelona, Spain', en: 'Barcelona, Spain'),
        overview: LocalizedText(
            fr: 'Campus espagnol de TBS Education.',
            en: 'Spanish campus of TBS Education.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '11 000 EUR/an', en: '11 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Anglais / Espagnol', en: 'English / Spanish'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_tbs_es'],
        isPartner: true),
    InstitutionModel(
        id: 'neoma_digital',
        name: LocalizedText(fr: 'NEOMA TEMA', en: 'NEOMA TEMA'),
        countryId: 'france',
        location: LocalizedText(fr: 'Reims', en: 'Reims'),
        overview: LocalizedText(
            fr: 'Programme digital et management.',
            en: 'Digital and management program.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '12 000 EUR/an', en: '12 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_neoma_tema'],
        isPartner: true),
    InstitutionModel(
        id: 'isc_orleans',
        name: LocalizedText(fr: 'ISC Orléans', en: 'ISC Orleans'),
        countryId: 'france',
        location: LocalizedText(fr: 'Orléans', en: 'Orleans'),
        overview: LocalizedText(
            fr: 'Nouveau campus ISC en région.',
            en: 'New regional ISC campus.'),
        studyLevels: ['Bachelor', 'Master'],
        tuitionLabel: LocalizedText(fr: '9 000 EUR/an', en: '9 000 EUR/yr'),
        languageRequirements: LocalizedText(fr: 'Français', en: 'French'),
        intakePeriods: ['Septembre'],
        programIds: ['prog_fr_isc_orl'],
        isPartner: false),
    InstitutionModel(
        id: 'isg_luxury',
        name: LocalizedText(fr: 'ISG Luxury Management', en: 'ISG Luxury'),
        countryId: 'france',
        location: LocalizedText(fr: 'Paris / Genève', en: 'Paris / Geneva'),
        overview: LocalizedText(
            fr: 'Spécialisé dans l\'industrie du luxe.',
            en: 'Specialized in the luxury industry.'),
        studyLevels: ['Bachelor', 'MBA'],
        tuitionLabel: LocalizedText(fr: '12 000 EUR/an', en: '12 000 EUR/yr'),
        languageRequirements:
            LocalizedText(fr: 'Français / Anglais', en: 'French / English'),
        intakePeriods: ['Septembre', 'Janvier'],
        programIds: ['prog_fr_isg_lux'],
        isPartner: false),
  ];

  static const programs = <ProgramModel>[
    ProgramModel(
      id: 'prog_001',
      institutionId: 'icn',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(fr: 'International BBA', en: 'International BBA'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '9900 EUR/an', en: '9900 EUR/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Year 1: Baccalaureate or equivalent. Year 2: 1 year of higher education.',
            en: 'Year 1: Baccalaureate or equivalent. Year 2: 1 year of higher education.')
      ],
    ),
    ProgramModel(
      id: 'prog_002',
      institutionId: 'icn',
      countryId: 'germany',
      fieldId: 'd02',
      name: LocalizedText(fr: 'International BBA', en: 'International BBA'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '9900 EUR/an', en: '9900 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Year 1: Baccalaureate or equivalent. Year 2: 1 year of higher education.',
            en: 'Year 1: Baccalaureate or equivalent. Year 2: 1 year of higher education.')
      ],
    ),
    ProgramModel(
      id: 'prog_003',
      institutionId: 'icn',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor in Management', en: 'Bachelor in Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '9200 EUR/an', en: '9200 EUR/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Program-specific; contact KPB for latest entry requirements.',
            en: 'Program-specific; contact KPB for latest entry requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_004',
      institutionId: 'icn',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor Tech & Innovation Management',
          en: 'Bachelor Tech & Innovation Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '8000 EUR/an', en: '8000 EUR/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Program-specific; contact KPB for latest entry requirements.',
            en: 'Program-specific; contact KPB for latest entry requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_005',
      institutionId: 'icn',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Master in Management (Grande École)',
          en: 'Master in Management (Grande École)'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 years', en: '2 years'),
      tuition: LocalizedText(fr: '14500 EUR/an', en: '14500 EUR/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Program-specific; contact KPB for latest entry requirements.',
            en: 'Program-specific; contact KPB for latest entry requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_006',
      institutionId: 'icn',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'MSc in International Management MIEX',
          en: 'MSc in International Management MIEX'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 years', en: '2 years'),
      tuition: LocalizedText(fr: '10000 EUR/an', en: '10000 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Program-specific; contact KPB for latest entry requirements.',
            en: 'Program-specific; contact KPB for latest entry requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_007',
      institutionId: 'icn',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(fr: 'MSc (DESSMI)', en: 'MSc (DESSMI)'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 years', en: '2 years'),
      tuition: LocalizedText(fr: '9500 EUR/an', en: '9500 EUR/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Program-specific; contact KPB for latest entry requirements.',
            en: 'Program-specific; contact KPB for latest entry requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_008',
      institutionId: 'icn',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(fr: 'PhD', en: 'PhD'),
      level: LocalizedText(fr: 'Doctorat', en: 'Doctorat'),
      duration: LocalizedText(fr: 'Varies', en: 'Varies'),
      tuition: LocalizedText(fr: '9000 EUR/an', en: '9000 EUR/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Program-specific; contact KPB for latest entry requirements.',
            en: 'Program-specific; contact KPB for latest entry requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_009',
      institutionId: 'icn',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(fr: 'DBA', en: 'DBA'),
      level: LocalizedText(fr: 'DBA', en: 'DBA'),
      duration: LocalizedText(fr: 'Varies', en: 'Varies'),
      tuition: LocalizedText(fr: '30000 EUR/an', en: '30000 EUR/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Program-specific; contact KPB for latest entry requirements.',
            en: 'Program-specific; contact KPB for latest entry requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_010',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd07',
      name: LocalizedText(
          fr: 'BA in International Relations and Diplomacy',
          en: 'BA in International Relations and Diplomacy'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '15420 EUR/an', en: '15420 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_011',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'BS in International Business',
          en: 'BS in International Business'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '15420 EUR/an', en: '15420 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_012',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd12',
      name: LocalizedText(
          fr: 'BS in International Hospitality and Tourism Management',
          en: 'BS in International Hospitality and Tourism Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '15420 EUR/an', en: '15420 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_013',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'BS in International Marketing',
          en: 'BS in International Marketing'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '15420 EUR/an', en: '15420 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_014',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'BS in Computer Science', en: 'BS in Computer Science'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '15420 EUR/an', en: '15420 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_015',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'BS in Applied Mathematics and Artificial Intelligence',
          en: 'BS in Applied Mathematics and Artificial Intelligence'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '15420 EUR/an', en: '15420 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_016',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'BS in Business Analytics', en: 'BS in Business Analytics'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '15420 EUR/an', en: '15420 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_017',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd07',
      name: LocalizedText(
          fr: 'BA in International Relations and Diplomacy',
          en: 'BA in International Relations and Diplomacy'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '17610 USD/an', en: '17610 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_018',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'BS in International Business',
          en: 'BS in International Business'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '17610 USD/an', en: '17610 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_019',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd12',
      name: LocalizedText(
          fr: 'BS in International Hospitality and Tourism Management',
          en: 'BS in International Hospitality and Tourism Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '17610 USD/an', en: '17610 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_020',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'BS in International Marketing',
          en: 'BS in International Marketing'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '17610 USD/an', en: '17610 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_021',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'BS in Computer Science', en: 'BS in Computer Science'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '17610 USD/an', en: '17610 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_022',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'BS in Applied Mathematics and Artificial Intelligence',
          en: 'BS in Applied Mathematics and Artificial Intelligence'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '17610 USD/an', en: '17610 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_023',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'BS in Business Analytics', en: 'BS in Business Analytics'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '17610 USD/an', en: '17610 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Official secondary school completion / high school diploma or equivalent.',
            en: 'Official secondary school completion / high school diploma or equivalent.')
      ],
    ),
    ProgramModel(
      id: 'prog_024',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd07',
      name: LocalizedText(
          fr: 'MA in International Relations and Diplomacy',
          en: 'MA in International Relations and Diplomacy'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '16560 EUR/an', en: '16560 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_025',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MS in Digital Marketing and E-commerce',
          en: 'MS in Digital Marketing and E-commerce'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '16560 EUR/an', en: '16560 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_026',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd03',
      name:
          LocalizedText(fr: 'MS in Global Finance', en: 'MS in Global Finance'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '16560 EUR/an', en: '16560 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_027',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd08',
      name: LocalizedText(
          fr: 'MS in Sustainability Management',
          en: 'MS in Sustainability Management'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '16500 EUR/an', en: '16500 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_028',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd01',
      name: LocalizedText(fr: 'MS in Data Science', en: 'MS in Data Science'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '16500 EUR/an', en: '16500 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_029',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd02',
      name: LocalizedText(fr: 'MBA', en: 'MBA'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '16560 EUR/an', en: '16560 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_030',
      institutionId: 'schiller',
      countryId: 'spain',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'MBA in International Business',
          en: 'MBA in International Business'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '20700 EUR/an', en: '20700 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_031',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd07',
      name: LocalizedText(
          fr: 'MA in International Relations and Diplomacy',
          en: 'MA in International Relations and Diplomacy'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '19620 USD/an', en: '19620 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_032',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MS in Digital Marketing and E-commerce',
          en: 'MS in Digital Marketing and E-commerce'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '19620 USD/an', en: '19620 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_033',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd03',
      name:
          LocalizedText(fr: 'MS in Global Finance', en: 'MS in Global Finance'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '19620 USD/an', en: '19620 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_034',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd08',
      name: LocalizedText(
          fr: 'MS in Sustainability Management',
          en: 'MS in Sustainability Management'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '19410 USD/an', en: '19410 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_035',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd01',
      name: LocalizedText(fr: 'MS in Data Science', en: 'MS in Data Science'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '19410 USD/an', en: '19410 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_036',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd02',
      name: LocalizedText(fr: 'MBA', en: 'MBA'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '19620 USD/an', en: '19620 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_037',
      institutionId: 'schiller',
      countryId: 'usa',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'MBA in International Business',
          en: 'MBA in International Business'),
      level: LocalizedText(fr: 'MBA', en: 'MBA'),
      duration: LocalizedText(
          fr: 'See official program page', en: 'See official program page'),
      tuition: LocalizedText(fr: '24525 USD/an', en: '24525 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.',
            en: 'Bachelor\\\'s degree or equivalent; transcript evaluation may be required for some international credentials.')
      ],
    ),
    ProgramModel(
      id: 'prog_038',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'Comptabilité, Contrôle et Audit',
          en: 'Comptabilité, Contrôle et Audit'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Baccalaureate all streams; dossier review plus written test and oral interview.',
            en: 'Baccalaureate all streams; dossier review plus written test and oral interview.')
      ],
    ),
    ProgramModel(
      id: 'prog_039',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Marketing Digital & Développement Commercial',
          en: 'Marketing Digital & Développement Commercial'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Baccalaureate all streams; dossier review plus written test and oral interview.',
            en: 'Baccalaureate all streams; dossier review plus written test and oral interview.')
      ],
    ),
    ProgramModel(
      id: 'prog_040',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Logistique, Transport et Commerce International',
          en: 'Logistique, Transport et Commerce International'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Baccalaureate all streams; dossier review plus written test and oral interview.',
            en: 'Baccalaureate all streams; dossier review plus written test and oral interview.')
      ],
    ),
    ProgramModel(
      id: 'prog_041',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Gestion des Ressources Humaines',
          en: 'Gestion des Ressources Humaines'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Baccalaureate all streams; dossier review plus written test and oral interview.',
            en: 'Baccalaureate all streams; dossier review plus written test and oral interview.')
      ],
    ),
    ProgramModel(
      id: 'prog_042',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Développement Multimédia et Animation 3D',
          en: 'Développement Multimédia et Animation 3D'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Scientific, economic, or technical baccalaureate; dossier review plus written test and oral interview.',
            en: 'Scientific, economic, or technical baccalaureate; dossier review plus written test and oral interview.')
      ],
    ),
    ProgramModel(
      id: 'prog_043',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Blockchain et Cryptographie', en: 'Blockchain et Cryptographie'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Scientific, economic, or technical baccalaureate; dossier review plus written test and oral interview.',
            en: 'Scientific, economic, or technical baccalaureate; dossier review plus written test and oral interview.')
      ],
    ),
    ProgramModel(
      id: 'prog_044',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Développement Web et Mobile', en: 'Développement Web et Mobile'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Scientific, economic, or technical baccalaureate; dossier review plus written test and oral interview.',
            en: 'Scientific, economic, or technical baccalaureate; dossier review plus written test and oral interview.')
      ],
    ),
    ProgramModel(
      id: 'prog_045',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'IoT et Systèmes Intelligents',
          en: 'IoT et Systèmes Intelligents'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Scientific, economic, or technical baccalaureate; dossier review plus written test and oral interview.',
            en: 'Scientific, economic, or technical baccalaureate; dossier review plus written test and oral interview.')
      ],
    ),
    ProgramModel(
      id: 'prog_046',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Classes préparatoires intégrées',
          en: 'Classes préparatoires intégrées'),
      level: LocalizedText(fr: 'Bac+2', en: 'BTS/DUT'),
      duration: LocalizedText(fr: '2 years', en: '2 years'),
      tuition: LocalizedText(fr: '40000 MAD/an', en: '40000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Scientific baccalaureate; dossier review plus written test and oral interview.',
            en: 'Scientific baccalaureate; dossier review plus written test and oral interview.')
      ],
    ),
    ProgramModel(
      id: 'prog_047',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Ingénierie Informatique', en: 'Ingénierie Informatique'),
      level: LocalizedText(fr: 'Engineering', en: 'Engineering'),
      duration: LocalizedText(fr: 'To confirm', en: 'To confirm'),
      tuition: LocalizedText(fr: '45000 MAD/an', en: '45000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Engineering pathway / school-specific progression and admissions.',
            en: 'Engineering pathway / school-specific progression and admissions.')
      ],
    ),
    ProgramModel(
      id: 'prog_048',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Ingénierie Data Science et Biotech',
          en: 'Ingénierie Data Science et Biotech'),
      level: LocalizedText(fr: 'Engineering', en: 'Engineering'),
      duration: LocalizedText(fr: 'To confirm', en: 'To confirm'),
      tuition: LocalizedText(fr: '45000 MAD/an', en: '45000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Engineering pathway / school-specific progression and admissions.',
            en: 'Engineering pathway / school-specific progression and admissions.')
      ],
    ),
    ProgramModel(
      id: 'prog_049',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Master en Gestion Opérationnelle et Stratégies des Entreprises',
          en: 'Master en Gestion Opérationnelle et Stratégies des Entreprises'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: 'To confirm', en: 'To confirm'),
      tuition: LocalizedText(fr: '45000 MAD/an', en: '45000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Relevant prior degree / program-specific requirements.',
            en: 'Relevant prior degree / program-specific requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_050',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd08',
      name: LocalizedText(
          fr: 'Master en Qualité, Hygiène, Sécurité, Environnement',
          en: 'Master en Qualité, Hygiène, Sécurité, Environnement'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: 'To confirm', en: 'To confirm'),
      tuition: LocalizedText(fr: '45000 MAD/an', en: '45000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Relevant prior degree / program-specific requirements.',
            en: 'Relevant prior degree / program-specific requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_051',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'Master en Comptabilité, Contrôle et Audit',
          en: 'Master en Comptabilité, Contrôle et Audit'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: 'To confirm', en: 'To confirm'),
      tuition: LocalizedText(fr: '45000 MAD/an', en: '45000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Relevant prior degree / program-specific requirements.',
            en: 'Relevant prior degree / program-specific requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_052',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Master en IoT et Data Science',
          en: 'Master en IoT et Data Science'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: 'To confirm', en: 'To confirm'),
      tuition: LocalizedText(fr: '45000 MAD/an', en: '45000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Relevant prior degree / program-specific requirements.',
            en: 'Relevant prior degree / program-specific requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_053',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'Master Fintech and Risk Management',
          en: 'Master Fintech and Risk Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: 'To confirm', en: 'To confirm'),
      tuition: LocalizedText(fr: '45000 MAD/an', en: '45000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Relevant prior degree / program-specific requirements.',
            en: 'Relevant prior degree / program-specific requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_054',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Master Développement Logiciel, Mobile et IoT',
          en: 'Master Développement Logiciel, Mobile et IoT'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: 'To confirm', en: 'To confirm'),
      tuition: LocalizedText(fr: '45000 MAD/an', en: '45000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Relevant prior degree / program-specific requirements.',
            en: 'Relevant prior degree / program-specific requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_055',
      institutionId: 'ismagi',
      countryId: 'morocco',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Master Digital Marketing and Communication',
          en: 'Master Digital Marketing and Communication'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: 'To confirm', en: 'To confirm'),
      tuition: LocalizedText(fr: '45000 MAD/an', en: '45000 MAD/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Relevant prior degree / program-specific requirements.',
            en: 'Relevant prior degree / program-specific requirements.')
      ],
    ),
    ProgramModel(
      id: 'prog_056',
      institutionId: 'esa_casa',
      countryId: 'morocco',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bac+3 Gestion des entreprises - Option Management',
          en: 'Bac+3 Gestion des entreprises - Option Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '5500 EUR/an', en: '5500 EUR/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Year 1: Bac validated or in progress. Year 2: Bac + validated first year in management. Year 3: Bac+2 or Bac+3 in management disciplines.',
            en: 'Year 1: Bac validated or in progress. Year 2: Bac + validated first year in management. Year 3: Bac+2 or Bac+3 in management disciplines.')
      ],
    ),
    ProgramModel(
      id: 'prog_057',
      institutionId: 'esa_casa',
      countryId: 'morocco',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'Bac+3 Gestion des entreprises - Option Finance',
          en: 'Bac+3 Gestion des entreprises - Option Finance'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 years', en: '3 years'),
      tuition: LocalizedText(fr: '5500 EUR/an', en: '5500 EUR/an'),
      language: LocalizedText(fr: 'Bilingue EN/FR', en: 'Bilingue EN/FR'),
      requirements: [
        LocalizedText(
            fr: 'Year 1: Bac validated or in progress. Year 2: Bac + validated first year in management. Year 3: Bac+2 or Bac+3 in management disciplines.',
            en: 'Year 1: Bac validated or in progress. Year 2: Bac + validated first year in management. Year 3: Bac+2 or Bac+3 in management disciplines.')
      ],
    ),
    ProgramModel(
      id: 'prog_058',
      institutionId: 'bau',
      countryId: 'turkey',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Business Administration', en: 'Business Administration'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '8500 USD/an', en: '8500 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.',
            en: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.')
      ],
    ),
    ProgramModel(
      id: 'prog_059',
      institutionId: 'bau',
      countryId: 'turkey',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'International Trade and Business',
          en: 'International Trade and Business'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '8500 USD/an', en: '8500 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.',
            en: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.')
      ],
    ),
    ProgramModel(
      id: 'prog_060',
      institutionId: 'bau',
      countryId: 'turkey',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'International Finance', en: 'International Finance'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '8500 USD/an', en: '8500 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.',
            en: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.')
      ],
    ),
    ProgramModel(
      id: 'prog_061',
      institutionId: 'bau',
      countryId: 'turkey',
      fieldId: 'd01',
      name:
          LocalizedText(fr: 'Computer Engineering', en: 'Computer Engineering'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '9000 USD/an', en: '9000 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.',
            en: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.')
      ],
    ),
    ProgramModel(
      id: 'prog_062',
      institutionId: 'bau',
      countryId: 'turkey',
      fieldId: 'd01',
      name:
          LocalizedText(fr: 'Software Engineering', en: 'Software Engineering'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '9000 USD/an', en: '9000 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.',
            en: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.')
      ],
    ),
    ProgramModel(
      id: 'prog_063',
      institutionId: 'bau',
      countryId: 'turkey',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Artificial Intelligence Engineering',
          en: 'Artificial Intelligence Engineering'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '12000 USD/an', en: '12000 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.',
            en: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.')
      ],
    ),
    ProgramModel(
      id: 'prog_064',
      institutionId: 'bau',
      countryId: 'turkey',
      fieldId: 'd04',
      name: LocalizedText(fr: 'Medicine', en: 'Medicine'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '6 years', en: '6 years'),
      tuition: LocalizedText(fr: '28000 USD/an', en: '28000 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.',
            en: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.')
      ],
    ),
    ProgramModel(
      id: 'prog_065',
      institutionId: 'bau',
      countryId: 'turkey',
      fieldId: 'd11',
      name: LocalizedText(fr: 'Architecture', en: 'Architecture'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '8500 USD/an', en: '8500 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.',
            en: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.')
      ],
    ),
    ProgramModel(
      id: 'prog_066',
      institutionId: 'bau',
      countryId: 'turkey',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Textile and Fashion Design', en: 'Textile and Fashion Design'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '4 years', en: '4 years'),
      tuition: LocalizedText(fr: '8500 USD/an', en: '8500 USD/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.',
            en: 'Online application; passport, high school transcripts, and diploma if available. Some programs require motivation letter or portfolio.')
      ],
    ),
    ProgramModel(
      id: 'prog_067',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'International Diploma in Business (Level 2)',
          en: 'International Diploma in Business (Level 2)'),
      level: LocalizedText(fr: 'Diplôme', en: 'Diplôme'),
      duration: LocalizedText(fr: '1 year', en: '1 year'),
      tuition: LocalizedText(fr: '25000 AED/an', en: '25000 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_068',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'International Extended Diploma in Business (Level 3)',
          en: 'International Extended Diploma in Business (Level 3)'),
      level: LocalizedText(fr: 'Diplôme', en: 'Diplôme'),
      duration: LocalizedText(fr: '1 year', en: '1 year'),
      tuition: LocalizedText(fr: '40000 AED/an', en: '40000 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_069',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'International Extended Diploma in IT (Level 3)',
          en: 'International Extended Diploma in IT (Level 3)'),
      level: LocalizedText(fr: 'Diplôme', en: 'Diplôme'),
      duration: LocalizedText(fr: '1 year', en: '1 year'),
      tuition: LocalizedText(fr: '40000 AED/an', en: '40000 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_070',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'HND International in Business',
          en: 'HND International in Business'),
      level: LocalizedText(fr: 'Bac+2', en: 'BTS/DUT'),
      duration: LocalizedText(fr: '2 years', en: '2 years'),
      tuition: LocalizedText(fr: '40000 AED/an', en: '40000 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_071',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'HND in Digital Technologies (Cyber Security)',
          en: 'HND in Digital Technologies (Cyber Security)'),
      level: LocalizedText(fr: 'Bac+2', en: 'BTS/DUT'),
      duration: LocalizedText(fr: '2 years', en: '2 years'),
      tuition: LocalizedText(fr: '40000 AED/an', en: '40000 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_072',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'HND in Digital Technologies (Artificial Intelligence)',
          en: 'HND in Digital Technologies (Artificial Intelligence)'),
      level: LocalizedText(fr: 'Bac+2', en: 'BTS/DUT'),
      duration: LocalizedText(fr: '2 years', en: '2 years'),
      tuition: LocalizedText(fr: '40000 AED/an', en: '40000 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_073',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd04',
      name: LocalizedText(
          fr: 'HND in Healthcare Practices (Healthcare Management)',
          en: 'HND in Healthcare Practices (Healthcare Management)'),
      level: LocalizedText(fr: 'Bac+2', en: 'BTS/DUT'),
      duration: LocalizedText(fr: '2 years', en: '2 years'),
      tuition: LocalizedText(fr: '40000 AED/an', en: '40000 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_074',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd11',
      name: LocalizedText(
          fr: 'HND in Construction Management',
          en: 'HND in Construction Management'),
      level: LocalizedText(fr: 'Bac+2', en: 'BTS/DUT'),
      duration: LocalizedText(fr: '2 years', en: '2 years'),
      tuition: LocalizedText(fr: '40000 AED/an', en: '40000 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_075',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd03',
      name: LocalizedText(fr: 'ACCA', en: 'ACCA'),
      level: LocalizedText(fr: 'Professional', en: 'Professional'),
      duration: LocalizedText(fr: 'Varies', en: 'Varies'),
      tuition: LocalizedText(fr: '8000-18500 AED/an', en: '8000-18500 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_076',
      institutionId: 'gbs_dubai',
      countryId: 'uae',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'Global Investment Banking Analyst Programme',
          en: 'Global Investment Banking Analyst Programme'),
      level: LocalizedText(fr: 'Certificat', en: 'Certificat'),
      duration: LocalizedText(fr: '4 weeks', en: '4 weeks'),
      tuition: LocalizedText(fr: '10000 AED/an', en: '10000 AED/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…',
            en: 'Academic entry requirements vary by country/course. HND policy example references Grade 12/HSC minimum 50%, IB 24, US GPA 2.0/4, and minimum age 17…')
      ],
    ),
    ProgramModel(
      id: 'prog_077',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Computer Science', en: 'Bachelor - Computer Science'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '8.490 EUR/an', en: '8.490 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_078',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Informatique', en: 'Bachelor - Informatique'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '8.490 EUR/an', en: '8.490 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_079',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Développeur Data et IA',
          en: 'Bachelor - Développeur Data et IA'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.690 EUR/an', en: '9.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_080',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Informatique - Cybersécurité et Réseaux',
          en: 'Bachelor - Informatique - Cybersécurité et Réseaux'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.690 EUR/an', en: '9.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_081',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Informatique - Développeur Data et IA',
          en: 'Bachelor - Informatique - Développeur Data et IA'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.690 EUR/an', en: '9.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_082',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Informatique - Développeur d\'Applications',
          en: 'Bachelor - Informatique - Développeur d\'Applications'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.690 EUR/an', en: '9.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_083',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Informatique - DevOps et Cloud',
          en: 'Bachelor - Informatique - DevOps et Cloud'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.690 EUR/an', en: '9.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_084',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(fr: 'M1 - Data Engineer', en: 'M1 - Data Engineer'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.890 EUR/an', en: '11.890 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_085',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd09',
      name: LocalizedText(
          fr: 'MSc - Systèmes d\'information ERP SAP pour les entreprises',
          en: 'MSc - Systèmes d\'information ERP SAP pour les entreprises'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.890 EUR/an', en: '11.890 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_086',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'MSc - Artificial Intelligence (CGE)',
          en: 'MSc - Artificial Intelligence (CGE)'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.450 EUR/an', en: '12.450 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_087',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'MSc - Cybersecurity Manager (CGE)',
          en: 'MSc - Cybersecurity Manager (CGE)'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.450 EUR/an', en: '12.450 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_088',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'MSc - Data Management (CGE)', en: 'MSc - Data Management (CGE)'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.450 EUR/an', en: '12.450 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_089',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd05',
      name: LocalizedText(
          fr: 'MSc - Sustainable Energy Futures (CGE)',
          en: 'MSc - Sustainable Energy Futures (CGE)'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.450 EUR/an', en: '12.450 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_090',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'MSc - Cybersecurity Management (CGE)',
          en: 'MSc - Cybersecurity Management (CGE)'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.450 EUR/an', en: '12.450 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_091',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'MSc - Technology Management and International Entrepreneurship (CGE)',
          en: 'MSc - Technology Management and International Entrepreneurship (CGE)'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.450 EUR/an', en: '12.450 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_092',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'MSc - Manager de la Cybersécurité (CGE)',
          en: 'MSc - Manager de la Cybersécurité (CGE)'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.450 EUR/an', en: '12.450 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_093',
      institutionId: 'ece',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Programme Grande Ecole - Cycle Préparatoire',
          en: 'Programme Grande Ecole - Cycle Préparatoire'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.150 EUR/an', en: '12.150 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_094',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor - International Bachelor',
          en: 'Bachelor - International Bachelor'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.650 EUR/an', en: '9.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_095',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor - International Business',
          en: 'Bachelor - International Business'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.650 EUR/an', en: '9.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_096',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor - Management des Organisations',
          en: 'Bachelor - Management des Organisations'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.650 EUR/an', en: '9.650 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_097',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Master in Management - International business',
          en: 'Master in Management - International business'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_098',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Master in Management - Régions Amérique/Asie/Europe',
          en: 'Master in Management - Régions Amérique/Asie/Europe'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_099',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Master in Management - Cursus expert America/Asia/Europe',
          en: 'Master in Management - Cursus expert America/Asia/Europe'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_100',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Programme Grande Ecole - International business',
          en: 'Programme Grande Ecole - International business'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_101',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Programme Grande Ecole - Régions Amérique/Asie/Europe',
          en: 'Programme Grande Ecole - Régions Amérique/Asie/Europe'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_102',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Master in Management - International Business Development',
          en: 'Master in Management - International Business Development'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_103',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Master in Management - Communication, Luxury and Prestige Marketing',
          en: 'Master in Management - Communication, Luxury and Prestige Marketing'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_104',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Master in Management - Digital & Sustainable Supply Chain',
          en: 'Master in Management - Digital & Sustainable Supply Chain'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_105',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Master in Management - International Digital Marketing',
          en: 'Master in Management - International Digital Marketing'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_106',
      institutionId: 'esce',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Programme Grande Ecole - International Business Developement',
          en: 'Programme Grande Ecole - International Business Developement'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.650 EUR/an', en: '12.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_107',
      institutionId: 'heip',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Bachelor of Arts in Humanities',
          en: 'Bachelor - Bachelor of Arts in Humanities'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.650 EUR/an', en: '9.650 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_108',
      institutionId: 'heip',
      countryId: 'france',
      fieldId: 'd07',
      name: LocalizedText(
          fr: 'Bachelor - Relations Internationales et Sciences Politiques',
          en: 'Bachelor - Relations Internationales et Sciences Politiques'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.650 EUR/an', en: '9.650 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_109',
      institutionId: 'heip',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'MSc - ERCI - Diplomatie économique et développement international des entreprises',
          en: 'MSc - ERCI - Diplomatie économique et développement international des entreprises'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_110',
      institutionId: 'heip',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Manager des Institutions et des Affaires Publiques',
          en: 'MSc - Manager des Institutions et des Affaires Publiques'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_111',
      institutionId: 'heip',
      countryId: 'france',
      fieldId: 'd07',
      name: LocalizedText(
          fr: 'MSc - ERCI - Politiques de défense et de sécurité internationale',
          en: 'MSc - ERCI - Politiques de défense et de sécurité internationale'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_112',
      institutionId: 'heip',
      countryId: 'france',
      fieldId: 'd07',
      name: LocalizedText(
          fr: 'MSc - ERCI - ERCI – Politiques de défense et de sécurité internationale',
          en: 'MSc - ERCI - ERCI – Politiques de défense et de sécurité internationale'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_113',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Manager in International Business Activities - Resp commercial activities',
          en: 'Bachelor - Manager in International Business Activities - Resp commercial activities'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_114',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Business Développement & Start-up - Resp des activités commerciales',
          en: 'Bachelor - Business Développement & Start-up - Resp des activités commerciales'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_115',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Commerce à l\'international - Resp des activités commerciales',
          en: 'Bachelor - Commerce à l\'international - Resp des activités commerciales'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_116',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'Bachelor - Finance - Resp en gestion financière et contrôle de gestion',
          en: 'Bachelor - Finance - Resp en gestion financière et contrôle de gestion'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_117',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Luxe et services personnalisés – Resp. d\'activités commerciales',
          en: 'Bachelor - Luxe et services personnalisés – Resp. d\'activités commerciales'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_118',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor - Management, Gestion - Chargé de Gestion et Management',
          en: 'Bachelor - Management, Gestion - Chargé de Gestion et Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_119',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Marketing Comm en Digital - Resp de projet Marketing Communication',
          en: 'Bachelor - Marketing Comm en Digital - Resp de projet Marketing Communication'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_120',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Marketing Comm et Développement - Resp de projet Marketing Communication',
          en: 'Bachelor - Marketing Comm et Développement - Resp de projet Marketing Communication'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_121',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Marketing Comm Evénementielle - Resp de projet Marketing Communication',
          en: 'Bachelor - Marketing Comm Evénementielle - Resp de projet Marketing Communication'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_122',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Sport Business - Resp des activités commerciales',
          en: 'Bachelor - Sport Business - Resp des activités commerciales'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_123',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor - Transac Immo, Marchands de biens - Resp en gestion financière et contrôle de gestion',
          en: 'Bachelor - Transac Immo, Marchands de biens - Resp en gestion financière et contrôle de gestion'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_124',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Vins & Spiritueux - Resp des activités commerciales',
          en: 'Bachelor - Vins & Spiritueux - Resp des activités commerciales'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_125',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd11',
      name: LocalizedText(
          fr: 'Bachelor - Immobilier, Assurance - Resp en gestion financière et contrôle de gestion',
          en: 'Bachelor - Immobilier, Assurance - Resp en gestion financière et contrôle de gestion'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.850 EUR/an', en: '9.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_126',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Vins Spiritueux, Distribution Export - Resp des activités commerciales',
          en: 'Bachelor - Vins Spiritueux, Distribution Export - Resp des activités commerciales'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_127',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Vins Spiritueux, Oenotourisme - Resp des activités commerciales',
          en: 'Bachelor - Vins Spiritueux, Oenotourisme - Resp des activités commerciales'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_128',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Vins Spiritueux, Sommellerie Gastronomie - Resp des activités commerciales',
          en: 'Bachelor - Vins Spiritueux, Sommellerie Gastronomie - Resp des activités commerciales'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_129',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Digital - Web marketing - Resp de projet Marketing Communication',
          en: 'Bachelor - Digital - Web marketing - Resp de projet Marketing Communication'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_130',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Digital Business, IA et Data - Resp de projet Marketing Communication',
          en: 'Bachelor - Digital Business, IA et Data - Resp de projet Marketing Communication'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_131',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Digital, Community & Réseaux Sociaux - Resp de projet Marketing Communication',
          en: 'Bachelor - Digital, Community & Réseaux Sociaux - Resp de projet Marketing Communication'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_132',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'Bachelor - Finance d\'entreprise - Responsable en gestion financière et contrôle de gestion',
          en: 'Bachelor - Finance d\'entreprise - Responsable en gestion financière et contrôle de gestion'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_133',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Immobilier - Chargé de développement commercial et marketing',
          en: 'Bachelor - Immobilier - Chargé de développement commercial et marketing'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_134',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Bachelor - Ressources Humaines - Chargé de gestion sociale et projet RSE',
          en: 'Bachelor - Ressources Humaines - Chargé de gestion sociale et projet RSE'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '10.690 EUR/an', en: '10.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_135',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor - Responsable en gestion financière et contrôle de gestion',
          en: 'Bachelor - Responsable en gestion financière et contrôle de gestion'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '8.340 EUR/an', en: '8.340 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_136',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Programme Grande Ecole', en: 'Programme Grande Ecole'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '13.650 EUR/an', en: '13.650 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_137',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Master in Management - Pre-specialisation in Finance',
          en: 'Master in Management - Pre-specialisation in Finance'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '14.090 EUR/an', en: '14.090 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_138',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Master in Management - Pre-spécialisation in Management',
          en: 'Master in Management - Pre-spécialisation in Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '14.090 EUR/an', en: '14.090 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_139',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Master in Management - Pre-specialisation in Marketing',
          en: 'Master in Management - Pre-specialisation in Marketing'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '14.090 EUR/an', en: '14.090 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_140',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Programme Grande Ecole - Pré spécialisation Finance',
          en: 'Programme Grande Ecole - Pré spécialisation Finance'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '14.090 EUR/an', en: '14.090 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_141',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Programme Grande Ecole - Pré spécialisation Management',
          en: 'Programme Grande Ecole - Pré spécialisation Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '14.090 EUR/an', en: '14.090 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_142',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Programme Grande Ecole - Pré spécialisation Marketing',
          en: 'Programme Grande Ecole - Pré spécialisation Marketing'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '14.090 EUR/an', en: '14.090 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_143',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'MSc - International Management',
          en: 'MSc - International Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.890 EUR/an', en: '12.890 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_144',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Luxury and Fashion Marketing & Customer Experience',
          en: 'MSc - Luxury and Fashion Marketing & Customer Experience'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.890 EUR/an', en: '12.890 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_145',
      institutionId: 'inseec',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Marketing & Brand Management',
          en: 'MSc - Marketing & Brand Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '12.890 EUR/an', en: '12.890 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_146',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor of Business Administration - Business Management',
          en: 'Bachelor of Business Administration - Business Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '15.050 EUR/an', en: '15.050 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_147',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor of Business Administration - Communication & Event Management',
          en: 'Bachelor of Business Administration - Communication & Event Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '15.350 EUR/an', en: '15.350 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_148',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Bachelor of Business Administration - Global Business Management',
          en: 'Bachelor of Business Administration - Global Business Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '15.350 EUR/an', en: '15.350 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_149',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'Bachelor of Business Administration - International Finance',
          en: 'Bachelor of Business Administration - International Finance'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '15.350 EUR/an', en: '15.350 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_150',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor of Business Administration - Luxury Marketing, Sales and Services',
          en: 'Bachelor of Business Administration - Luxury Marketing, Sales and Services'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '15.350 EUR/an', en: '15.350 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_151',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor of Business Administration - Management of Luxury Tourism and Hospitality',
          en: 'Bachelor of Business Administration - Management of Luxury Tourism and Hospitality'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '15.350 EUR/an', en: '15.350 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_152',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor of Business Administration - Sport Business Management',
          en: 'Bachelor of Business Administration - Sport Business Management'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '15.350 EUR/an', en: '15.350 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_153',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'MSc - Finance - Hedge Funds and Alternative Investments',
          en: 'MSc - Finance - Hedge Funds and Alternative Investments'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '27.590 EUR/an', en: '27.590 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_154',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'MSc - Finance - Private Banking and Wealth Management',
          en: 'MSc - Finance - Private Banking and Wealth Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '27.590 EUR/an', en: '27.590 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_155',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'MSc - Finance - Private Equity and Investment Banking',
          en: 'MSc - Finance - Private Equity and Investment Banking'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '31.950 EUR/an', en: '31.950 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_156',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'MSc - International Management',
          en: 'MSc - International Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '26.690 EUR/an', en: '26.690 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_157',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Luxury Management - Brand Management',
          en: 'MSc - Luxury Management - Brand Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '28.690 EUR/an', en: '28.690 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_158',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Luxury Management - Fashion and Accessories',
          en: 'MSc - Luxury Management - Fashion and Accessories'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '28.690 EUR/an', en: '28.690 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_159',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Luxury Management - Hospitality and Events Management',
          en: 'MSc - Luxury Management - Hospitality and Events Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '28.690 EUR/an', en: '28.690 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_160',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Luxury Management - Yachting Industry',
          en: 'MSc - Luxury Management - Yachting Industry'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '28.690 EUR/an', en: '28.690 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_161',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Sport Business Management',
          en: 'MSc - Sport Business Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '26.690 EUR/an', en: '26.690 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_162',
      institutionId: 'ium',
      countryId: 'france',
      fieldId: 'd08',
      name: LocalizedText(
          fr: 'MSc - Sustainability and Innovation Management',
          en: 'MSc - Sustainability and Innovation Management'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '25.850 EUR/an', en: '25.850 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_163',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Communication and Digital marketing',
          en: 'Bachelor - Communication and Digital marketing'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '8.850 EUR/an', en: '8.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_164',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Communication et création visuelle',
          en: 'Bachelor - Communication et création visuelle'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '8.850 EUR/an', en: '8.850 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_165',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Communication et stratégies des Marques',
          en: 'Bachelor - Communication et stratégies des Marques'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.090 EUR/an', en: '9.090 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_166',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Communication événementielle',
          en: 'Bachelor - Communication événementielle'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.690 EUR/an', en: '9.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_167',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Bachelor - Stratégie de communication',
          en: 'Bachelor - Stratégie de communication'),
      level: LocalizedText(fr: 'Bac+3', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 ans'),
      tuition: LocalizedText(fr: '9.690 EUR/an', en: '9.690 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_168',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'MSc - Creative strategies and strategic planning',
          en: 'MSc - Creative strategies and strategic planning'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.550 EUR/an', en: '11.550 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_169',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Luxury and Fashion Communication',
          en: 'MSc - Luxury and Fashion Communication'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.550 EUR/an', en: '11.550 EUR/an'),
      language: LocalizedText(fr: 'Anglais', en: 'English'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_170',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Communication Corporate et Relations Publics',
          en: 'MSc - Communication Corporate et Relations Publics'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.350 EUR/an', en: '11.350 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_171',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Communication et Production visuelle',
          en: 'MSc - Communication et Production visuelle'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.350 EUR/an', en: '11.350 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_172',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'MSc - Communication et Stratégie Média',
          en: 'MSc - Communication et Stratégie Média'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.350 EUR/an', en: '11.350 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_173',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'MSc - Stratégie Digitale et Social Media',
          en: 'MSc - Stratégie Digitale et Social Media'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.350 EUR/an', en: '11.350 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_174',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'MSc - Stratégie et Production Evénementielle',
          en: 'MSc - Stratégie et Production Evénementielle'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.350 EUR/an', en: '11.350 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_175',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Communication des Industries Culturelles et Créatives',
          en: 'MSc - Communication des Industries Culturelles et Créatives'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.350 EUR/an', en: '11.350 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_176',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Direction Artistique et Design Graphique',
          en: 'MSc - Direction Artistique et Design Graphique'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.350 EUR/an', en: '11.350 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_177',
      institutionId: 'sup_de_pub',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'MSc - Communication du Luxe et de la Mode',
          en: 'MSc - Communication du Luxe et de la Mode'),
      level: LocalizedText(fr: 'Bac+5', en: 'Master'),
      duration: LocalizedText(fr: '2 ans', en: '2 ans'),
      tuition: LocalizedText(fr: '11.550 EUR/an', en: '11.550 EUR/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)',
            en: 'Baccalauréat ou équivalent (Bac+3) ; Licence ou équivalent (Bac+5)')
      ],
    ),
    ProgramModel(
      id: 'prog_178',
      institutionId: 'igs_rh',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(fr: 'Ressources Humaines', en: 'Ressources Humaines'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_179',
      institutionId: 'igs_rh',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Transformation Numérique', en: 'Transformation Numérique'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_180',
      institutionId: 'esam',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Management International', en: 'Management International'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_181',
      institutionId: 'esam',
      countryId: 'france',
      fieldId: 'd03',
      name: LocalizedText(
          fr: 'Finance d\'Entreprises', en: 'Finance d\'Entreprises'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_182',
      institutionId: 'esam',
      countryId: 'france',
      fieldId: 'd07',
      name: LocalizedText(
          fr: 'Droit et Sciences Politiques',
          en: 'Droit et Sciences Politiques'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_183',
      institutionId: 'esam',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
          fr: 'Management Stratégique', en: 'Management Stratégique'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_184',
      institutionId: 'esam',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(fr: 'Expert Financier', en: 'Expert Financier'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_185',
      institutionId: 'iscpa',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(fr: 'Journalisme', en: 'Journalism'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_186',
      institutionId: 'iscpa',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(fr: 'Image&Co', en: 'Image&Co'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_187',
      institutionId: 'iscpa',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
          fr: 'Communication Responsable', en: 'Communication Responsable'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_188',
      institutionId: 'ipi',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(fr: 'Développeur', en: 'Développeur'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_189',
      institutionId: 'ipi',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(fr: 'Infrastructure', en: 'Infrastructure'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
    ProgramModel(
      id: 'prog_190',
      institutionId: 'ipi',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
          fr: 'Systèmes Réseaux Cybersécurité',
          en: 'Systèmes Réseaux Cybersécurité'),
      level: LocalizedText(fr: 'Bac+3 / Bac+5', en: 'Bac+3 / Bac+5'),
      duration: LocalizedText(fr: '3 à 5 ans', en: '3 à 5 ans'),
      tuition: LocalizedText(
          fr: 'Entre 8000€ et 12000€/an', en: 'Entre 8000€ et 12000€/an'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(
            fr: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français',
            en: 'Avoir au moins 11 de moyennes durant les 3 dernières années d\\\'études. Avoir un bon niveau de français')
      ],
    ),
      ProgramModel(
      id: 'prog_s005',
      institutionId: 'hec_paris',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
        fr: "Master in Management (Grande École)",
        en: "Master in Management (Grande École)",
      ),
      level: LocalizedText(fr: "Bac+5", en: "Master's Degree"),
      duration: LocalizedText(fr: "2 ans", en: "2 years"),
      tuition: LocalizedText(
        fr: "24 500 € / an (UE) - 29 800 € / an (Hors UE)",
        en: "24,500 € / year (EU) - 29,800 € / year (Non-EU)",
      ),
      language: LocalizedText(fr: "Anglais", en: "English"),
      requirements: [
        LocalizedText(
          fr: "Diplôme de Licence/Bachelor, score GMAT/GRE ou TAGE MAGE, et niveau d'anglais certifié (TOEFL/IELTS).",
          en: "Bachelor's degree, GMAT/GRE or TAGE MAGE score, and English proficiency certificate (TOEFL/IELTS).",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_s006',
      institutionId: 'essec',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
        fr: "Global BBA (Bachelor in Business Administration)",
        en: "Global BBA (Bachelor in Business Administration)",
      ),
      level: LocalizedText(fr: "Bac+4", en: "Bachelor's Degree"),
      duration: LocalizedText(fr: "4 ans", en: "4 years"),
      tuition: LocalizedText(
        fr: "16 500 € / an",
        en: "16,500 € / year",
      ),
      language: LocalizedText(fr: "Français & Anglais", en: "French & English"),
      requirements: [
        LocalizedText(
          fr: "Diplôme de fin d'études secondaires (Baccalauréat ou équivalent) avec un excellent dossier académique.",
          en: "High school diploma (French Baccalaureate or equivalent) with strong academic records.",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_s007',
      institutionId: 'sciences_po',
      countryId: 'france',
      fieldId: 'd07',
      name: LocalizedText(
        fr: "Master en Affaires Publiques",
        en: "Master in Public Policy",
      ),
      level: LocalizedText(fr: "Bac+5", en: "Master's Degree"),
      duration: LocalizedText(fr: "2 ans", en: "2 years"),
      tuition: LocalizedText(
        fr: "Calculez selon les revenus (0 € à 14 200 € / an)",
        en: "Income-based scaling (0 € to 14,200 € / year)",
      ),
      language: LocalizedText(fr: "Français ou Anglais", en: "French or English"),
      requirements: [
        LocalizedText(
          fr: "Diplôme de Licence / Bachelor ou équivalent et entretien d'admission rigoureux.",
          en: "Bachelor's degree or equivalent and a rigorous admission interview.",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_s008',
      institutionId: 'em_lyon',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
        fr: "MSc in Management - Grande École",
        en: "MSc in Management - Grande École",
      ),
      level: LocalizedText(fr: "Bac+5", en: "Master's Degree"),
      duration: LocalizedText(fr: "2 à 3 ans", en: "2 to 3 years"),
      tuition: LocalizedText(
        fr: "19 500 € / an",
        en: "19,500 € / year",
      ),
      language: LocalizedText(fr: "Anglais & Français", en: "English & French"),
      requirements: [
        LocalizedText(
          fr: "Licence/Bachelor en France ou à l'international, test de logique (GMAT/GRE/TAGE MAGE) et entretien de motivation.",
          en: "Bachelor's degree, logic test (GMAT/GRE/TAGE MAGE), and motivation interview.",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_escp_mim',
      institutionId: 'escp_paris',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
        fr: "Master in Management (Grande École)",
        en: "Master in Management (Grande École)",
      ),
      level: LocalizedText(fr: "Bac+5", en: "Master's Degree"),
      duration: LocalizedText(fr: "2 ans", en: "2 years"),
      tuition: LocalizedText(
        fr: "21 800 € / an",
        en: "21,800 € / year",
      ),
      language: LocalizedText(fr: "Anglais & Français", en: "English & French"),
      requirements: [
        LocalizedText(
          fr: "Licence 3 ou équivalent international, score GMAT/GRE/TAGE MAGE, et excellent niveau en langues.",
          en: "Bachelor's degree or international equivalent, GMAT/GRE/TAGE MAGE score, and excellent language skills.",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_edhec_bba',
      institutionId: 'edhec_bus',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
        fr: "EDHEC International BBA",
        en: "EDHEC International BBA",
      ),
      level: LocalizedText(fr: "Bac+4", en: "Bachelor's Degree"),
      duration: LocalizedText(fr: "4 ans", en: "4 years"),
      tuition: LocalizedText(
        fr: "14 200 € / an",
        en: "14,200 € / year",
      ),
      language: LocalizedText(fr: "100% Anglais ou Bilingue", en: "100% English or Bilingual"),
      requirements: [
        LocalizedText(
          fr: "Baccalauréat ou diplôme d'études secondaires équivalent, dossier académique et test d'anglais certifié.",
          en: "High school diploma or equivalent, academic records, and standardized English test.",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_skema_mim',
      institutionId: 'skema',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
        fr: "Master in Management (Grande École)",
        en: "Master in Management (Grande École)",
      ),
      level: LocalizedText(fr: "Bac+5", en: "Master's Degree"),
      duration: LocalizedText(fr: "2 ans", en: "2 years"),
      tuition: LocalizedText(
        fr: "16 000 € / an",
        en: "16,000 € / year",
      ),
      language: LocalizedText(fr: "Anglais & Français", en: "English & French"),
      requirements: [
        LocalizedText(
          fr: "Diplôme de niveau Licence ou équivalent, score de test d'anglais ou de français selon le parcours de spécialisation.",
          en: "Bachelor's degree or equivalent, English or French proficiency tests depending on the track.",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_epita_cs',
      institutionId: 'epita',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
        fr: "Master of Science in Computer Science",
        en: "Master of Science in Computer Science",
      ),
      level: LocalizedText(fr: "Bac+5", en: "Master's Degree"),
      duration: LocalizedText(fr: "2 ans", en: "2 years"),
      tuition: LocalizedText(
        fr: "10 900 € / an",
        en: "10,900 € / year",
      ),
      language: LocalizedText(fr: "100% Anglais", en: "100% English"),
      requirements: [
        LocalizedText(
          fr: "Bachelor en Informatique, Ingénierie ou Mathématiques avec un bon dossier, test de compétences en anglais.",
          en: "Bachelor's degree in CS, IT, Engineering, or Math, and English test certification.",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_epitech_msc',
      institutionId: 'epitech_paris',
      countryId: 'france',
      fieldId: 'd01',
      name: LocalizedText(
        fr: "MSc Pro - Expert en Technologies de l'Information",
        en: "MSc Pro - Expert in Information Technology",
      ),
      level: LocalizedText(fr: "Bac+5", en: "Master's Degree"),
      duration: LocalizedText(fr: "5 ans (post-Bac) ou 2 ans (post-Bac+3)", en: "5 years (post-HighSchool) or 2 years (post-Bachelor)"),
      tuition: LocalizedText(
        fr: "9 900 € / an",
        en: "9,900 € / year",
      ),
      language: LocalizedText(fr: "Français & Anglais", en: "French & English"),
      requirements: [
        LocalizedText(
          fr: "Passion pour le code, entretien de motivation individuel, et test d'aptitude technique.",
          en: "Strong passion for coding, individual admission interview, and technical aptitude test.",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_rubika_master',
      institutionId: 'rubika_val',
      countryId: 'france',
      fieldId: 'd06',
      name: LocalizedText(
        fr: "Cycle Supérieur - Cinéma d'Animation 3D / VFX / Jeu Vidéo",
        en: "Graduate Program - 3D Animation / VFX / Game Design",
      ),
      level: LocalizedText(fr: "Bac+5", en: "Master's Degree"),
      duration: LocalizedText(fr: "5 ans", en: "5 years"),
      tuition: LocalizedText(
        fr: "9 600 € / an",
        en: "9,600 € / year",
      ),
      language: LocalizedText(fr: "Français", en: "French"),
      requirements: [
        LocalizedText(
          fr: "Présentation d'un portfolio artistique (dessins, modélisations) et entretien individuel de création.",
          en: "Submission of an artistic portfolio (sketching, modeling) and creative interview.",
        ),
      ],
    ),
    ProgramModel(
      id: 'prog_isg_bba',
      institutionId: 'isg_paris',
      countryId: 'france',
      fieldId: 'd02',
      name: LocalizedText(
        fr: "International BBA - Luxe & Management International",
        en: "International BBA - Luxury & International Management",
      ),
      level: LocalizedText(fr: "Bac+4", en: "Bachelor's Degree"),
      duration: LocalizedText(fr: "4 ans", en: "4 years"),
      tuition: LocalizedText(
        fr: "10 800 € / an",
        en: "10,800 € / year",
      ),
      language: LocalizedText(fr: "Anglais", en: "English"),
      requirements: [
        LocalizedText(
          fr: "Baccalauréat ou équivalent international, dossier de candidature, test écrit et entretien de motivation.",
          en: "High school graduation, application folder, written test, and motivation interview.",
        ),
      ],
    ),
];

  static const scholarships = <ScholarshipModel>[];

  static const serviceOffers = <ServiceOffer>[
    ServiceOffer(
      id: 'offer-application-pack',
      name: LocalizedText(
          fr: 'Pack admission guidée', en: 'Guided application pack'),
      offerType: 'application_support',
      destinationIds: ['canada', 'france', 'uk', 'morocco', 'turkey'],
      studyLevels: ['Bac+3', 'Bac+5'],
      priceLabel: LocalizedText(fr: 'Sur devis', en: 'Quoted on request'),
      benefits: [
        LocalizedText(
            fr: 'Qualification du profil et shortlist',
            en: 'Profile qualification and shortlist'),
        LocalizedText(
            fr: 'Support documents et suivi KPB',
            en: 'Document support and KPB follow-up'),
        LocalizedText(
            fr: 'Accès prioritaire aux partenaires KPB',
            en: 'Priority access to KPB partner schools'),
      ],
      ctaLabel: LocalizedText(
          fr: 'Démarrer ma candidature', en: 'Start my application'),
      status: PublicationStatus.published,
    ),
    ServiceOffer(
      id: 'offer-scholarship-boost',
      name: LocalizedText(fr: 'Boost bourse', en: 'Scholarship boost'),
      offerType: 'scholarship_support',
      destinationIds: ['canada', 'france', 'germany', 'turkey', 'uae'],
      studyLevels: ['Bac+3', 'Bac+5', 'Bac+8'],
      priceLabel:
          LocalizedText(fr: 'À partir de 75 000 FCFA', en: 'From 75,000 XOF'),
      benefits: [
        LocalizedText(
            fr: 'Matching bourses personnalisé',
            en: 'Personalised scholarship matching'),
        LocalizedText(
            fr: 'Stratégie de dossier et suivi',
            en: 'Application strategy and follow-up'),
      ],
      ctaLabel: LocalizedText(
          fr: 'Demander un accompagnement', en: 'Request support'),
      status: PublicationStatus.published,
    ),
  ];

  static const supportDestinations = <SupportDestination>[
    SupportDestination(
      id: 'support-canada',
      countryId: 'canada',
      supportLanguages: ['fr', 'en'],
      availableServiceTypes: [
        'consultation',
        'application_support',
        'scholarship_support'
      ],
      conditions: [
        LocalizedText(
            fr: 'Profil académique complet', en: 'Complete academic profile')
      ],
      counselorNames: ['Amina KPB', 'Youssef KPB'],
      isVisible: true,
      status: PublicationStatus.published,
    ),
    SupportDestination(
      id: 'support-france',
      countryId: 'france',
      supportLanguages: ['fr'],
      availableServiceTypes: [
        'consultation',
        'application_support',
        'housing_support'
      ],
      conditions: [
        LocalizedText(
            fr: 'Campus France ou admission directe selon programme',
            en: 'Campus France or direct admission')
      ],
      counselorNames: ['Moussa KPB'],
      isVisible: true,
      status: PublicationStatus.published,
    ),
    SupportDestination(
      id: 'support-morocco',
      countryId: 'morocco',
      supportLanguages: ['fr', 'ar'],
      availableServiceTypes: ['consultation', 'application_support'],
      conditions: [
        LocalizedText(
            fr: 'Dossier académique complet', en: 'Complete academic file')
      ],
      counselorNames: ['Karim KPB'],
      isVisible: true,
      status: PublicationStatus.published,
    ),
    SupportDestination(
      id: 'support-turkey',
      countryId: 'turkey',
      supportLanguages: ['fr', 'en'],
      availableServiceTypes: [
        'consultation',
        'application_support',
        'scholarship_support'
      ],
      conditions: [
        LocalizedText(fr: 'Profil Bac+0 à Bac+3', en: 'Profile Bac+0 to Bac+3')
      ],
      counselorNames: ['Sara KPB'],
      isVisible: true,
      status: PublicationStatus.published,
    ),
  ];

  static final articles = <ArticleModel>[
    ArticleModel(
      id: 'article-canada-budget',
      slug: 'budget-etudes-canada-afrique',
      category: 'guides',
      title: const LocalizedText(
          fr: 'Budget études au Canada pour un étudiant africain',
          en: 'Study budget in Canada for an African student'),
      summary: const LocalizedText(
          fr: 'Frais de scolarité, coût de vie, preuve de fonds et conseils pratiques.',
          en: 'Tuition, living costs, proof of funds, and practical planning tips.'),
      content: const LocalizedText(
          fr: 'Préparez votre budget autour des frais académiques, du logement et de la preuve de fonds.',
          en: 'Build your budget around tuition, housing, and proof-of-funds requirements.'),
      tags: const ['budget', 'canada', 'visa'],
      authorName: 'KPB Editorial',
      status: PublicationStatus.published,
      publishedAt: DateTime(2026, 3, 28, 9),
    ),
    ArticleModel(
      id: 'article-scholarships-2026',
      slug: '5-bourses-afrique-2026',
      category: 'scholarships',
      title: const LocalizedText(
          fr: '5 bourses à surveiller en 2026',
          en: '5 scholarships to watch in 2026'),
      summary: const LocalizedText(
          fr: 'Sélection d\'opportunités Licence et Master avec forte attractivité.',
          en: 'A shortlist of high-value Bachelor and Master opportunities.'),
      content: const LocalizedText(
          fr: 'Repérez les bourses selon votre niveau, pays cible et délais.',
          en: 'Track scholarships by study level, destination country, and timeline.'),
      tags: const ['scholarships', 'deadlines', 'strategy'],
      authorName: 'KPB Editorial',
      status: PublicationStatus.published,
      publishedAt: DateTime(2026, 4, 2, 14),
    ),
    ArticleModel(
      id: 'article-france-campus',
      slug: 'campus-france-guide-complet',
      category: 'guides',
      title: const LocalizedText(
          fr: 'Campus France : le guide complet pour l\'Afrique de l\'Ouest',
          en: 'Campus France: the complete guide for West Africa'),
      summary: const LocalizedText(
          fr: 'Procédure, timing, documents requis et erreurs à éviter.',
          en: 'Process, timing, required documents and mistakes to avoid.'),
      content: const LocalizedText(
          fr: 'Campus France est la porte d\'entrée vers les universités et grandes écoles françaises.',
          en: 'Campus France is the gateway to French universities and grandes écoles.'),
      tags: const ['france', 'campus-france', 'visa'],
      authorName: 'KPB Editorial',
      status: PublicationStatus.published,
      publishedAt: DateTime(2026, 3, 15, 10),
    ),
    ArticleModel(
      id: 'article-turkey-burslari',
      slug: 'bourse-turquie-burslari',
      category: 'scholarships',
      title: const LocalizedText(
          fr: 'Bourse Türkiye Burslari : comment postuler depuis l\'Afrique',
          en: 'Türkiye Burslari Scholarship: how to apply from Africa'),
      summary: const LocalizedText(
          fr: 'Bourse complète incluant frais, logement et billet d\'avion.',
          en: 'Full scholarship including tuition, housing and plane ticket.'),
      content: const LocalizedText(
          fr: 'La bourse Türkiye Burslari est l\'une des plus généreuses pour les étudiants africains.',
          en: 'The Türkiye Burslari scholarship is one of the most generous for African students.'),
      tags: const ['turquie', 'bourse-complete', 'medecine'],
      authorName: 'KPB Editorial',
      status: PublicationStatus.published,
      publishedAt: DateTime(2026, 2, 20, 8),
    ),
  ];

  static const forumCategories = <ForumCategoryModel>[
    ForumCategoryModel(
      id: 'forum-admission',
      label: LocalizedText(
          fr: 'Admissions & Candidatures', en: 'Admissions & Applications'),
      description: LocalizedText(
          fr: 'Démarches, pièces requises, délais et retours d\'expérience.',
          en: 'Application steps, required documents, deadlines and experience sharing.'),
      displayOrder: 1,
      status: PublicationStatus.published,
    ),
    ForumCategoryModel(
      id: 'forum-scholarships',
      label: LocalizedText(
          fr: 'Bourses & Financement', en: 'Scholarships & Funding'),
      description: LocalizedText(
          fr: 'Stratégies de financement, dossiers de bourses et retours.',
          en: 'Funding strategies, scholarship applications and feedback.'),
      displayOrder: 2,
      status: PublicationStatus.published,
    ),
    ForumCategoryModel(
      id: 'forum-visa',
      label: LocalizedText(fr: 'Visa & Immigration', en: 'Visa & Immigration'),
      description: LocalizedText(
          fr: 'Démarches consulaires, refus, recours et témoignages.',
          en: 'Consular procedures, refusals, appeals and testimonials.'),
      displayOrder: 3,
      status: PublicationStatus.published,
    ),
    ForumCategoryModel(
      id: 'forum-logement',
      label: LocalizedText(fr: 'Logement & Arrivée', en: 'Housing & Arrival'),
      description: LocalizedText(
          fr: 'Trouver un logement, s\'installer, les premières semaines.',
          en: 'Finding housing, settling in, the first weeks abroad.'),
      displayOrder: 4,
      status: PublicationStatus.published,
    ),
    ForumCategoryModel(
      id: 'forum-vie-etudiante',
      label: LocalizedText(
          fr: 'Vie Étudiante & Conseils', en: 'Student Life & Tips'),
      description: LocalizedText(
          fr: 'Astuces, entraide et partage d\'expériences entre étudiants.',
          en: 'Tips, mutual support and experience sharing between students.'),
      displayOrder: 5,
      status: PublicationStatus.published,
    ),
  ];

  static const forumTopicTags = <ForumTopicTagModel>[
    ForumTopicTagModel(
        id: 'tag-canada',
        label: LocalizedText(fr: 'Canada', en: 'Canada'),
        description: LocalizedText(
            fr: 'Sujets liés au Canada', en: 'Topics related to Canada'),
        displayOrder: 1,
        status: PublicationStatus.published),
    ForumTopicTagModel(
        id: 'tag-france',
        label: LocalizedText(fr: 'France', en: 'France'),
        description: LocalizedText(
            fr: 'Sujets liés à la France', en: 'Topics related to France'),
        displayOrder: 2,
        status: PublicationStatus.published),
    ForumTopicTagModel(
        id: 'tag-turquie',
        label: LocalizedText(fr: 'Turquie', en: 'Turkey'),
        description: LocalizedText(
            fr: 'Sujets liés à la Turquie', en: 'Topics related to Turkey'),
        displayOrder: 3,
        status: PublicationStatus.published),
    ForumTopicTagModel(
        id: 'tag-bourse-complete',
        label: LocalizedText(fr: 'Bourse complète', en: 'Full scholarship'),
        description: LocalizedText(
            fr: 'Bourses couvrant tous les frais',
            en: 'Scholarships covering all fees'),
        displayOrder: 4,
        status: PublicationStatus.published),
    ForumTopicTagModel(
        id: 'tag-campus-france',
        label: LocalizedText(fr: 'Campus France', en: 'Campus France'),
        description: LocalizedText(
            fr: 'Tout sur les démarches Campus France',
            en: 'Everything about Campus France procedures'),
        displayOrder: 5,
        status: PublicationStatus.published),
    ForumTopicTagModel(
        id: 'tag-visa-refus',
        label: LocalizedText(fr: 'Refus visa', en: 'Visa refusal'),
        description: LocalizedText(
            fr: 'Expériences de refus et recours',
            en: 'Refusal experiences and appeals'),
        displayOrder: 6,
        status: PublicationStatus.published),
  ];

  static List<StudentCase> starterCases() {
    final now = DateTime.now();
    return [
      StudentCase(
        id: 'case-1',
        referenceCode: 'KPB-2026-001',
        type: CaseType.consultation,
        title: const LocalizedText(
            fr: 'Consultation orientation Canada',
            en: 'Canada orientation consultation'),
        description: const LocalizedText(
          fr: 'Premier échange pour clarifier le projet d\'études, le niveau cible et les options de bourses.',
          en: 'Initial consultation to clarify the study plan, target level, and scholarship options.',
        ),
        contextLabel: const LocalizedText(
            fr: 'Canada • orientation + admission',
            en: 'Canada • orientation + admission'),
        status: CaseStatus.counselorAssigned,
        preferredContactMethod: ContactMethod.inApp,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(hours: 6)),
        assignedAdvisorName: 'Amina KPB',
        advisorPhone: '+227 90 00 00 00',
        advisorWhatsapp: '+22790000000',
        nextStepTitle: const LocalizedText(
            fr: 'Préparer votre entretien',
            en: 'Prepare for your consultation'),
        nextStepDescription: const LocalizedText(
          fr: 'Complétez votre profil académique et confirmez votre disponibilité pour mardi 16h.',
          en: 'Complete your academic profile and confirm availability for Tuesday at 4 PM.',
        ),
        timeline: [
          CaseTimelineEvent(
            id: 'evt-1',
            title: const LocalizedText(
                fr: 'Demande reçue', en: 'Request received'),
            description: const LocalizedText(
                fr: 'Votre demande a bien été enregistrée.',
                en: 'Your request has been recorded.'),
            createdAt: now.subtract(const Duration(days: 3)),
            status: CaseStatus.submitted,
          ),
          CaseTimelineEvent(
            id: 'evt-2',
            title: const LocalizedText(
                fr: 'Conseillère assignée', en: 'Counselor assigned'),
            description: const LocalizedText(
                fr: 'Amina suit votre dossier.',
                en: 'Amina is handling your case.'),
            createdAt: now.subtract(const Duration(hours: 6)),
            status: CaseStatus.counselorAssigned,
          ),
        ],
        messages: [
          CaseMessage(
            id: 'msg-1',
            senderName: 'Amina KPB',
            senderRole: 'counselor',
            body: const LocalizedText(
              fr: 'Bonjour, je suis votre conseillère. Pouvez-vous confirmer votre niveau actuel et votre pays cible principal ?',
              en: 'Hello, I am your counselor. Can you confirm your current level and primary target country?',
            ),
            createdAt: now.subtract(const Duration(hours: 5)),
          ),
        ],
        documentRequests: const [
          DocumentRequest(
              id: 'doc-1',
              title: LocalizedText(
                  fr: 'Relevés de notes récents', en: 'Recent transcripts'),
              isProvided: false),
          DocumentRequest(
              id: 'doc-2',
              title: LocalizedText(
                  fr: 'Passeport ou pièce d\'identité', en: 'Passport or ID'),
              isProvided: true),
        ],
      ),
    ];
  }

  static const academyCourses = [
    AcademyCourseModel(
      id: 'c-fulbright',
      title: LocalizedText(
          fr: 'Pack Réussite Fulbright', en: 'Fulbright Success Pack'),
      description: LocalizedText(
        fr: 'Maîtrise chaque étape du programme Fulbright avec nos experts. Inclus : Guide de rédaction du Personal Statement et simulations.',
        en: 'Master every step of the Fulbright program. Includes Personal Statement guide and interview prep.',
      ),
      coverImageUrl:
          'https://images.unsplash.com/photo-1523050853064-87a1a0b3f886',
      priceXOF: 15000,
      priceEUR: 25,
      lessonCount: 5,
    ),
    AcademyCourseModel(
      id: 'c-visa-canada',
      title:
          LocalizedText(fr: 'Objectif Visa Canada', en: 'Mission Canada Visa'),
      description: LocalizedText(
        fr: 'Tout pour votre demande de permis d\'étude : preuve de fonds, lettre d\'explication et documents requis.',
        en: 'Everything for your study permit: financial proof, explanation letter and required docs.',
      ),
      coverImageUrl:
          'https://images.unsplash.com/photo-1550751827-4bd374c3f58b',
      priceXOF: 10000,
      priceEUR: 15,
      lessonCount: 4,
    ),
  ];

  static const academyLessons = {
    'c-fulbright': [
      AcademyLessonModel(
          id: 'l1',
          title: LocalizedText(
              fr: 'Introduction au Fulbright', en: 'Fulbright Intro'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 300,
          order: 1),
      AcademyLessonModel(
          id: 'l2',
          title: LocalizedText(
              fr: 'Rédiger son Personal Statement',
              en: 'Writing Personal Statement'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 600,
          order: 2),
      AcademyLessonModel(
          id: 'l3',
          title: LocalizedText(
              fr: 'Le relevé d\'objectifs d\'étude',
              en: 'Study Objectives Letter'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 450,
          order: 3),
    ],
    'c-visa-canada': [
      AcademyLessonModel(
          id: 'v1',
          title: LocalizedText(fr: 'Le CAQ (Québec)', en: 'CAQ Process'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 400,
          order: 1),
      AcademyLessonModel(
          id: 'v2',
          title: LocalizedText(
              fr: 'Preuves de ressources financières', en: 'Financial Proofs'),
          videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          durationSeconds: 800,
          order: 2),
    ],
  };
}
