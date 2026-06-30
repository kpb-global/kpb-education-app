# Catalogue Verification SOP

KPB-47 turns the verification badge into an operational promise: every sensitive catalogue row must carry a recent source, a timestamp, and the admin who checked it.

## Cadence And Ownership

| Category | Rows | Cadence | Owner |
| --- | --- | --- | --- |
| Pays: visa, coûts et difficulté admission | `Country` | 30 days | Amina KPB |
| Établissements: frais, niveaux et exigences | `Institution` | 180 days | Fatou Admin |
| Formations: frais, durée, langue et prérequis | `Program` | 180 days | Fatou Admin |
| Bourses: deadlines, financement et éligibilité | `Scholarship` | 30 days | Amina KPB |

## Workflow

1. Open the admin verification queue at `/verification`.
2. Review rows due for re-check, starting with missing source links and never-verified rows.
3. Edit the row in the relevant catalogue section using the official source.
4. Save the row. The admin API records `lastVerifiedAt`, `verifiedById`, `verifiedByName`, and `verificationSourceUrl`.
5. If a source is unavailable, leave the row inactive or update the public copy so it does not overpromise.

## Source Standard

Use official school, government, scholarship, Campus France, embassy, or partner pages. Avoid aggregator pages unless no official source exists and the row is explicitly marked for follow-up.
