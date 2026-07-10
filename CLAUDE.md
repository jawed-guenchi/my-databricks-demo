# CLAUDE.md — Cadrage du projet

> Ce fichier est lu automatiquement par Claude Code au démarrage. Il définit **comment tu (Claude) dois te comporter** dans ce repo. Suis-le strictement.

## But du repo

Point d'entrée d'équipe pour créer **rapidement des démos Databricks** destinées à des pitchs client : fausses données réalistes + pipeline + application, sur un cas d'usage métier concret. L'utilisateur décrit sa démo **en langage naturel** — il n'y a pas de commande à retenir. Ton rôle : l'onboarder si besoin, puis construire la démo de façon cadrée.

## Au démarrage de chaque session

Un hook `SessionStart` (`.claude/hooks/sync-skills.ps1`) s'exécute automatiquement et affiche un bloc `=== Etat environnement Databricks Demo ===`. **Lis-le** et agis en conséquence :

- **`[skills] ... synchronisees`** : les Databricks Agent Skills officielles viennent d'être mises à jour dans `.claude/skills/`. Tu n'as rien à faire — elles sont dispo et à jour. (Elles couvrent CLI, données synthétiques, pipelines, apps, dashboards, Unity Catalog, etc.)
- **`[cli] Databricks CLI ABSENT`** → propose d'installer le CLI (voir Onboarding).
- **`[auth] NON authentifie`** → propose de faire le login OAuth (voir Onboarding).
- Si CLI présent **et** authentifié : pas d'onboarding, passe directement au besoin de l'utilisateur.

N'exécute jamais l'onboarding en silence : explique brièvement ce que tu vas faire et laisse l'utilisateur valider.

## Onboarding (premier lancement)

À faire uniquement si le hook signale un manque.

1. **Installer le Databricks CLI** (unifié, moderne — surtout PAS l'ancien package pip `databricks-cli`) :
   ```powershell
   winget install Databricks.DatabricksCLI
   ```
   Après install, un nouveau terminal peut être nécessaire pour rafraîchir le PATH. Vérifie : `databricks version` (attendu ≥ 0.205 ; idéalement v1.x).

2. **Authentifier via OAuth** (aucun secret n'est stocké dans le repo — le token va dans le Windows Credential Manager) :
   ```powershell
   databricks auth login --host <URL-du-workspace>
   ```
   Demande à l'utilisateur l'URL de son workspace Databricks (ex : `https://dbc-xxxx.cloud.databricks.com`). Un login navigateur s'ouvre. Vérifie ensuite : `databricks current-user me`.

   > Ne propose jamais de coller un token PAT dans un fichier du repo. OAuth uniquement.

## Construire une démo (workflow cadré)

Quand l'utilisateur décrit un client / un cas d'usage, suis ces étapes **dans l'ordre** :

1. **Cadrer** avant de coder. Clarifie :
   - Le **secteur** et le **cas d'usage** métier.
   - L'**histoire** : la donnée doit raconter une histoire (un incident / une anomalie → un impact chiffré en €/$ → une analyse possible → une action). Pas de données plates et uniformes. Si l'utilisateur n'a pas d'histoire précise, **propose-en une**.
   - Le **catalog / schema Unity Catalog cible** (ne jamais deviner — demande ; sur un workspace Free, souvent le catalogue `workspace`).
2. **Proposer un plan** (tables + distributions, pipeline, app) et le faire **valider** avant de générer le moindre code. Utilise le mode plan si la tâche est non triviale.
3. **Scaffolder** la démo sous `demos/<nom-demo>/` en **Databricks Asset Bundle** (DAB) : `databricks.yml` + `resources/` + `src/`. Une démo = un bundle autonome.
4. **Générer les 3 briques** en t'appuyant sur les skills synchronisées :
   - **Données synthétiques** (skill `databricks-synthetic-data-gen`) : Spark + Faker en serverless, distributions réalistes (jamais uniformes), intégrité référentielle.
   - **Pipeline** (skill `databricks-pipelines`) : Lakeflow Spark Declarative Pipeline, pattern medallion, en gardant les dimensions utiles au dashboard/app.
   - **Application** (skills `databricks-apps` / `databricks-apps-python` / `databricks-app-design`) : par défaut AppKit si Node.js v22+ est dispo, sinon Streamlit (Python).
5. **Valider** la config : `databricks bundle validate` (ajoute `--target dev`). Corrige jusqu'à validation propre.

## Règles d'or (non négociables)

- **Plan avant action** : pour toute tâche non triviale, propose une stratégie et fais-la valider avant d'exécuter.
- **Jamais de déploiement sans feu vert explicite** : `databricks bundle deploy`, `databricks apps deploy`, ou toute commande qui **crée / modifie des ressources dans le workspace** exige une confirmation dédiée de l'utilisateur, même si un plan global a déjà été approuvé.
- **Full refresh de pipeline** : opération dangereuse (perte de données possible) — ne jamais lancer sans validation explicite.
- **Secrets** : ne jamais committer de token, `.databrickscfg`, `.env`, clé. OAuth uniquement pour l'auth.
- **Git** : confirme avant tout `git push`.

## Repères

- Les skills vivent dans `.claude/skills/` (gitignorées, synchronisées auto — voir `docs/ARCHITECTURE.md`).
- Détails de fonctionnement : `docs/ARCHITECTURE.md`.
- Gouvernance entreprise (AI Gateway, UCode, Service Policies, guardrails, Smart Scaling) : `docs/GOVERNANCE.md` — roadmap, pas encore implémentée.
