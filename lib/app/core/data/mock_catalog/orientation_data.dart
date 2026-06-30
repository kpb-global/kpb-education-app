// AUTO-GENERATED — KPB Education catalog seed data.
// ignore_for_file: lines_longer_than_80_chars
import '../../models/app_models.dart';

const kOrientationQuestions = <OrientationQuestion>[
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
