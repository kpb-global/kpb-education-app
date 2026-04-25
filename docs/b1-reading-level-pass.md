# KPB Education — CEFR B1 Reading-Level Pass

**Author:** Content/UX research pass
**Date:** 2026-04-17
**Status:** Research draft — no code changes in this pass
**Next step:** Validate with focus groups in Abidjan and Dakar, then roll edits into `app_translations.dart` and `mock_catalog.dart`.

---

## 1. Context and calibration

CEFR B1 ("intermediate") is the level most realistic for a francophone/anglophone high-school or early-undergraduate student in Côte d'Ivoire or Senegal who is *not yet abroad*. They can read everyday text, follow the main ideas in a slightly longer passage, and handle concrete topics — but they stumble on:

- **Abstract nouns stacked together** ("stratégies de financement", "attractivité", "procédures consulaires").
- **Nominal style** favored in Parisian institutional French ("Préserve les ressources naturelles et développe les énergies du futur pour un monde durable") where a verbal, action-focused sentence reads better.
- **Formal register** verbs ("solliciter", "négocier des traités", "façonner le monde").
- **Jargon or acronyms without expansion** (CAS, JW202, I-20, CAQ, HSK, MEXT, CEDEAO, "preuve de fonds").
- **English copy that is too bureaucratic or US-register** ("facilitated post-study immigration", "proof-of-funds requirements", "simplified visa via Campus France").
- **Idioms / metaphors that don't land in CI/SN** ("porte d'entrée de l'Europe", "forte attractivité", "hub startup européen").

Two cross-cutting findings before the string-level list:

1. **Register mismatch between FR and EN.** The FR tends to sound like a Parisian press release; the EN is a literal translation of it. B1 students read both; the EN version often doesn't feel addressed to them.
2. **Large share of EN strings in `mock_catalog.dart` are not translated at all** — they contain the French string verbatim (e.g. `FieldModel` `d01`–`d12` descriptions, most `subjects`, `careers`, `dailyLife`, several `personalityTraits`, and many `tuitionRange`/`livingCostRange` cost strings). This blocks any B1 review of the English version and is probably worth flagging as a separate data-hygiene task.

---

## 2. Strings above B1 — with proposed rewrites

Format: **Current (FR / EN) → Proposed B1 rewrite.** Lines reference the source file and line number when a single location is representative; otherwise the pattern applies repeatedly across the file.

### 2.1 `lib/app/core/translations/app_translations.dart`

| Key | Current (FR) | Current (EN) | Issue | B1 rewrite (FR) | B1 rewrite (EN) |
|---|---|---|---|---|---|
| [`app_tagline`](lib/app/core/translations/app_translations.dart:8) | Orientation, études à l'étranger et accompagnement pour les étudiants africains. | Orientation, study abroad, and support for African students. | "Accompagnement" is abstract; "study abroad" reads like a brochure. | Trouver sa filière, partir étudier à l'étranger, être aidé à chaque étape. | Find your field, study abroad, and get help at every step. |
| [`onboarding_title`](lib/app/core/translations/app_translations.dart:27) | Construisons votre parcours | Let's build your journey | "Parcours" / "journey" are metaphors students read as corporate. | Créons votre plan d'études | Let's plan your studies |
| [`partner_redirect`](lib/app/core/translations/app_translations.dart:28-29) | Les partenariats sont gérés via un formulaire dédié et un suivi KPB. | Partnerships are handled through a dedicated form and KPB follow-up. | "Gérés via", "dedicated form", "follow-up" are all admin register. | Pour les partenariats, remplissez le formulaire. L'équipe KPB vous répond. | For partnerships, fill in the form. The KPB team will reply to you. |
| [`orientation_intro`](lib/app/core/translations/app_translations.dart:49-50) | Répondez à quelques questions. KPB vous propose des pistes de filières, des pays et des bourses cohérents. | Answer a few questions. KPB will suggest fields, countries, and scholarships that fit your profile. | "Pistes", "cohérents", "that fit your profile" — more abstract than needed. | Réponds à quelques questions. KPB te propose des filières, des pays et des bourses qui te correspondent. | Answer a few questions. KPB will suggest fields, countries, and scholarships that match you. |
| [`why_it_fits`](lib/app/core/translations/app_translations.dart:54) | Pourquoi cela vous correspond | Why this fits you | OK in EN; FR is fine but "cela" is bookish. | Pourquoi ça te correspond | Why it fits you |
| [`parent_support`](lib/app/core/translations/app_translations.dart:80-81) | Comparez les destinations, les coûts et demandez un échange avec un conseiller. | Compare destinations, estimate costs, and request a conversation with an advisor. | "Échange", "request a conversation" are formal; parents in CI/SN expect "parler à quelqu'un". | Comparez les pays et les coûts, puis parlez à un conseiller. | Compare countries and costs, then talk to an advisor. |
| [`partner_support`](lib/app/core/translations/app_translations.dart:82-83) | Présentez votre structure et nous organiserons un échange avec l'équipe KPB. | Share your organization details and we will arrange a follow-up with the KPB team. | "Structure", "arrange a follow-up" = admin French/English. | Parlez-nous de votre organisation. L'équipe KPB vous rappellera. | Tell us about your organization. The KPB team will call you back. |
| [`community_intro`](lib/app/core/translations/app_translations.dart:87-88) | Contenus utiles, catégories forum et sujets à suivre pour avancer plus vite. | Useful content, forum categories, and topics to track as you move forward. | Noun-heavy; "topics to track" and "avancer plus vite" are abstract. | Des articles, des forums et des sujets pour t'aider à avancer. | Articles, forums, and topics to help you move forward. |
| [`grade_range`](lib/app/core/translations/app_translations.dart:23 / 128) | Fourchette académique | Academic range | "Fourchette académique" is unusual; students think "moyenne" or "notes". | Ta moyenne au lycée | Your high-school average |
| [`upload`](lib/app/core/translations/app_translations.dart:64 / 169) | Marquer comme fourni | Mark as provided | "Marquer comme fourni" sounds like a bureaucratic checkbox. | Je l'ai envoyé | I've sent it |
| [`scholarship_interest`](lib/app/core/translations/app_translations.dart:24 / 129) | Je cherche activement une bourse | I am actively looking for scholarships | "Actively" / "activement" reads formal. | Je cherche une bourse | I'm looking for a scholarship |

### 2.2 `lib/app/core/data/mock_catalog.dart` — Orientation questions (lines 8-63)

| Line | Current (FR) | Current (EN) | Issue | B1 rewrite (FR) | B1 rewrite (EN) |
|---|---|---|---|---|---|
| [14](lib/app/core/data/mock_catalog.dart:14) | Résoudre des problèmes avec la technologie | Solving problems with technology | OK. | Résoudre des problèmes grâce à la technologie | Solve problems with technology |
| [15](lib/app/core/data/mock_catalog.dart:15) | Comprendre le commerce et les marchés | Understanding business and markets | "Marchés" is abstract at B1. | Comprendre comment marchent les entreprises et le commerce | Understand how businesses and trade work |
| [17](lib/app/core/data/mock_catalog.dart:17) | Défendre des droits et comprendre les institutions | Defend rights and understand institutions | "Institutions" is abstract; students in CI/SN read it as "gouvernement". | Défendre les droits des gens et comprendre comment l'État fonctionne | Defend people's rights and understand how the state works |
| [27](lib/app/core/data/mock_catalog.dart:27) | Communication, langues et persuasion | Communication, languages and persuasion | "Persuasion" is a C1 word for most students. | Communication, langues et convaincre les autres | Communication, languages, and convincing others |
| [29](lib/app/core/data/mock_catalog.dart:29) | Créativité, design et sens esthétique | Creativity, design and aesthetic sense | "Sens esthétique" is highly abstract. | Créativité, design et le beau | Creativity, design, and a good eye |
| [37](lib/app/core/data/mock_catalog.dart:37) | Trouver un emploi international bien rémunéré | Land a well-paid international job | "Bien rémunéré" is fine; "land a … job" is idiomatic. | Trouver un bon travail à l'international | Get a well-paid international job |
| [40](lib/app/core/data/mock_catalog.dart:40) | Faire de la recherche ou de l'enseignement | Do research or teaching | OK. | Faire de la recherche ou enseigner | Do research or teach |
| [58-60](lib/app/core/data/mock_catalog.dart:58) | Bac+3 — Licence ou Bachelor / Bac+5 — Master ou Grande École / Bac+8 — Doctorat ou PhD | Bachelor degree (3 years) / Master / Grande École (5 years) / PhD / Doctorate (8 years) | "Grande École" won't be read the same way in CI/SN as in Paris; "Bac+X" is fine locally but EN loses it. | (FR unchanged, keep "Bac+3, Bac+5, Bac+8" — it's the local standard) | Bachelor / Licence (3 years) — Master (5 years) — PhD / Doctorate (8 years) |

### 2.3 `mock_catalog.dart` — Field descriptions (lines 65-505)

All twelve field descriptions are single sentences in nominal/poetic style. They skim well but students asked to paraphrase will struggle on the abstract verbs ("façonner", "préserver", "optimiser", "transmettre le savoir"). Pattern rewrite:

| Field | Current (FR) | B1 rewrite (FR) | Current (EN, when translated) | B1 rewrite (EN) |
|---|---|---|---|---|
| [d01 Informatique & IA](lib/app/core/data/mock_catalog.dart:69) | Apprends à coder, créer des intelligences artificielles et sécuriser les systèmes numériques. | Apprends à coder, à créer des IA et à protéger les systèmes informatiques. | *(currently FR)* | Learn to code, build AI, and protect computer systems. |
| [d02 Business & Management](lib/app/core/data/mock_catalog.dart:107) | Pilote des projets, dirige des équipes et développe des entreprises à l'international. | Gère des projets, dirige des équipes et fais grandir des entreprises à l'étranger. | *(currently FR)* | Run projects, lead teams, and grow businesses abroad. |
| [d03 Finance](lib/app/core/data/mock_catalog.dart:145) | Gère les flux financiers, analyse les marchés et conseille les entreprises sur leurs investissements. | Gère l'argent des entreprises, analyse les marchés et conseille pour mieux investir. | *(currently FR)* | Manage company finances, study markets, and advise on investments. |
| [d04 Santé](lib/app/core/data/mock_catalog.dart:183) | Soigne, prévient les maladies et améliore la santé des populations. | Soigne les gens, prévient les maladies et améliore la santé de tous. | *(currently FR)* | Treat patients, prevent illness, and improve public health. |
| [d05 Ingénierie](lib/app/core/data/mock_catalog.dart:220) | Conçois et construis les infrastructures, machines et technologies qui façonnent le monde. | Conçois et construis les routes, machines et technologies qu'on utilise tous les jours. | *(currently FR)* | Design and build the roads, machines, and tech we use every day. |
| [d06 Marketing & Arts](lib/app/core/data/mock_catalog.dart:258) | Crée des messages percutants, développe des marques et exprime ta créativité. | Crée des messages forts, fais grandir des marques et exprime tes idées. | *(currently FR)* | Create strong messages, grow brands, and express your ideas. |
| [d07 Droit](lib/app/core/data/mock_catalog.dart:296) | Défend les droits, négocie des traités et influence les politiques qui gouvernent les nations. | Défends les droits des gens et aide à écrire les lois et les accords entre pays. | *(currently FR)* | Defend people's rights and help write the laws and agreements between countries. |
| [d08 Énergie & Environnement](lib/app/core/data/mock_catalog.dart:334) | Préserve les ressources naturelles et développe les énergies du futur pour un monde durable. | Protège la nature et développe des énergies propres pour un monde qui dure. | *(currently FR)* | Protect nature and develop clean energy for a world that lasts. |
| [d09 Éducation & Sciences Humaines](lib/app/core/data/mock_catalog.dart:372) | Comprends les sociétés humaines, transmet le savoir et accompagne le développement des individus. | Comprends les gens et les sociétés, enseigne et aide les autres à grandir. | *(currently FR)* | Understand people and societies, teach, and help others grow. |
| [d10 Agriculture](lib/app/core/data/mock_catalog.dart:410) | Nourrit les populations en optimisant la production agricole et les filières alimentaires. | Nourris les gens en améliorant la production agricole et la chaîne alimentaire. | *(currently FR)* | Feed people by improving farming and the food supply chain. |
| [d11 Architecture & BTP](lib/app/core/data/mock_catalog.dart:448) | Conçois et bâtis les villes, bâtiments et infrastructures de demain. | Dessine et construis les villes, les bâtiments et les routes de demain. | *(currently FR)* | Design and build tomorrow's cities, buildings, and roads. |
| [d12 Hôtellerie & Tourisme](lib/app/core/data/mock_catalog.dart:485) | Crée des expériences inoubliables dans l'hôtellerie, le tourisme et les industries du luxe. | Accueille les voyageurs et crée des moments forts dans les hôtels, le tourisme et le luxe. | *(currently FR)* | Welcome travelers and create great moments in hotels, tourism, and luxury. |

### 2.4 `mock_catalog.dart` — Country `whyStudy` (lines 507-678)

Consistent issue: compressed clauses separated by commas that read like a listicle. Students paraphrasing will lose half the content.

| Country | Current (FR) | Current (EN) | Issue | B1 rewrite (FR) | B1 rewrite (EN) |
|---|---|---|---|---|---|
| [USA](lib/app/core/data/mock_catalog.dart:511) | Réseau universitaire mondial, diversité de programmes, carrières tech et recherche. | World-class universities, diverse programs, tech and research careers. | Three noun phrases in a row — no verb. | Les meilleures universités du monde, beaucoup de programmes, et des carrières dans la tech et la recherche. | Top universities, many programs, and careers in tech and research. |
| [Canada](lib/app/core/data/mock_catalog.dart:521) | Excellente qualité de vie, parcours francophones et anglophones, immigration facilitée après études. | Excellent quality of life, French and English programs, facilitated post-study immigration. | "Immigration facilitée" / "facilitated post-study immigration" — formal. | Bonne qualité de vie, cours en français et en anglais, et il est plus facile d'y rester après les études. | A good quality of life, classes in French and English, and it's easier to stay after your studies. |
| [France](lib/app/core/data/mock_catalog.dart:531) | Grande qualité académique, coûts réduits dans les universités publiques, visa simplifié via Campus France. | High academic quality, low costs in public universities, simplified visa via Campus France. | "Via Campus France" assumes the reader knows Campus France (most CI/SN students do, but not all). | Bon niveau universitaire, frais bas dans les universités publiques, et le visa passe par Campus France. | Good universities, low fees in public ones, and the visa goes through Campus France. |
| [UK](lib/app/core/data/mock_catalog.dart:541) | Universités classées mondialement, programmes courts et intensifs, carrières finance et tech. | World-ranked universities, short intensive programs, finance and tech careers. | "Classées mondialement" = jargon. | Universités très reconnues, programmes courts, et carrières en finance et en tech. | Highly ranked universities, short programs, and careers in finance and tech. |
| [Germany](lib/app/core/data/mock_catalog.dart:551) | Universités publiques quasi-gratuites, excellence technique, forte demande en ingénieurs. | Nearly free public universities, technical excellence, high demand for engineers. | "Excellence technique" and "forte demande" feel like brochure French. | Universités publiques presque gratuites, très bon niveau en technique, et on cherche beaucoup d'ingénieurs. | Public universities are almost free, strong technical training, and engineers are in demand. |
| [Portugal](lib/app/core/data/mock_catalog.dart:621) | Visa simplifié pour lusophones, coûts de vie bas, hub startup européen, passerelle vers le Brésil. | Simplified visa for Lusophone students, low living costs, European startup hub. | "Hub startup européen", "passerelle" — tech-media French. | Visa plus simple pour ceux qui parlent portugais, vie pas chère, beaucoup de startups, et accès facile vers le Brésil. | An easier visa if you speak Portuguese, low living costs, many startups, and an easy link to Brazil. |
| [Switzerland](lib/app/core/data/mock_catalog.dart:631) | Excellence mondiale (EPFL, ETHZ), salaires post-diplôme parmi les plus élevés d'Europe, trilinguisme. | World excellence (EPFL, ETHZ), top post-grad salaries in Europe, trilingualism. | "Trilinguisme" and "salaires post-diplôme" are nominal/formal. | Universités parmi les meilleures du monde (EPFL, ETHZ), très bons salaires après le diplôme, et on y parle 3 langues. | Top universities in the world (EPFL, ETHZ), high salaries after graduation, and three languages spoken. |
| [Italy](lib/app/core/data/mock_catalog.dart:641) | Bocconi et Politecnico reconnus mondialement, coûts inférieurs à la France, cadre de vie exceptionnel. | Bocconi and Politecnico world-recognized, lower costs than France, exceptional lifestyle. | "Cadre de vie exceptionnel" is vague bourgeois French. | Bocconi et Politecnico connus partout, moins cher que la France, et une belle qualité de vie. | Bocconi and Politecnico are famous, it's cheaper than France, and the lifestyle is great. |
| [China](lib/app/core/data/mock_catalog.dart:591) | Bourses gouvernementales généreuses (HSK), hub technologique mondial, expansion économique. | Generous government scholarships (HSK), global tech hub, economic expansion. | "HSK" without explanation — HSK is a language test, not the scholarship name (likely CSC). Also "hub technologique mondial". | Bourses du gouvernement chinois, un des plus grands centres de technologie au monde, économie qui grandit vite. | Chinese government scholarships, one of the world's biggest tech centers, and a fast-growing economy. |
| [Turkey](lib/app/core/data/mock_catalog.dart:571) | Coûts très abordables, bourse gouvernementale complète (Türkiye Burslari), médecine en anglais. | Very affordable costs, full government scholarship (Türkiye Burslari), medicine in English. | Decent, but "abordables" is slightly formal. | Très pas cher, bourse complète du gouvernement turc (Türkiye Burslari), et études de médecine en anglais. | Very cheap, full Turkish government scholarship (Türkiye Burslari), and medicine taught in English. |
| [Belgium](lib/app/core/data/mock_catalog.dart:611) | Porte d'entrée de l'Europe, coûts inférieurs à la France, programmes en français pour les étudiants d'Afrique francophone. | Gateway to Europe, lower costs than France, French programs for francophone Africa. | "Porte d'entrée" is a metaphor — test if students get it. | Un bon point de départ en Europe, moins cher que la France, et beaucoup de programmes en français. | A good way to enter Europe, cheaper than France, and many programs in French. |

**Visa overview lines** ([514](lib/app/core/data/mock_catalog.dart:514), [544](lib/app/core/data/mock_catalog.dart:544), [594](lib/app/core/data/mock_catalog.dart:594), [664](lib/app/core/data/mock_catalog.dart:664)): the acronyms **I-20, CAS, JW202, CAQ, MEXT** are each dropped without explanation. Expand them once in-line the first time, even at the cost of a few extra words — e.g. `Visa F-1 avec preuve d'argent et I-20 (lettre officielle de l'université).`

### 2.5 `mock_catalog.dart` — Articles, forums, cases (lines 5100-5230)

| Line | Current (FR / EN) | Issue | B1 rewrite (FR / EN) |
|---|---|---|---|
| [5105](lib/app/core/data/mock_catalog.dart:5105) | Frais de scolarité, coût de vie, preuve de fonds et conseils pratiques. / Tuition, living costs, proof of funds, and practical planning tips. | "Preuve de fonds" is a visa-officer term; "proof of funds" is technical. | Frais de scolarité, coût de la vie, compte bancaire à montrer, et conseils pratiques. / Tuition, living costs, the bank balance you must show, and practical tips. |
| [5113](lib/app/core/data/mock_catalog.dart:5113) | Sélection d'opportunités Licence et Master avec forte attractivité. / A shortlist of high-value Bachelor and Master opportunities. | "Forte attractivité", "high-value" — business-school talk. | Des bourses Licence et Master à ne pas manquer. / Bachelor and Master scholarships you should not miss. |
| [5121](lib/app/core/data/mock_catalog.dart:5121) | Procédure, timing, documents requis et erreurs à éviter. / Process, timing, required documents and mistakes to avoid. | "Timing" in FR is English; "required documents" is admin EN. | Les étapes, les dates, les documents à fournir, et les erreurs à éviter. / Steps, dates, documents you need, and mistakes to avoid. |
| [5139](lib/app/core/data/mock_catalog.dart:5139) | Démarches, pièces requises, délais et retours d'expérience. / Application steps, required documents, deadlines and experience sharing. | "Pièces requises", "retours d'expérience" — admin/corporate FR. | Les étapes, les documents à fournir, les dates, et les témoignages d'étudiants. / Steps, documents to send, deadlines, and student stories. |
| [5144](lib/app/core/data/mock_catalog.dart:5144) | Stratégies de financement, dossiers de bourses et retours. / Funding strategies, scholarship applications and feedback. | "Stratégies de financement" is MBA-speak. | Comment payer ses études, préparer son dossier de bourse, et lire les témoignages. / How to pay for your studies, prepare a scholarship file, and read student stories. |
| [5149](lib/app/core/data/mock_catalog.dart:5149) | Démarches consulaires, refus, recours et témoignages. / Consular procedures, refusals, appeals and testimonials. | "Démarches consulaires" / "consular procedures" — legalese. | Comment faire la demande de visa, que faire en cas de refus, et les témoignages. / How to apply for a visa, what to do if it's refused, and real stories. |
| [5154](lib/app/core/data/mock_catalog.dart:5154) | Trouver un logement, s'installer, les premières semaines. / Finding housing, settling in, the first weeks abroad. | OK; "s'installer" is slightly formal. | Trouver un logement, s'installer, et tes premières semaines à l'étranger. / Finding housing, getting settled, and your first weeks abroad. |
| [5182](lib/app/core/data/mock_catalog.dart:5182) | Premier échange pour clarifier le projet d'études, le niveau cible et les options de bourses. / Initial consultation to clarify the study plan, target level, and scholarship options. | "Premier échange", "niveau cible", "initial consultation" — consultant-speak. | Premier rendez-vous pour préciser ton projet, ton niveau visé, et les bourses possibles. / First meeting to clarify your study plan, the level you want, and possible scholarships. |
| [5195](lib/app/core/data/mock_catalog.dart:5195) | Complétez votre profil académique et confirmez votre disponibilité pour mardi 16h. / Complete your academic profile and confirm availability for Tuesday at 4 PM. | "Complétez", "confirmez votre disponibilité" = very formal. | Remplis ton profil et confirme que tu es libre mardi à 16h. / Fill in your profile and confirm you're free Tuesday at 4 PM. |

### 2.6 `mock_catalog.dart` — Academy courses (lines 5233-5257)

| Line | Current | Issue | B1 rewrite |
|---|---|---|---|
| [5238](lib/app/core/data/mock_catalog.dart:5238) | Maîtrise chaque étape du programme Fulbright avec nos experts. | "Maîtrise chaque étape" is B2/C1. | Apprends toutes les étapes du programme Fulbright avec nos experts. / Learn every step of Fulbright with our experts. |
| [5250](lib/app/core/data/mock_catalog.dart:5250) | Tout pour votre demande de permis d'étude : preuve de fonds, lettre d'explication et documents requis. | "Preuve de fonds", "lettre d'explication" — visa jargon unexplained. | Tout pour ta demande de permis d'études : le compte bancaire à montrer, la lettre qui explique ton projet, et les documents à joindre. / Everything for your study-permit application: the bank balance to show, the letter that explains your project, and the documents to attach. |

### 2.7 `lib/app/features/onboarding/onboarding_screen.dart`

| Line | Current | Issue | B1 rewrite |
|---|---|---|---|
| [140](lib/app/features/onboarding/onboarding_screen.dart:140) | Veuillez accepter la politique de confidentialité et les conditions d'utilisation. | Legalese; "veuillez" is formal. | Merci d'accepter la politique de confidentialité et les conditions d'utilisation. |
| [155](lib/app/features/onboarding/onboarding_screen.dart:155) | Choisissez au moins une filière d'intérêt. | "Filière d'intérêt" is school-admin FR. | Choisis au moins une filière qui t'intéresse. |
| [250](lib/app/features/onboarding/onboarding_screen.dart:250) | Créons votre profil KPB Education. | OK. | Créons ton profil KPB Education. *(tutoiement is the single biggest lever — see §2.8)* |
| [279](lib/app/features/onboarding/onboarding_screen.dart:279) | Dites-nous où vous en êtes. | "Où vous en êtes" is idiomatic — test. | Dis-nous à quel niveau tu es. |
| [306](lib/app/features/onboarding/onboarding_screen.dart:306) | Personnalisez vos recommandations. | "Personnalisez" = formal verb. | Adapte tes recommandations à toi. |

### 2.8 `lib/app/features/cases/`

| Line | Current | Issue | B1 rewrite |
|---|---|---|---|
| [case_composer_sheet.dart:64](lib/app/features/cases/case_composer_sheet.dart:64) | Tell KPB what you need, what stage you are in, and what outcome you want. | "Outcome" is B2; three clauses. | Tell KPB what you need, where you are in your project, and what you want to happen. / Dis à KPB ce dont tu as besoin, où tu en es dans ton projet, et ce que tu veux obtenir. |
| [case_composer_sheet.dart:97](lib/app/features/cases/case_composer_sheet.dart:97) | Need support for ${widget.title} | "Need support" is admin EN and — problematically — this fallback is hard-coded in English only, so it will appear in a francophone student's FR-locale app. | Make this localised. FR fallback: `J'ai besoin d'aide pour ${widget.title}`. EN fallback: `I need help with ${widget.title}`. |
| [cases_screen.dart:122](lib/app/features/cases/cases_screen.dart:122) | Créez votre premier dossier pour démarrer votre accompagnement KPB. | "Démarrer votre accompagnement" = corporate. | Crée ton premier dossier pour commencer avec KPB. |
| [case_detail_screen.dart:540](lib/app/features/cases/case_detail_screen.dart:540) | Documents requis | Admin FR; "à fournir" is softer. | Documents à envoyer |
| [case_detail_screen.dart:552](lib/app/features/cases/case_detail_screen.dart:552) | En attente de décision | OK but bureaucratic. | On attend la réponse |
| [case_detail_screen.dart:393](lib/app/features/cases/case_detail_screen.dart:393) | Envoyez un message à votre conseiller. | Vous-form + formal. | Écris un message à ton conseiller. |

### 2.9 `lib/app/features/community/`

| Line | Current | Issue | B1 rewrite |
|---|---|---|---|
| [community_screen.dart:103](lib/app/features/community/community_screen.dart:103) | Articles, guides et conseils de nos experts pour réussir votre projet d'études. | Noun-heavy. | Des articles, des guides et des conseils d'experts pour réussir tes études. |
| [forum_category_screen.dart:275](lib/app/features/community/forum_category_screen.dart:275) | The in-app forum is launching soon. Connect on WhatsApp to discuss with other students and KPB counselors now. | "In-app forum is launching", "connect on WhatsApp to discuss" — tech/marketing EN. | The forum in the app is coming soon. Join us on WhatsApp to talk with other students and KPB counselors right now. |
| [forum_category_screen.dart:177](lib/app/features/community/forum_category_screen.dart:177) | Aucun article marqué pour l'instant. Rejoins le groupe WhatsApp pour poser tes questions. | OK — already tutoiement. | (Keep as-is; this is the voice we want elsewhere.) |

### 2.10 Cross-cutting recommendations

1. **Move to `tu` / informal "you" across student-facing copy.** Half the app already uses `tu` (community, forum join CTA, document rejection messages), half uses `vous` (onboarding, case-creation empty state, case detail). Students under ~25 in both CI and SN read `tu` as "talking to me" and `vous` as "talking to my parents/administration". This single change carries more B1 impact than any individual rewrite. Flag it for the focus group explicitly.
2. **Drop acronyms on first mention, or expand them in parentheses.** I-20, CAS, JW202, CAQ, MEXT, HSK, CEDEAO all currently appear once without gloss.
3. **Stop stacking three noun phrases with commas.** Replace with one sentence that has a verb.
4. **Localize fallbacks.** Several fallback strings (e.g. `case_composer_sheet.dart:97`) are hard-coded English and will appear in a French UI.
5. **Fix un-translated EN entries in `mock_catalog.dart`.** `FieldModel` descriptions, subjects, careers, dailyLife, and several country ranges contain French strings in the `en:` slot. This is a blocker for the English B1 pass — roughly 40% of EN catalog strings are actually French.
6. **Idioms to test specifically in CI/SN:** "porte d'entrée de l'Europe" (Belgium), "façonnent le monde" (Engineering), "percutants" (Marketing), "parcours" (used everywhere), "échange" for a meeting, "accompagnement" (used throughout — probably reads as KPB-jargon to students on first exposure).

---

## 3. Focus-group script (Abidjan & Dakar)

**Format:** 60-minute sessions, 6 students per group. Two groups per city (one FR-dominant lycée, one mixed bilingual/anglophone university). Facilitator + note-taker. Record audio with consent. Each student has the app installed on their own phone or gets a test device.

**Opening (5 min):** warm intros, ages, school/faculty, how often they use apps in French vs English. No KPB branding emphasis — we want honest reactions.

### Question 1 — Orientation intro (reading aloud, 10 min)
Show [`orientation_intro`](lib/app/core/translations/app_translations.dart:49) and the first two orientation questions ([lines 8-32](lib/app/core/data/mock_catalog.dart:8)).
- *Prompt:* "Lis cet écran à voix haute, comme si tu le lisais pour la première fois. Puis explique-moi avec tes mots ce qu'on te demande de faire."
- *Watch for:* hesitations on "pistes", "cohérents", "persuasion", "sens esthétique". Note where the student paraphrases correctly vs where they guess or skip.

### Question 2 — Country page (paraphrase test, 10 min)
Show three country cards in the app (France, Turkey, Belgium). Student picks one and reads `whyStudy`, `visaOverview`, `tuitionRange` aloud.
- *Prompt:* "Explique-moi ce pays comme si tu le présentais à un ami qui n'a jamais pensé à partir étudier là-bas."
- *Watch for:* whether they explain the acronyms (Campus France, I-20, CAS); whether they understand "immigration facilitée", "porte d'entrée", "hub startup", "forte attractivité"; whether they notice the cost ranges aren't localised into their currency.

### Question 3 — Field description (matching test, 8 min)
Show the 12 field cards. Ask the student to pick two fields that sound interesting and read the `description` and `dailyLife` aloud.
- *Prompt:* "Avec ce que tu viens de lire, quelles matières tu penses qu'il faudra étudier au lycée pour faire ça ? Qu'est-ce que tu ferais au quotidien dans ce métier ?"
- *Watch for:* whether the description actually helps them connect to real jobs, or whether it's just poetic noise. Abstract verbs like "façonner", "optimiser", "préserver" are the prime suspects.

### Question 4 — Case creation (task + voice test, 10 min)
Ask the student to imagine they need help preparing for Campus France. Walk them through creating a case.
- *Prompt:* "Ouvre le bouton 'Créer un dossier' et raconte-moi ce que tu lis à chaque étape. S'il y a un mot que tu ne dirais jamais à un ami, arrête-toi et dis-le-moi."
- *Watch for:* reactions to `vous`/`tu` mix, to "Marquer comme fourni", "démarrer votre accompagnement", "En attente de décision", and whether "Tell KPB what you need…" feels like something an older sibling would say or a form.

### Question 5 — Forum categories (scan test, 8 min)
Open the Community screen and show the five forum categories + the "Join the conversation" block.
- *Prompt:* "Si tu as une question sur ton visa refusé, où tu cliques ? Et sur ton premier logement à Istanbul ?"
- *Watch for:* whether "Démarches consulaires, refus, recours et témoignages" helps or hurts category selection. Do they prefer the tutoiement copy or the vouvoiement copy when they see both side by side?

### Question 6 — Tone & trust (direct feedback, 9 min)
Open two screens side by side: the onboarding intro (vouvoiement) and the forum WhatsApp CTA (tutoiement).
- *Prompt:* "Laquelle de ces deux voix te parle le plus ? Pourquoi ? Est-ce que ça te donne envie de faire confiance à KPB ?"
- *Bonus:* "Y a-t-il un mot ou une phrase dans l'app qui, à ton avis, a été écrite pour un étudiant à Paris et pas pour toi ?"

**Wrap (5 min):** thank-you, per-diem / airtime incentive, ask if they'd be willing to be recontacted for a second-round validation.

---

## 4. Recruitment, scheduling, and edit rollout

### 4.1 Partners and recruitment channels

**Abidjan**
- Lycée Classique d'Abidjan and Lycée Sainte-Marie (terminale cohort, FR-dominant).
- INP-HB and Université Félix Houphouët-Boigny (L1-L2 students).
- AIESEC Côte d'Ivoire and Jeune Chambre Internationale Abidjan for student-association recruitment.
- KPB's existing alumni WhatsApp groups for Canada, France and Turkey — warm pipeline, easy to reach six motivated students fast.

**Dakar**
- Lycée Blaise Diagne, Lycée Galandou Diouf.
- UCAD, UGB, ISM (mixed cohort, L1-M1).
- Campus France Dakar alumni network (warm, already in the funnel for study-abroad language).
- WhatsApp groups: "Étudiants Sénégal 🇸🇳", "Bac 2026 Dakar", KPB partner groups.

**Recruitment flow (WhatsApp-first, mirroring how students actually talk):**
1. Draft a short FR recruitment message (7-8 lines max, conversational). Include: what we're doing, 60-min commitment, 5 000 FCFA / 10 000 FCFA per-diem or mobile-money credit, consent to record.
2. Post in 6-8 WhatsApp groups per city via partner champions (1 champion per group so the message isn't cold spam).
3. Screen respondents with a 4-question Google Form: city, level, current/target country of study, language comfort (FR only / bilingual / EN dominant). Aim for 2 FR-only + 3 bilingual + 1 EN-dominant per group.
4. Confirm slots over WhatsApp 48h before. No-show buffer: over-book by 2.

### 4.2 Timeline (4 weeks from today)

| Week | Dates | Deliverable |
|---|---|---|
| Week 1 | 2026-04-20 → 2026-04-24 | Finalize discussion guide; set up consent form; align with 2 partner champions per city; send recruitment posts. |
| Week 2 | 2026-04-27 → 2026-05-01 | Run 2 sessions in Abidjan (Tue/Wed), 2 in Dakar (Thu/Fri). Transcribe audio nightly. |
| Week 3 | 2026-05-04 → 2026-05-08 | Synthesis: tag each string in §2 as **kept / rewrite-accepted / rewrite-rejected / needs-new-draft**. Draft v2 of the rewrite table. |
| Week 4 | 2026-05-11 → 2026-05-15 | Open PR with edits to `app_translations.dart` (low-risk strings first: nav, CTAs, short labels). Second PR for `mock_catalog.dart` (field + country descriptions). Keep each PR under ~60 string changes so review is tractable. Second round of async validation via WhatsApp (send 3 screenshots to 10 students, ask "is there a word you don't get?"). |

### 4.3 Rollout principles

- **Don't batch everything into one giant diff.** Three PRs: (1) `app_translations.dart` + tutoiement switch, (2) field + country descriptions, (3) articles + cases + forum copy.
- **Ship a style guide alongside PR 1** covering: tutoiement default, acronym-on-first-mention rule, "one verb per sentence" heuristic, banned phrase list ("accompagnement", "démarches consulaires", "forte attractivité", "parcours"). Save it at `docs/voice-guide.md`.
- **Fix the untranslated EN catalog entries in parallel** (separate task): this is a data-hygiene fix, not a B1 rewrite, and shouldn't wait on focus-group output.
- **Validate with a 10-student WhatsApp re-test before merging PR 2** — catalog copy has the biggest surface area and the highest risk of re-introducing B2 phrasing if we rewrite from Paris instead of from Abidjan/Dakar.

---

## 5. Open questions for the team

1. Do we commit to `tu` across the student surface? (Strong recommend: yes. Parent surface stays `vous`.)
2. Are cost ranges (USD/EUR/CHF) acceptable to leave unlocalised into FCFA, or should we show an FCFA approximation next to the foreign-currency figure? Worth asking in focus groups.
3. Is "KPB Editorial" the author we want on articles, or should we sign with a human name? Students in both cities consistently trust a named human byline more than a brand byline.
4. Can we split the English translation pass from this B1 pass? They're different problems and blocking each other in the current catalog.
