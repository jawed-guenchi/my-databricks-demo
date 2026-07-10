# Architecture — comment ce repo fonctionne

Ce document explique les mécanismes internes du starter. Utile pour comprendre, débugger ou adapter.

## Vue d'ensemble

Le repo transforme un simple clone Git en environnement prêt à produire des démos Databricks, en s'appuyant sur trois piliers de Claude Code, tous chargés **automatiquement au clone** :

| Fichier | Rôle |
|---|---|
| `CLAUDE.md` | Chargé automatiquement au démarrage. Cadre le comportement de Claude (onboarding, workflow démo, règles d'or). |
| `.claude/settings.json` | Déclare un hook `SessionStart` (partagé, versionné). |
| `.claude/hooks/sync-skills.ps1` | Le script exécuté par le hook à chaque session. |

## Mise à jour automatique des skills

**Objectif** : que toutes les Databricks Agent Skills officielles soient disponibles et **toujours à jour**, sans aucune action de l'utilisateur.

**Mécanisme** : le hook `SessionStart` (matcher `startup`) lance `.claude/hooks/sync-skills.ps1` à **chaque** démarrage de session Claude Code. Le script :

1. Maintient un **cache** local du repo officiel dans `.claude/.cache/databricks-agent-skills` (clone shallow au premier run, `fetch` + `reset --hard` ensuite). L'option `git -c core.longpaths=true` contourne la limite de longueur de chemin de Windows.
2. Recopie **toutes** les skills de `skills/` du repo officiel vers `.claude/skills/` (miroir via `robocopy /MIR`).
3. Vérifie l'état du CLI Databricks et de l'authentification.
4. Imprime un bloc de statut sur stdout — que **Claude lit** au démarrage pour décider s'il doit onboarder l'utilisateur.

Le script est **non bloquant** : en cas d'échec (hors-ligne, git absent…), il conserve les skills déjà en cache et n'interrompt jamais la session.

### Pourquoi les skills sont gitignorées

`.claude/skills/*` est dans `.gitignore` (sauf `.gitkeep`). Raisons :

- **Toujours à jour** : la source de vérité est le repo officiel, pas une copie figée dans notre Git.
- **Repo léger** : les skills représentent ~1500 fichiers ; inutile de les versionner.
- Le `.gitkeep` garantit que le dossier `.claude/skills/` **existe dès le clone**, ce qui permet à Claude Code d'y détecter les skills « à chaud » quand le hook les y dépose.

### Note sur la précédence des skills

Claude Code applique un ordre : **personnel (`~/.claude/skills/`) > projet (`.claude/skills/`)**. Si un utilisateur a des skills Databricks installées **personnellement** portant le même nom, elles **masquent** celles du repo (potentiellement plus anciennes). Pour éviter ça, ne pas conserver de copie personnelle des skills Databricks ; laisser le repo les gérer.

## Authentification (OAuth U2M)

L'auth passe par `databricks auth login --host <url>` (OAuth user-to-machine) :

- Un login **navigateur** s'ouvre ; le token est stocké dans le **Windows Credential Manager**, jamais dans un fichier.
- Le `.databrickscfg` ne contient alors que l'URL du workspace (rien de secret).
- C'est plus sûr qu'un token PAT écrit en clair, et ça évite tout risque de commit accidentel de secret.

`.databrickscfg` reste malgré tout listé dans `.gitignore` par prudence.

## Structure d'une démo (DAB)

Chaque démo est un **Databricks Asset Bundle** autonome sous `demos/<nom>/` :

```
demos/<nom>/
├── databricks.yml          # bundle + variables (catalog, schema) + targets (dev/prod)
├── resources/              # une ressource par fichier : *.pipeline.yml, *.app.yml, *.job.yml...
└── src/                    # code : pipeline (SQL/Python), app (Streamlit/AppKit), notebooks
```

Cycle : `databricks bundle validate` → (sur confirmation) `databricks bundle deploy -t dev` → `databricks bundle run <resource>`.

## Réglages et dépannage

- **Ralentir la synchro** (éviter un `git fetch` à chaque session) : ajouter dans `sync-skills.ps1` un throttle basé sur `.claude/.cache/last-sync.txt` (déjà écrit à chaque run) pour ne resynchroniser qu'au-delà de N heures.
- **Désactiver temporairement le hook** : retirer/renommer le bloc `SessionStart` dans `.claude/settings.json`, ou surcharger via `.claude/settings.local.json` (non versionné).
- **Forcer une resynchro propre** : supprimer `.claude/.cache/` et redémarrer la session.
- **Le hook ne se lance pas** : vérifier que le dossier est « trusted » dans VS Code, et que PowerShell est disponible.
