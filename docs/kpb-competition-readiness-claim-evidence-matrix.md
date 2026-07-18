# KPB Competition Readiness — matrice claim → preuve

Dernière mise à jour : 18 juillet 2026

Cette matrice est le gate éditorial avant pitch, dossier de concours, site ou
publication d'impact. Une cellule vide interdit la publication de la claim.
Les équipes ne remplacent jamais une donnée manquante par une estimation
présentée comme un résultat observé.

## Statuts

- `draft` : formulation interne, non publiable ;
- `measured` : calcul reproductible, contrôles qualité effectués ;
- `verified` : snapshot gelé, seconde revue, sources traçables ;
- `approved` : formulation et périmètre approuvés pour le canal indiqué ;
- `expired` : période/source trop ancienne ou accord arrivé à échéance.

## Registre

| ID | Claim exacte | Population et période | Définition/méthode | Snapshot | Couverture de preuve | Seuil petite cellule | Accord/permission | Relecteurs | Statut | Date d'expiration |
| --- | --- | --- | --- | --- | ---: | ---: | --- | --- | --- | --- |
| CR-C001 | _À renseigner_ | _À renseigner_ | version de métrique | ID + SHA-256 | % | ≥ 20 public | ID/révision active | impact + privacy | draft | date |

## Règles par famille de claim

| Famille | Source autorisée | Interdit |
| --- | --- | --- |
| Étudiants accompagnés | adhésion cohorte/usage borné et dédupliqué | téléchargements ou comptes comme accompagnement |
| Candidatures soumises | `ApplicationSubmission` avec preuve et statut attendu | workspace créé, tâche cochée ou `Case.completed` |
| Admissions obtenues | décision d'admission courante `verified` | auto-déclaration non vérifiée ou dossier KPB terminé |
| Financements/bourses gagnés | décision de financement courante `verified` | admission seule, montant demandé ou promesse |
| Partenaires | révision d'accord active autorisant explicitement la claim | `Institution.isPartner`, logo ou échange commercial |
| Amélioration pédagogique | protocole, baseline/follow-up et analyse explicitée | causalité déduite d'un pilote non randomisé |
| IA | eval versionnée, coût et taux fallback réconciliés | « garantit la réussite », score non validé ou conseil illimité |
| Notifications | acceptation fournisseur et livraison appareil séparées | acceptation fournisseur présentée comme notification reçue |

## Checklist de publication

- [ ] formulation identique à celle du support public ;
- [ ] métrique et période figées, unité et dénominateur visibles ;
- [ ] seules les décisions vérifiées contribuent aux outcomes revendiqués ;
- [ ] couverture de preuve et données manquantes communiquées ;
- [ ] cellules publiques inférieures à 20 supprimées ou regroupées sans
      ré-identification ;
- [ ] aucun identifiant, document, URL signée ou clé de stockage dans l'export ;
- [ ] accord actif au jour de publication pour tout partenaire nommé ;
- [ ] limites méthodologiques et distinction association/causalité explicites ;
- [ ] snapshot, manifest et export ont des empreintes vérifiées ;
- [ ] deux relecteurs distincts ont approuvé ;
- [ ] date d'expiration et owner de retrait sont renseignés.

## Formulations sûres tant que le suivi est jeune

Préférer « participants au pilote », « dossiers préparés », « soumissions
vérifiées » ou « faisabilité observée sur la période… ». Réserver « admissions
obtenues » et « financements remportés » aux décisions institutionnelles
vérifiées. Ne parler d'effet causal que si le protocole, l'assignation et
l'analyse le permettent ; sinon parler d'association ou de signal préliminaire.

## Archivage

Chaque version approuvée est exportée avec : contenu canonique, snapshot ID,
hash du manifest, IDs/révisions d'accord, définition de métrique, requête ou
version de code, date, relecteurs et canal. Le fichier public est régénérable
sans accès aux données identifiantes.
