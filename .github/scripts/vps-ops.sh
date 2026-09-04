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

# Recrée le conteneur api SANS RIEN RECONSTRUIRE.
#
# `docker compose up -d --no-deps api` seul a été une erreur, payée le
# 30/08/2026 : compose résout `image: kpb-backend:${KPB_IMAGE_TAG:-local}`, ne
# trouve pas `kpb-backend:local`, échoue à le tirer (registre privé), et
# RECONSTRUIT depuis la source. Le conteneur repart alors sur une image sans
# tag ni `KPB_BUILD_SHA` : `/health/version` rend `sha: unknown`, et l'empreinte
# immuable de la release — que `deploy.yml` construit et vérifie soigneusement —
# est perdue.
#
# Le code tournant restait le bon (le checkout du VPS est au SHA déployé), mais
# la traçabilité, non. Une opération de drapeau ne doit JAMAIS changer l'artefact.
#
# On relit donc le tag et le SHA sur le conteneur EN COURS, et on recrée avec
# exactement les mêmes. `--no-build` est la ceinture : si le tag ne résout pas,
# on veut un échec franc, pas une reconstruction silencieuse.
# Le tag lu ici est MUTABLE : `deploy.yml` réécrit `kpb-backend:<tag>` pendant
# `docker compose build`. La parade principale est ailleurs — `vps-ops.yml`
# partage désormais le groupe de concurrence `deploy-vps`, donc une opération de
# drapeau ne peut plus s'entrelacer avec une release. Le contrôle ci-dessous est
# la ceinture : on relève l'ID d'image (lui, immuable) avant et après, et on
# échoue franchement s'il a bougé. Sans lui, une sérialisation cassée un jour
# par une renommée de groupe repasserait inaperçue — et c'est précisément ce
# genre de silence qui a coûté l'empreinte de release le 30/08/2026.
recreate_api_same_image() {
  local cur tag sha id_before id_after sha_after
  cur=$(docker inspect -f '{{.Config.Image}}' kpb_api 2>/dev/null || true)
  [ -n "$cur" ] || { echo "::error::conteneur kpb_api introuvable — ne pas recréer à l'aveugle"; exit 1; }
  tag="${cur##*:}"
  [ -n "$tag" ] && [ "$tag" != "$cur" ] || { echo "::error::image sans tag exploitable : $cur"; exit 1; }
  sha=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' kpb_api 2>/dev/null | sed -n 's/^KPB_BUILD_SHA=//p' | head -1)
  id_before=$(docker inspect -f '{{.Image}}' kpb_api)
  echo "recréation à l'identique — image $cur, id ${id_before}, build sha ${sha:-<absent>}"
  KPB_IMAGE_TAG="$tag" KPB_BUILD_SHA="$sha" \
    docker compose up -d --no-deps --no-build api

  id_after=$(docker inspect -f '{{.Image}}' kpb_api)
  if [ "$id_before" != "$id_after" ]; then
    echo "::error::l'image a CHANGÉ pendant la recréation : ${id_before} -> ${id_after}. Le tag ${tag} a été réécrit entre-temps (release concurrente ?). Relancer « Deploy backend (VPS) » scope=full pour repartir d'un état connu."
    exit 1
  fi
  sha_after=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' kpb_api 2>/dev/null | sed -n 's/^KPB_BUILD_SHA=//p' | head -1)
  if [ "$sha" != "$sha_after" ]; then
    echo "::error::KPB_BUILD_SHA perdu à la recréation : « ${sha:-<absent>} » -> « ${sha_after:-<absent>} ». L'empreinte de release ne serait plus lisible sur /health/version."
    exit 1
  fi
  echo "image et empreinte inchangées — id ${id_after}, build sha ${sha_after:-<absent>}"
}

# La valeur EFFECTIVEMENT vue par l'API, pas celle qu'on devine.
#
# Deux façons de se tromper, et le script tombait dans les deux :
#
#   1. Lire `.env` avec `head -1`. Une clé posée deux fois garde la DERNIÈRE —
#      `set_env_key` le documente à quatre lignes d'ici — donc le premier
#      assignement peut dire exactement le contraire de la configuration
#      réelle. Un rapport qui ment sur ce qu'il a lu est pire qu'un rapport
#      absent.
#   2. Lire `.env` tout court. Une variable peut y être posée sans être
#      relayée dans le bloc `environment:` de compose : elle existe dans le
#      fichier et n'atteint jamais le processus. C'est le défaut mesuré en
#      août (LIV-T15), et `require_relay` existe déjà à cause de lui.
#
# On interroge donc le CONTENEUR EN COURS, qui est la seule source de vérité :
# c'est l'environnement que Node lit réellement. Repli sur `.env` avec
# `tail -1` si le conteneur est introuvable, en le DISANT.
effective_env() {
  local key="$1" value
  value=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' kpb_api 2>/dev/null \
    | sed -n "s/^${key}=//p" | tail -1 || true)
  if [ -n "$value" ]; then
    printf '%s' "$value"
    return 0
  fi
  # Le conteneur ne porte pas la clé : soit elle est absente, soit il n'est pas
  # là. On distingue les deux, parce que « absente » et « illisible » n'appellent
  # pas le même geste.
  if docker inspect kpb_api >/dev/null 2>&1; then
    return 1
  fi
  grep -E "^${key}=" .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"'"'"'\r' | xargs || true
}

# Rend compte d'un secret SANS le montrer.
#
# La règle est asymétrique et c'est voulu : `ONESIGNAL_APP_ID` est public — il
# voyage dans le binaire de l'app, un `strings` sur l'IPA le donne — donc
# l'afficher permet de comparer. `ONESIGNAL_REST_API_KEY` est un secret : on
# n'en dit que la présence, jamais la valeur ni la longueur.
report_key() {
  local key="$1" mode="${2:-masked}" value
  value=$(effective_env "$key")
  if [ -z "$value" ]; then
    printf '  %-26s ABSENTE\n' "$key"
    return 1
  fi
  if [ "$mode" = "public" ]; then
    printf '  %-26s %s\n' "$key" "$value"
  else
    printf '  %-26s posée\n' "$key"
  fi
}

# Le push est-il seulement CAPABLE de partir, et vers la bonne application ?
#
# `OneSignalSenderService` se dégrade en silence : sans ces deux variables,
# chaque envoi devient un no-op journalisé, le fil d'actualité s'écrit quand
# même, et le dispatcher rend `push_unconfigured`. Rien, nulle part, ne le
# disait — c'est la forme d'échec qui a envoyé la build 50 sans PostHog.
show_push_state() {
  echo "── Notifications push (OneSignal) ──"
  docker inspect kpb_api >/dev/null 2>&1 \
    || echo "  (conteneur kpb_api introuvable — valeurs lues dans .env, pas dans le processus)"
  local ok=0
  report_key ONESIGNAL_APP_ID public || ok=1
  report_key ONESIGNAL_REST_API_KEY masked || ok=1
  if [ "$ok" -ne 0 ]; then
    echo "  → push DÉSACTIVÉ : le fil s'écrira, aucune notification ne partira."
  else
    echo "  → push configuré."
  fi

  # Comparaison INDICATIVE, et jamais bloquante.
  #
  # `EXPECTED_ONESIGNAL_APP_ID` vient du `defaultValue` COURANT de
  # `app_config.dart`. Ce n'est pas nécessairement l'App ID de la build que les
  # utilisateurs ont installée : le défaut a pu changer depuis la mise en ligne,
  # et un binaire peut avoir été construit avec `--dart-define`, qui l'emporte.
  #
  # Un écart mérite donc un REGARD, pas une action. En faire une erreur aurait
  # invité à basculer le serveur pour le faire correspondre à la source — et à
  # couper le push pour tous les clients déjà installés. La vérité vit dans
  # l'artefact distribué : `strings App.framework/App | grep -o '[0-9a-f-]\{36\}'`.
  if [ -n "${EXPECTED_ONESIGNAL_APP_ID:-}" ]; then
    local server
    server=$(effective_env ONESIGNAL_APP_ID)
    if [ -z "$server" ]; then
      : # déjà signalé comme ABSENTE ci-dessus
    elif [ "$server" = "$EXPECTED_ONESIGNAL_APP_ID" ]; then
      echo "  App ID identique au défaut courant de app_config.dart ✅"
    else
      echo "::warning::l'App ID du serveur ($server) diffère du défaut courant de app_config.dart ($EXPECTED_ONESIGNAL_APP_ID). Ce n'est PAS forcément une panne : la build installée peut porter un autre App ID (défaut modifié depuis la mise en ligne, ou --dart-define). NE PAS basculer le serveur sans avoir lu l'App ID de l'artefact réellement distribué."
    fi
  fi
  echo
}

# Vers QUI partent réellement les invites IA ?
#
# La question n'est pas cosmétique : `docs/CONSOLE_ANSWERS.md` §5 porte la
# mention « recopier au formulaire destinataires ». Nommer le mauvais
# sous-traitant dans une déclaration de confidentialité est une déclaration
# fausse, pas une coquille.
#
# On REJOUE ici la précédence exacte de `LlmService.provider`
# (backend/src/modules/ai/llm.service.ts) plutôt que de la résumer : un résumé
# se désynchronise du code en silence, et c'est précisément ce qu'on cherche à
# éviter. `LLM_API_KEY` l'emporte (OpenRouter sauf `LLM_PROVIDER=groq`) ; à
# défaut, `GROQ_API_KEY` fait tomber sur Groq ; sans clé, aucun fournisseur.
#
# Asymétrie habituelle : les CLÉS sont des secrets (présence seulement), le
# fournisseur, le modèle et l'URL sont de la configuration — les afficher est
# tout l'intérêt de la manoeuvre.
show_llm_state() {
  echo "── Fournisseur LLM (destinataire des invites) ──"
  docker inspect kpb_api >/dev/null 2>&1 \
    || echo "  (conteneur kpb_api introuvable — valeurs lues dans .env, pas dans le processus)"

  # `|| true` sur CHAQUE lecture optionnelle : sous `set -e`, une affectation
  # dont la substitution rend 1 tue le script. `effective_env` rend justement 1
  # quand la clé est absente du conteneur — et `LLM_PROVIDER`, `LLM_MODEL` et
  # `LLM_CHAT_COMPLETIONS_URL` sont TOUTES optionnelles par construction. Sans
  # ces gardes, `show-state` mourait pile sur l'installation la plus banale.
  local llm_key groq_key name model url
  llm_key=$(effective_env LLM_API_KEY || true)
  groq_key=$(effective_env GROQ_API_KEY || true)

  if [ -n "$llm_key" ]; then
    report_key LLM_API_KEY masked
    local declared
    declared=$(effective_env LLM_PROVIDER || true)
    if [ "$(printf '%s' "$declared" | tr '[:upper:]' '[:lower:]')" = "groq" ]; then
      name=groq
      model=$(effective_env LLM_MODEL || true); model="${model:-llama-3.3-70b-versatile (défaut)}"
      url=$(effective_env LLM_CHAT_COMPLETIONS_URL || true); url="${url:-https://api.groq.com/openai/v1/chat/completions (défaut)}"
    else
      name=openrouter
      model=$(effective_env LLM_MODEL || true); model="${model:-deepseek/deepseek-v4-flash (défaut)}"
      url=$(effective_env LLM_CHAT_COMPLETIONS_URL || true); url="${url:-https://openrouter.ai/api/v1/chat/completions (défaut)}"
    fi
  elif [ -n "$groq_key" ]; then
    echo "  LLM_API_KEY                ABSENTE (repli sur les variables GROQ_* héritées)"
    report_key GROQ_API_KEY masked
    name=groq
    model=$(effective_env GROQ_MODEL || true); model="${model:-llama-3.3-70b-versatile (défaut)}"
    url="https://api.groq.com/openai/v1/chat/completions (fixe sur ce chemin)"
  else
    echo "  aucune clé LLM posée"
    echo "  → IA NON configurée : les outils rendront une réponse locale de repli."
    echo
    return 0
  fi

  printf '  %-26s %s\n' "fournisseur résolu" "$name"
  printf '  %-26s %s\n' "modèle" "$model"
  printf '  %-26s %s\n' "URL appelée" "$url"
  echo "  → destinataire à déclarer dans les formulaires : $name"

  # Le §5 de la fiche consoles nomme Groq. Si la prod route ailleurs, la fiche
  # ment au formulaire — on le dit fort, sans faire échouer une lecture d'état.
  if [ "$name" != "groq" ]; then
    echo "::warning::docs/CONSOLE_ANSWERS.md §5 déclare Groq comme destinataire des invites IA, or la production route vers ${name}. Corriger la fiche AVANT de recopier la table des destinataires dans Play Data Safety / App Privacy."
  fi
  echo
}

show_state() {
  echo "── Drapeaux EEF dans le .env ──"
  grep -E '^KPB_EEF' .env || echo "(aucune variable KPB_EEF posée)"
  echo
  show_push_state
  show_llm_state
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
    recreate_api_same_image
    ;;

  eef-teaser-off)
    require_relay
    cp -p .env ".env.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    set_env_key KPB_EEF_TEASER_ENABLED false
    echo "── .env après écriture ──"; grep -E '^KPB_EEF' .env
    recreate_api_same_image
    ;;

  publish-catalog)
    # SOP docs/catalog-verification-sop.md, SANS --confirmed-only : ce drapeau
    # écarte toute fiche à cycle estimé, c'est-à-dire les bourses « à venir ».
    #
    # `reconcile` s'intercale entre `import` et `switch`, et l'ordre est une
    # nécessité, pas une préférence :
    #   • `import` crée les fiches manquantes et NE TOUCHE JAMAIS les autres ;
    #   • `reconcile` réaligne les fiches déjà créées sur le dépôt — sans lui,
    #     une correction relue en PR n'atteint jamais la production (mesuré le
    #     31/08/2026 : deux fiches servaient un cycle « estimated » là où le
    #     dépôt disait « confirmed » depuis le 24/08) ;
    #   • `switch` publie, en dernier, sur des données à jour. Réconcilier APRÈS
    #     aurait publié la version périmée avant de la corriger.
    #
    # `reconcile` ne publie ni n'approuve rien : sa transaction est annulée si
    # l'état de modération d'une seule fiche a bougé pendant l'opération.
    if [ "$DRY_RUN" = "true" ]; then
      echo "── SIMULATION (rien n'est écrit) ──"
      docker compose exec -T api npm run catalog:import -- --dry-run
      docker compose exec -T api npm run catalog:reconcile -- --dry-run
      docker compose exec -T api npm run catalog:switch -- --dry-run
    else
      echo "── APPLICATION ──"
      docker compose exec -T api npm run catalog:import -- --apply
      docker compose exec -T api npm run catalog:reconcile -- --apply
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
