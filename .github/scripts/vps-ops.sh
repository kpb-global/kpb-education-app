#!/usr/bin/env bash
# Opérations de production, liste FERMÉE. Voir .github/workflows/vps-ops.yml
# pour le pourquoi. Ce script ne lit aucune commande depuis l'extérieur :
# `ACTION` est comparé à quatre littéraux et rien d'autre n'est exécuté.
#
# Aucune valeur de secret n'est affichée. Le `.env` n'est jamais imprimé — on
# n'en montre que les trois clés KPB_EEF_*, qui sont des drapeaux publics.
set -euo pipefail

: "${VPS_PATH:?VPS_PATH manquant}"
: "${ACTION:?ACTION manquante}"
DRY_RUN="${DRY_RUN:-true}"

cd "$VPS_PATH"

# ── Garde-fou : sans le relais dans compose, écrire le .env n'a AUCUN effet ──
# C'est exactement le défaut mesuré en août (LIV-T15) : les variables posées
# dans .env, absentes du bloc `environment:`, et un opérateur envoyé chercher
# une faute de frappe dans un fichier qui n'en avait pas.
require_relay() {
  local missing=0
  for key in KPB_EEF_TEASER_ENABLED KPB_EEF_CAMPAIGN_OPENS_AT KPB_EEF_SUSPENDED_COUNTRIES; do
    grep -q -- "- ${key}=\${${key}" docker-compose.yml || { echo "::error::${key} n'est pas relayée dans docker-compose.yml — poser le .env n'aurait aucun effet. Le VPS tourne un checkout antérieur au correctif du relais."; missing=1; }
  done
  [ "$missing" -eq 0 ] || exit 1
}

# Pose ou REMPLACE une clé dans .env. Remplacer plutôt qu'ajouter : un .env
# avec deux fois la même clé garde la dernière, et devient illisible pour la
# personne qui le relit.
set_env_key() {
  local key="$1" value="$2"
  if grep -qE "^${key}=" .env; then
    sed -i.bak "s|^${key}=.*|${key}=${value}|" .env
  else
    printf '%s=%s\n' "$key" "$value" >> .env
  fi
}

show_state() {
  echo "── Drapeaux EEF dans le .env ──"
  grep -E '^KPB_EEF' .env || echo "(aucune variable KPB_EEF posée)"
  echo
  echo "── Ce que compose interpolera ──"
  docker compose config 2>/dev/null | grep -E 'KPB_EEF' || echo "(interpolation indisponible)"
  echo
  echo "── Bourses en base ──"
  docker compose exec -T db psql -v ON_ERROR_STOP=1 -tA \
    -U "$(grep -E '^POSTGRES_USER=' .env | cut -d= -f2-)" \
    -d "$(grep -E '^POSTGRES_DB=' .env | cut -d= -f2-)" \
    -c 'SELECT "moderationStatus", "isActive", count(*) FROM "Scholarship" GROUP BY 1,2 ORDER BY 1,2;'
}

case "$ACTION" in
  show-state)
    show_state
    ;;

  eef-teaser-on)
    require_relay
    cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    set_env_key KPB_EEF_TEASER_ENABLED true
    set_env_key KPB_EEF_CAMPAIGN_OPENS_AT 2026-10-01
    set_env_key KPB_EEF_SUSPENDED_COUNTRIES Niger,NE
    # KPB_EEF_ENABLED reste ABSENT à dessein : il retire la vitrine de lui-même
    # et afficherait l'espace réel, qui est une coquille vide en Phase 0.
    if grep -qE '^KPB_EEF_ENABLED=true' .env; then
      echo "::error::KPB_EEF_ENABLED=true est posé : il désactive la vitrine et afficherait un espace VIDE. Le retirer avant de continuer."
      exit 1
    fi
    echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
    docker compose up -d --no-deps api
    ;;

  eef-teaser-off)
    require_relay
    cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    set_env_key KPB_EEF_TEASER_ENABLED false
    echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
    docker compose up -d --no-deps api
    ;;

  publish-catalog)
    # SOP docs/catalog-verification-sop.md, SANS --confirmed-only : ce drapeau
    # écarte toute fiche à cycle estimé, c'est-à-dire les bourses « à venir ».
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run catalog:import -- --dry-run
      docker compose exec -T api npm run catalog:switch -- --dry-run
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run catalog:import -- --apply
      docker compose exec -T api npm run catalog:switch -- --apply
    fi
    echo
    echo "── Bourses visibles après opération ──"
    show_state
    ;;

  *)
    echo "::error::ACTION inconnue : $ACTION"
    exit 2
    ;;
esac
