# Attacher une vidéo d'explication à une bourse

Vérifié de bout en bout le 29/08/2026 : chaîne de code lue, routes sondées sur
la production, aller-retour joué contre la vraie base, et quatre tests
d'intégration ajoutés pour que la chaîne reste tenue
(`scholarships-public-reads.postgres.spec.ts`).

## La chaîne, telle qu'elle existe

| Maillon | Où |
|---|---|
| Formulaire | `ScholarshipVideosEditor`, dans la fiche bourse de l'admin |
| Écriture | `POST /admin/catalog/scholarships/:id/videos` |
| Stockage | table `ScholarshipVideo` |
| Lecture app | `GET /scholarships` (`featuredVideo`) et `GET /scholarships/:id` (`videos`) |
| Affichage | section vidéos de la fiche, puis lecteur dédié |

Les quatre routes admin répondent **401** en production — elles existent et
exigent une session. L'état `unavailable` du formulaire (404/405/501) ne se
déclenchera pas.

## Ce qu'on colle dans le champ

N'importe laquelle de ces formes ; l'admin la normalise et le serveur en extrait
l'identifiant de 11 caractères :

- `https://youtu.be/dQw4w9WgXcQ` (bouton « Partager » de YouTube)
- `https://www.youtube.com/watch?v=dQw4w9WgXcQ`
- `https://www.youtube.com/embed/…`, `/shorts/…`, `/live/…`
- l'identifiant nu : `dQw4w9WgXcQ`

Hors YouTube, rien ne passe : le serveur n'accepte que `youtube.com` et
`youtu.be`, en HTTPS. **Une vidéo NotebookLM doit donc d'abord être déposée sur
YouTube** — « non répertoriée » suffit, elle reste hors des recherches et des
suggestions tout en étant lisible par lien.

## Les deux façons de perdre une vidéo

**1. Le statut.** La base crée en `draft` par défaut ; le formulaire, lui,
propose **« publié »** d'emblée. Une vidéo laissée en brouillon est écrite,
visible dans l'admin, et **jamais servie à l'app**. C'est silencieux : rien ne
signale l'écart.

**2. La bourse elle-même.** Le piège principal, et il est mesuré : au 29/08/2026,
**10 fiches sur 45 sont servies au public**. Une bourse n'est visible que si elle
est active, approuvée, horodatée comme vérifiée, et pas encore échue. Une vidéo
publiée sur l'une des 35 autres est correctement enregistrée et **n'apparaîtra
nulle part** — pas à cause de la vidéo, à cause de la fiche.

Les 10 fiches actuellement servies :

Chevening 2027-2028 · Lester B. Pearson 2027 · TaiwanICDF 2027 ·
ETH Zurich ESOP 2027-2028 · Knight-Hennessy 2027 · Open Doors Russie 2027 ·
Schwarzman Scholars 2027-2028 · UWC Burkina Faso · UWC Kenya ·
University of Pretoria — Mastercard Foundation 2027

(McCall MacBain 2027 est approuvée mais sa date limite est passée : elle sort
des listes tant que le cycle n'est pas rouvert.)

## Le reste du comportement, vérifié

- **Une seule mise en avant, en édition séquentielle.** Cocher « mise en avant »
  sur une nouvelle vidéo retire la coche de la précédente, dans la même
  transaction. Aucun index unique ne l'impose en base, cependant : deux
  personnes qui mettraient en avant deux vidéos *exactement* en même temps
  pourraient laisser deux coches — la lecture publique trancherait alors sur
  `displayOrder`. Sans conséquence à un seul rédacteur, à savoir si l'équipe
  éditoriale grandit.
- **Pas de doublon.** Le même identifiant YouTube deux fois sur la même bourse
  est refusé par une contrainte d'unicité en base — l'API répond 409.
- **Ordre d'affichage** : mise en avant d'abord, puis `displayOrder` croissant.
- **Vignette** : déduite de l'identifiant si on n'en fournit pas.
- **Titre EN** : si on le laisse vide, le titre FR est recopié.

## Où ça se voit dans l'admin

Page **Bourses**, filtre de statut sur **approuvées** (les fiches servies au
public y sont), puis la fiche à ouvrir. Le bloc vidéos est en bas de la fiche.
