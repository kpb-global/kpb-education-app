#!/usr/bin/env python3
"""Vérifie les CAPACITÉS annoncées par /api/health, pas seulement son statut.

`live` et `ready` ont répondu 200 pendant les vingt jours où clamd était mort
dans `kpb_clamav` : le processus vivait, PostgreSQL répondait, et pourtant
aucun envoi de fichier ne passait — `AntivirusService` est fail-closed et
rendait 503 sur chaque document de dossier, chaque avatar, chaque pièce du
Success Lab. Une sonde qui demande seulement « le service répond-il ? » ne peut
pas voir cette classe de panne.

Script séparé, et non un bloc `run:` : la vérification tient en quelques
règles qui méritent d'être exercées hors ligne (`check_health_capabilities_test`),
et un heredoc Python imbriqué dans du YAML indenté ne s'exécute pas — le
terminateur doit être en colonne 0, ce qui est intenable dans un `run:`.

Lit le corps JSON sur stdin. Sort 0 si tout va bien, 1 sinon.
"""

import json
import sys


def verdicts(body):
    """Rend (code_de_sortie, [lignes]). Pur : testable sans réseau."""
    lines = []

    try:
        health = json.loads(body)
    except (ValueError, TypeError):
        return 1, ["::error::/api/health n'a pas rendu du JSON — sonde inopérante."]

    if not isinstance(health, dict):
        return 1, ["::error::/api/health n'a pas rendu un objet JSON."]

    antivirus = health.get("antivirus")
    if antivirus is None:
        # Un champ ABSENT doit échouer bruyamment. Le traiter comme « rien à
        # signaler » ferait passer un déploiement trop ancien — celui qui ne
        # sait pas encore rapporter l'antivirus — pour un service sain.
        return 1, [
            "::error::/api/health ne rapporte pas `antivirus` : sonde "
            "inopérante, ce qui n'est PAS la même chose qu'un service sain. "
            "Le backend déployé est-il antérieur à cette sonde ?"
        ]

    configured = bool(antivirus.get("configured"))
    reachable = bool(antivirus.get("reachable"))

    # Asymétrie voulue : `configured: false` est un CHOIX de déploiement (les
    # fichiers passent sans analyse — discutable, mais délibéré et visible
    # ailleurs). `configured: true` + `reachable: false` est une panne : la
    # seule combinaison qui REFUSE silencieusement le travail des utilisateurs.
    if configured and not reachable:
        return 1, [
            "::error::ClamAV est configuré mais INJOIGNABLE : tout envoi de "
            "fichier est refusé en 503 (fail-closed) — documents de dossier, "
            "avatars, pièces du Success Lab. Réparer avec "
            "vps-ops → restart-clamav, puis vérifier la limite mémoire."
        ]

    lines.append("antivirus ✅" if reachable else "antivirus non configuré (choix de déploiement)")
    return 0, lines


def main():
    code, lines = verdicts(sys.stdin.read())
    for line in lines:
        print(line)
    return code


if __name__ == "__main__":
    sys.exit(main())
