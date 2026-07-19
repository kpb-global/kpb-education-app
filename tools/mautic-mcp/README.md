# KPB Mautic MCP

Petit serveur MCP (stdio) qui expose le Mautic auto-hébergé
(`mautic.kpbeducation.cloud`) à Claude : segments, contacts, vérification
d'auth. Sert à opérer la newsletter « Nouvelles bourses » (créée par la PR
#163) sans quitter la conversation.

## Installation

```bash
cd tools/mautic-mcp
npm install
```

## Credentials

Créer `tools/mautic-mcp/.env` (git-ignoré) avec **l'un des deux** modes :

```bash
# Basic auth (activé sur l'instance KPB) — utilisateur Mautic dédié conseillé
MAUTIC_USERNAME=...
MAUTIC_PASSWORD=...

# OU OAuth2 client_credentials (Mautic → Settings → API Credentials)
MAUTIC_CLIENT_ID=...
MAUTIC_CLIENT_SECRET=...

# Optionnel (défaut: https://mautic.kpbeducation.cloud)
MAUTIC_BASE_URL=https://mautic.kpbeducation.cloud
```

## Enregistrement dans Claude Code

```bash
claude mcp add kpb-mautic --scope user -- node "<repo>/tools/mautic-mcp/index.mjs"
```

## Outils

| Outil | Rôle |
|---|---|
| `mautic_test_auth` | Vérifie les identifiants (renvoie l'utilisateur connecté) |
| `mautic_list_segments` | Liste les segments (id, nom, alias) |
| `mautic_create_segment` | Crée un segment → id à mettre dans `MAUTIC_SEGMENT_ID` |
| `mautic_segment_contacts` | Contacts d'un segment (vérifier que les opt-ins arrivent) |
| `mautic_search_contact` | Retrouve un contact par email (+ statut do-not-contact) |
| `mautic_add_contact_to_segment` | Ajout manuel d'un contact à un segment |
