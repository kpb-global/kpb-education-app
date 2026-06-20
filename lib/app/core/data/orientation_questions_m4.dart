import '../models/app_models.dart';

/// M4 extension — questions 6–10 (spec §5.4).
const orientationQuestionsM4Extension = <OrientationQuestion>[
  OrientationQuestion(
    id: 'ai_concern',
    prompt: LocalizedText(
      fr: 'L’intelligence artificielle te préoccupe-t-elle pour ton futur métier ?',
      en: 'Are you concerned about AI affecting your future career?',
    ),
    options: [
      OrientationOption(
        id: 'ai_yes',
        label: LocalizedText(
          fr: 'Oui — je veux un métier résilient à l’IA',
          en: 'Yes — I want an AI-resilient career',
        ),
        weights: {'d01': 3, 'd03': 3, 'd04': 2, 'd07': 2},
      ),
      OrientationOption(
        id: 'ai_no',
        label: LocalizedText(
          fr: 'Non — ce n’est pas mon critère principal',
          en: 'No — not my main criterion',
        ),
        weights: {'d10': 2, 'd06': 1},
      ),
    ],
  ),
  OrientationQuestion(
    id: 'languages',
    prompt: LocalizedText(
      fr: 'Dans quelle langue aimerais-tu étudier ?',
      en: 'Which language would you like to study in?',
    ),
    options: [
      OrientationOption(
        id: 'lang_en',
        label: LocalizedText(fr: 'Anglais', en: 'English'),
        weights: {'d01': 3, 'd02': 2, 'd03': 2, 'd07': 2},
      ),
      OrientationOption(
        id: 'lang_fr',
        label: LocalizedText(fr: 'Français', en: 'French'),
        weights: {'d02': 2, 'd04': 2, 'd09': 2},
      ),
      OrientationOption(
        id: 'lang_both',
        label: LocalizedText(fr: 'Bilingue FR/EN', en: 'Bilingual FR/EN'),
        weights: {'d02': 2, 'd01': 2, 'd07': 2},
      ),
    ],
  ),
  OrientationQuestion(
    id: 'avoid',
    prompt: LocalizedText(
      fr: 'Qu’est-ce que tu ne voudrais surtout PAS faire ?',
      en: 'What would you definitely NOT want to do?',
    ),
    options: [
      OrientationOption(
        id: 'avoid_sales',
        label: LocalizedText(
          fr: 'Vente / négociation commerciale',
          en: 'Sales / commercial negotiation',
        ),
        weights: {'d02': -2},
      ),
      OrientationOption(
        id: 'avoid_lab',
        label: LocalizedText(
          fr: 'Laboratoire / soins cliniques',
          en: 'Lab work / clinical care',
        ),
        weights: {'d04': -2, 'd03': -1},
      ),
      OrientationOption(
        id: 'avoid_desk',
        label: LocalizedText(
          fr: 'Bureau / écran toute la journée',
          en: 'Desk / screen all day',
        ),
        weights: {'d01': -1, 'd02': -1},
      ),
    ],
  ),
  OrientationQuestion(
    id: 'budget_band',
    prompt: LocalizedText(
      fr: 'Quel budget annuel peux-tu envisager pour les frais de scolarité ?',
      en: 'What annual tuition budget can you consider?',
    ),
    options: [
      OrientationOption(
        id: 'budget_low',
        label: LocalizedText(fr: 'Moins de 5 000 €/an', en: 'Under €5,000/year'),
        weights: {'d09': 2, 'd08': 2, 'd12': 2},
      ),
      OrientationOption(
        id: 'budget_mid',
        label: LocalizedText(fr: '5 000 – 12 000 €/an', en: '€5,000–12,000/year'),
        weights: {'d02': 2, 'd06': 2, 'd03': 1},
      ),
      OrientationOption(
        id: 'budget_high',
        label: LocalizedText(fr: 'Plus de 12 000 €/an', en: 'Over €12,000/year'),
        weights: {'d01': 2, 'd04': 2, 'd07': 2},
      ),
    ],
  ),
  OrientationQuestion(
    id: 'mobility',
    prompt: LocalizedText(
      fr: 'Es-tu prêt(e) à étudier à l’étranger ?',
      en: 'Are you ready to study abroad?',
    ),
    options: [
      OrientationOption(
        id: 'mobility_yes',
        label: LocalizedText(fr: 'Oui, c’est mon objectif', en: 'Yes, that’s my goal'),
        weights: {'d07': 2, 'd12': 2, 'd02': 1},
      ),
      OrientationOption(
        id: 'mobility_maybe',
        label: LocalizedText(fr: 'Peut-être, selon les bourses', en: 'Maybe, depending on scholarships'),
        weights: {'d02': 1, 'd09': 1},
      ),
      OrientationOption(
        id: 'mobility_no',
        label: LocalizedText(fr: 'Plutôt rester proche', en: 'Prefer to stay close'),
        weights: {'d09': 2, 'd10': 1},
      ),
    ],
  ),
];
