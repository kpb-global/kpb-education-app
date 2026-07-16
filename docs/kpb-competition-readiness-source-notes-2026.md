# KPB Education — notes de preuve pour la stratégie concours 2026

Date de revue : 16 juillet 2026  
Périmètre : code et documentation du dépôt local, complétés par les critères officiels publiés par les organisateurs de concours.  
Limite majeure : aucun export de données de production, aucune cohorte pilote et aucun dossier de partenariat signé n'ont été fournis. Les scores ci-dessous évaluent donc la **préparation démontrable dans le dépôt**, pas la traction réelle de KPB.

## Question de décision

Quelles améliorations augmenteraient le plus les chances de KPB Education de remporter des concours EdTech, innovation, IA responsable et impact social ?

## Sources produit vérifiées

| Élément | Source revue | Conclusion bornée |
|---|---|---|
| Proposition produit | `README.md` | Application Africa-first d'orientation, admissions, bourses et accompagnement, avec surfaces Flutter, NestJS et Next.js. |
| Catalogue de bourses | `backend/src/modules/scholarships-index/data/` et commande `npm run scholarships:validate:structure` | Structure valide : 25 opportunités uniques, couvrant 3 opportunités secondaire, 12 Bachelor et 19 Master ; cela ne certifie pas à lui seul la fraîcheur des appels officiels. |
| Parcours de candidature | `backend/prisma/schema.prisma` | Cycles annuels, dates estimées/confirmées, alertes explicites, notifications dédupliquées, étapes de candidature et vidéos YouTube sont modélisés. |
| Matching | `backend/prisma/schema.prisma` et `backend/src/modules/matches/` | Score, zone, version d'algorithme, estimation et explication par facteur sont persistés. |
| IA responsable | `backend/src/modules/coach/coach-prompt.builder.ts` | Minimisation des données, consentement IA séparé, contexte vérifié, fraîcheur des sources et avertissement sur les chiffres non sourcés sont présents. |
| Résilience | `lib/app/core/services/catalog_cache_service.dart`, `connectivity_service.dart`, `sync_telemetry.dart` | Le produit possède des mécanismes de cache, de mode dégradé et d'observabilité de synchronisation ; les performances réelles sur appareils d'entrée de gamme ne sont pas démontrées ici. |
| Impact | `backend/src/modules/impact/impact.service.ts` | Les comptes et avis sont agrégés sans fabriquer de données ; cependant `completedCases` est actuellement exposé comme `admissionsSecured`, ce qui ne prouve pas qu'une admission a réellement été obtenue. |
| Analytics | `docs/analytics-event-contract.md` et `lib/app/core/services/analytics_service.dart` | L'instrumentation couvre orientation, sauvegardes, dossiers, contact conseiller et fiabilité, mais pas le funnel complet bourse → candidature → décision vérifiée. |
| Reporting admin | `backend/src/modules/reports/reports.service.ts` | Le funnel compte inscriptions, dossiers, candidatures soumises et achats, mais pas encore les décisions d'admission ou bourses remportées avec preuve. |

## Critères officiels recoupés

- GESAwards 2026 : douleur marché, innovation pédagogique, expérience, croissance avec modèle durable et viabilité produit. Source : https://www.globaledtechawards.org/
- WISE Prize 2026–2027 : résultats d'apprentissage ou de vie significatifs et mesurables, crédibilité, innovation, faisabilité, scalabilité, durabilité, contextualisation, inclusion et usage responsable de l'IA. Source : https://www.wise-qatar.org/innovation/wise-prize-for-education
- Africa Prize for Engineering Innovation : crédibilité technique, différenciation, viabilité commerciale, passage à l'échelle, impact social/environnemental et capacité d'équipe. Source : https://africaprize.raeng.org.uk/about-the-prize/faq/
- UNESCO ICT in Education Prize 2026 : innovation pédagogique, preuve d'apprentissage, inclusion, voix des apprenants et réplication. Source : https://www.unesco.org/en/prizes/ict-education
- GITEX Africa Supernova Challenge : opportunité de marché, concurrence/scalabilité, modèle économique et capacité de l'équipe ; le pitch doit montrer problème, solution, marché, traction et équipe. Source : https://gitexafrica.com/africa-supernova-challenge

## Rubrique de préparation utilisée dans le rapport

Échelle ordinale, issue d'une revue experte du dépôt :

- 1 : absent ou non démontré ;
- 2 : intention ou composants partiels ;
- 3 : capacité fonctionnelle identifiable, preuve externe insuffisante ;
- 4 : capacité solide et démontrable, validation terrain encore perfectible ;
- 5 : preuve robuste et directement présentable à un jury.

| Critère | Score actuel | Preuve principale | Manque décisif |
|---|---:|---|---|
| Douleur marché et pertinence africaine | 4.0 | Positionnement Africa-first, bourses, budget, orientation et accompagnement | Quantifier le problème sur les marchés pilotes |
| Viabilité produit et profondeur fonctionnelle | 4.0 | Trois surfaces, catalogue, dossiers, notifications, matching, admin | Démonstration publique stable et QA sur appareils réels |
| Confiance et IA responsable | 3.5 | Consentement séparé, données minimisées, contexte sourcé, fraîcheur | Batterie d'évaluations, audit de biais et taux d'erreur publiable |
| Inclusion et faible connectivité | 3.0 | FR/EN, cache, mode dégradé, instrumentation de fallback | Tests 2G/3G, accessibilité complète et langues/voix locales validées |
| Expérience et récit de démonstration | 3.0 | Parcours riches et composants UX nombreux | Un seul parcours héros, test utilisateur et thème cohérent partout |
| Scalabilité et modèle économique | 2.5 | Architecture séparée, paiements/services et opérations admin | Unit economics, coût d'acquisition, marge et stratégie B2B2C prouvés |
| Traction et partenariats | 1.5 | Modèles de partenaires et conseillers présents | Utilisateurs actifs vérifiés, rétention, revenus, lettres d'engagement |
| Impact étudiant mesuré | 1.0 | Tableau d'impact et funnel partiels | Modèle d'outcomes vérifiés ; ne plus assimiler dossier complété et admission |

Ces scores ne sont ni des mesures utilisateurs ni des probabilités de gagner.

## KPI de preuve recommandés

### KPI primaires

1. **Candidatures vérifiées soumises pour 100 chercheurs de bourse actifs**  
   Numérateur : candidatures dont la soumission est attestée pendant le mois.  
   Dénominateur : utilisateurs uniques ayant consulté, sauvegardé ou activé une alerte sur au moins une opportunité éligible pendant le mois.  
   Fenêtre : mensuelle, avec cohorte et pays de résidence.

2. **Taux de décision positive vérifiée**  
   Numérateur : admissions et/ou bourses obtenues avec preuve et consentement.  
   Dénominateur : candidatures soumises dont la décision est connue.  
   Fenêtre : cohorte par cycle de candidature ; afficher séparément admissions et financement.

3. **Progression de préparation à 30 jours**  
   Numérateur : nouveaux utilisateurs ayant complété profil, choisi une opportunité éligible et terminé au moins une étape ou un document dans les 30 jours.  
   Dénominateur : nouveaux utilisateurs ayant déclaré rechercher une bourse.  
   Rôle : indicateur avancé ; ne remplace pas les résultats finaux.

### Indicateurs moteurs

- délai jusqu'au premier match qualifié ;
- taux d'activation de « M'avertir » ;
- taux alerte → fiche → étape commencée ;
- taux de complétion des documents et checklists ;
- délai de première réponse conseiller ;
- rétention de progression à 30 et 90 jours.

### Garde-fous

- taux de bourses périmées ou incorrectes parmi les fiches publiées ;
- taux de réponse IA contenant un fait non soutenu par une source vérifiée ;
- écart de progression entre pays, genre déclaré, type de connexion ou appareil, uniquement avec consentement et seuils de confidentialité ;
- taux de crash et d'échec de synchronisation ;
- incidents de confidentialité, consentement ou protection des mineurs.

## Contrat de la visualisation

- Question : où la préparation concours est-elle forte ou faible ?
- Forme : barres horizontales, une barre par critère, score ordinal de 1 à 5.
- Takeaway : KPB est déjà crédible sur le problème et le produit, mais reste faible sur la preuve d'impact et la traction.
- Palette : une seule racine bleue, libellés directs, axe commun de 0 à 5 ; aucune sémantique rouge/verte.
- Limite : notation experte du dépôt, non mesure de marché.

## Carte du rapport

- Titre
- Executive Summary
- Positionnement gagnant et cible concours immédiate
- État de préparation avec visualisation
- Améliorations prioritaires avec tableau d'exécution
- Système de preuve et KPI
- Démonstration de trois minutes et dossier de concours
- Prochaines étapes 90 jours
- Questions ouvertes
- Caveats et hypothèses

## Validation des conclusions

- Les recommandations ne dépendent d'aucun chiffre de production absent.
- Les capacités sont qualifiées comme présentes dans le code, pas comme validées en production.
- L'inférence « dossier complété = admission » est rejetée explicitement.
- Les critères concours viennent de pages officielles ; les échéances peuvent changer et doivent être reverifiées avant dépôt.
- Les objectifs de pilote proposés dans le rapport sont des seuils de preuve à convenir, pas des benchmarks sectoriels.
