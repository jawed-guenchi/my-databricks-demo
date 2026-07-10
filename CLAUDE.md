# CLAUDE.md — Instructions pour Claude Code

> Ce fichier est lu automatiquement au démarrage. Il te dit **exactement quoi faire, étape par étape**, dans ce repo. Suis-le strictement. En cas de doute, applique les **Règles d'or** (section finale).

---

## 🎯 Rôle du repo (résumé en une phrase)

Aider un consultant à produire une **démo Databricks** (fausses données + pipeline + **application web React**) pour un pitch client, à partir d'une **description en langage naturel**. Il n'y a **aucune commande slash** à retenir : l'utilisateur décrit, tu construis — après validation.

> 🎨 **L'application doit être une vraie app web React (AppKit), montrable aux métiers** : soignée, interactive, pertinente pour le cas d'usage. **Pas de Streamlit** — l'objectif est un rendu « pro » qu'on présente à un décideur, pas un prototype data.

Ton job se résume à deux moments :
1. **Onboarding** — t'assurer que l'environnement est prêt (CLI Databricks + Node.js + connexion Databricks). À faire une seule fois.
2. **Construction de démo** — transformer une demande en langage naturel en données + pipeline + app React.

---

## ÉTAPE 0 — À chaque démarrage : lire le statut du hook

Un hook `SessionStart` exécute `.claude/hooks/sync-skills.ps1` automatiquement. Il affiche un bloc :

```
=== Etat environnement Databricks Demo (hook SessionStart) ===
[skills] ...
[cli] ...
[auth] ...
[node] ...
```

**Lis ce bloc et oriente-toi :**

| Ce que tu vois | Ce que ça veut dire | Ce que tu fais |
|---|---|---|
| `[skills] ... synchronisees` ou `Deja a jour` | Les skills Databricks officielles sont installées et à jour dans `.claude/skills/` | Rien — elles sont prêtes à l'emploi |
| `[cli] Databricks CLI ABSENT` | Le CLI n'est pas installé | Va à **ÉTAPE 1** |
| `[node] Node.js ABSENT` (ou < 22) | Node.js manquant → pas d'app React possible | Va à **ÉTAPE 1** |
| `[auth] NON authentifie` | Pas connecté à un workspace | Va à **ÉTAPE 2** |
| `[cli] ... present`, `[node] ... present` **et** `[auth] Authentifie` | Tout est prêt | Saute l'onboarding → **ÉTAPE 3** |

> ⚠️ Ne fais jamais l'onboarding en silence. Explique en une phrase ce que tu vas faire, puis laisse l'utilisateur valider avant d'exécuter une commande.

Si le bloc de statut n'apparaît pas (hook non déclenché), tu peux le lancer manuellement :
`powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/sync-skills.ps1`

---

## ÉTAPE 1 — Installer les outils requis (si absents)

Propose puis, après accord, installe ce qui manque :

**a) CLI Databricks** (si `[cli] ABSENT`) :
```powershell
winget install Databricks.DatabricksCLI
```
- C'est le **CLI unifié moderne**. Surtout **PAS** l'ancien package pip `databricks-cli` (déprécié).
- Vérifie avec `databricks version` (attendu : ≥ 0.295 pour `databricks apps init` / AppKit).

**b) Node.js ≥ 22** (si `[node] ABSENT` ou trop ancien) — **requis pour les apps React/AppKit** :
```powershell
winget install OpenJS.NodeJS.LTS
```
- Vérifie avec `node --version` (attendu : v22+).

Après une installation, le PATH peut nécessiter un **nouveau terminal**. Puis enchaîne sur l'ÉTAPE 2.

---

## ÉTAPE 2 — Connecter l'utilisateur à Databricks (si non authentifié)

1. **Demande l'URL de son workspace** (ex : `https://dbc-xxxx.cloud.databricks.com`). Ne devine jamais.
2. Propose puis exécute :
   ```powershell
   databricks auth login --host <URL-du-workspace>
   ```
   Un login **navigateur** s'ouvre (OAuth). Le jeton est stocké dans le **Windows Credential Manager**, **jamais** dans un fichier du repo.
3. Vérifie : `databricks current-user me` (doit renvoyer l'utilisateur).

> ❌ Ne propose JAMAIS de coller un token PAT dans un fichier. OAuth uniquement.

Quand CLI + auth sont OK, tu es prêt à construire.

---

## ÉTAPE 3 — Construire une démo (le cœur du travail)

Déclenchée dès que l'utilisateur décrit un client ou un cas d'usage. Suis ces sous-étapes **dans l'ordre**, sans en sauter.

### 3.1 — Cadrer AVANT de coder
Pose (au minimum) ces trois questions si l'info manque :
- **Secteur & cas d'usage** — retail, banque, télécom, santé… et quel problème métier ?
- **L'histoire des données** — la donnée doit raconter une histoire : *un incident / une anomalie → un impact chiffré en €/$ → une analyse possible → une action.* Jamais de données plates/uniformes. Si l'utilisateur n'a pas d'idée, **propose une histoire** convaincante.
- **Catalog / schema Unity Catalog cible** — où écrire les données ? Ne devine pas ; demande. (Sur un workspace Free, c'est souvent le catalogue `workspace`.)

### 3.2 — Proposer un plan et le faire valider
Présente un plan clair : liste des tables (+ ordres de grandeur et distributions), la logique du pipeline, le type d'app/dashboard. **N'écris aucun code de génération avant l'accord.** Pour une tâche non triviale, passe par le mode plan.

### 3.3 — Scaffolder la démo comme un bundle
Crée la démo sous `demos/<nom-demo>/` en **Databricks Asset Bundle (DAB)** :
```
demos/<nom-demo>/
├── databricks.yml     # bundle + variables (catalog, schema) + target dev
├── resources/         # une ressource par fichier : *.pipeline.yml, *.app.yml, *.job.yml
└── src/               # code : pipeline, app, notebooks
```
Une démo = un bundle autonome. Charge la skill `databricks-dabs` pour la structure exacte.

### 3.4 — Générer les 3 briques (appuie-toi sur les skills)
Les skills dans `.claude/skills/` contiennent les bonnes pratiques détaillées — **charge la skill correspondante avant de coder chaque brique** :

| Brique | Skill à charger | Points clés |
|---|---|---|
| Données synthétiques | `databricks-synthetic-data-gen` | Spark + Faker en serverless ; distributions réalistes (jamais uniformes) ; intégrité référentielle |
| Pipeline | `databricks-pipelines` | Lakeflow Spark Declarative Pipeline ; pattern medallion ; garder les dimensions utiles à l'app |
| **Application web React** | `databricks-apps` + `databricks-app-design` | **Standard = AppKit (TypeScript + React)**. Scaffolder avec `databricks apps init`. Front soigné, montrable aux métiers. Plugin **Analytics** pour interroger le SQL Warehouse (typé, caché) ; plugin **Genie** pour du questionnement en langage naturel. Déployer avec `databricks apps deploy`. |

**Sur l'application (important) :**
- **Toujours une app React via AppKit** — pas de Streamlit. L'objectif est un rendu « produit », interactif et pertinent pour le décideur métier (KPI clairs, graphes, drill-down, storytelling du cas d'usage).
- Charge **`databricks-app-design`** pour l'UX (choix du genre d'écran, layout, KPI, couleurs sémantiques, états loading/empty/error, notation IBCS, affichage de confiance pour les résultats Genie).
- AppKit requiert **Node.js ≥ 22** (voir onboarding). Si vraiment indisponible et non installable, préviens l'utilisateur et propose un dashboard **AI/BI (Lakeview)** natif via `databricks-aibi-dashboards` comme repli — **jamais** Streamlit.
- Une fois l'app déployée, son **service principal** doit avoir les droits de lecture (USE CATALOG/SCHEMA + SELECT) sur le schéma des données : c'est une **création de droits** → demande confirmation avant de l'exécuter (voir Règle d'or 2).

Pour toute action CLI/auth, la skill parente est `databricks-core`.

### 3.5 — Valider
Lance `databricks bundle validate --target dev`. Corrige jusqu'à validation propre.

### 3.6 — Déployer (UNIQUEMENT sur demande explicite)
Le déploiement crée de vraies ressources dans le workspace. **Demande une confirmation dédiée** avant :
```powershell
databricks bundle deploy --target dev
databricks bundle run <resource> --target dev
```
Même si un plan global a été approuvé plus tôt, cette étape exige un « oui » explicite ici.

---

## 🛡️ Règles d'or (non négociables)

1. **Plan avant action** — toute tâche non triviale : propose une stratégie, fais-la valider, PUIS exécute.
2. **Jamais de déploiement / création de ressource sans feu vert explicite** — `bundle deploy`, `apps deploy`, création de cluster/warehouse/catalog… toujours confirmer juste avant.
3. **Full refresh de pipeline = dangereux** (perte de données possible) — jamais sans validation explicite.
4. **Zéro secret dans le repo** — pas de token, pas de `.databrickscfg`, pas de `.env` commité. OAuth uniquement pour l'auth.
5. **Confirme avant tout `git push`.**
6. **Réponds en français** (langue de l'équipe), sauf demande contraire.

---

## 📍 Repères

- **Skills** : dans `.claude/skills/` (gitignorées, synchronisées auto par le hook). Ne les modifie pas à la main — elles sont écrasées à chaque session.
- **Fonctionnement interne** (hook, cache, précédence des skills, tuning) : `docs/ARCHITECTURE.md`.
- **Gouvernance entreprise** (AI Gateway, UCode, Service Policies, guardrails, Smart Scaling) : `docs/GOVERNANCE.md` — roadmap, pas encore implémentée.
- **Démos déjà créées** : sous `demos/`.
