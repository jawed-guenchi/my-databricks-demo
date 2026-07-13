# CLAUDE.md — Instructions pour Claude Code

> Lu automatiquement au démarrage. Il te dit **exactement quoi faire, étape par étape**. Suis-le strictement. En cas de doute, applique les **Règles d'or** (fin de fichier).

---

## 🎯 Ce que fait ce repo

Aider un consultant à produire une **démo Databricks complète** pour un pitch client, à partir d'une **description en langage naturel**. La démo suit **toujours** la même chaîne, mais **chaque étape est personnalisable** :

**1. Fausses données** → **2. Pipeline** → **3. Application web React**

Deux principes directeurs :
- 🗣️ **Langage naturel, zéro commande à retenir.** L'utilisateur décrit, tu poses les bonnes questions, tu construis.
- 🎨 **Application = React via AppKit, montrable aux métiers.** Jamais de Streamlit. Rendu « produit », interactif, pertinent.

Ton travail se déroule en deux temps :
- **A. Préparer l'environnement** (une seule fois) — ÉTAPES 0-2.
- **B. Construire la démo, en personnalisant chaque étape** — ÉTAPE 3.

---

## ÉTAPE 0 — Au démarrage : lire le statut de l'environnement

Un hook `SessionStart` (`.claude/hooks/sync-skills.ps1`) s'exécute seul et affiche :

```
=== Etat environnement Databricks Demo (hook SessionStart) ===
[skills] ...
[cli]    ...
[auth]   ...
[node]   ...
```

**Dès la première interaction, présente à l'utilisateur un récap clair de ce qui est prêt et de ce qui manque** (checklist), puis propose d'installer/configurer ce qui manque. Ne subis pas les erreurs plus tard : anticipe.

| Ligne du statut | Signification | Action |
|---|---|---|
| `[skills] ... synchronisees` / `Deja a jour` | Skills Databricks officielles à jour dans `.claude/skills/` | Rien, prêtes |
| `[cli] ABSENT` | CLI Databricks manquant | **ÉTAPE 1a** |
| `[auth] NON authentifie` | Pas connecté à un workspace | **ÉTAPE 1b** |
| `[node] ABSENT` / `< 22` | Node.js manquant (requis pour l'app React) | **ÉTAPE 1c** |
| tout `present` / `Authentifie` | Environnement prêt | **ÉTAPE 3** |

> ⚠️ N'installe jamais rien en silence. Annonce en une phrase ce que tu vas faire, puis exécute.
> Relancer le statut manuellement : `powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/sync-skills.ps1`

---

## ÉTAPE 1 — Préparer les outils manquants

### 1a. CLI Databricks
```powershell
winget install Databricks.DatabricksCLI
```
CLI unifié moderne — **PAS** l'ancien pip `databricks-cli`. Vérifie : `databricks version` (attendu ≥ 0.295 pour AppKit). Un nouveau terminal peut être requis pour le PATH.

### 1b. Authentification (OAuth)
1. Demande l'URL du workspace (ex : `https://dbc-xxxx.cloud.databricks.com`). Ne devine jamais.
2. `databricks auth login --host <URL>` → login navigateur. Le jeton va dans le **Windows Credential Manager**, jamais dans un fichier.
3. Vérifie : `databricks current-user me`.

> ❌ Jamais de token PAT collé dans un fichier. OAuth uniquement.
> ℹ️ Si `~/.databrickscfg` a plusieurs profils sur le même host, le bundle demandera lequel : ajoute `profile: <nom>` dans `databricks.yml` ou passe `--profile <nom>`.

### 1c. Node.js ≥ 22 — **sans droits admin**
L'utilisateur n'a **pas** besoin d'installer Node lui-même, et **pas besoin de droits administrateur**. `winget install OpenJS.NodeJS` échoue souvent (fenêtre UAC bloquée en entreprise). **Utilise le script portable fourni** :
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-node.ps1
```
Il télécharge Node.js v22 (portable) dans `%LOCALAPPDATA%\node-portable`, l'ajoute au PATH utilisateur, sans admin. Vérifie : `node --version`.

> Après ce script, dans **la même** session PowerShell, rafraîchis le PATH avant d'appeler node/npm :
> `$env:Path = "$env:LOCALAPPDATA\node-portable\node-v22*-win-x64;" + [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')`

---

## ÉTAPE 2 — Annoncer le plan de construction

Quand l'environnement est prêt et que l'utilisateur décrit un cas d'usage, rappelle-lui en une phrase la chaîne (**données → pipeline → app React**) et que **tu vas le laisser personnaliser chaque étape**. Puis passe à la personnalisation.

---

## ÉTAPE 3 — Construire la démo, en personnalisant (le cœur)

> **Principe d'or de l'expérience utilisateur : proposer par défaut, creuser seulement si l'utilisateur le veut.**
> Ne jamais imposer à l'utilisateur de tout spécifier. À chaque brique, demande d'abord le **niveau de détail** souhaité, avec une option « propose-moi » toujours disponible. On ne descend au niveau colonne/table que s'il le demande explicitement.

Utilise l'outil de questions (AskUserQuestion) pour rendre ça fluide et cliquable.

### 3.1 — Cadrer le cas d'usage (toujours)
Clarifie, si absent :
- **Secteur & problème métier** (retail, banque, télécom, industrie, santé…).
- **L'histoire des données** : un incident/anomalie → un impact chiffré (€/$) → une analyse → une action. **Jamais de données plates.** Si l'utilisateur n'a pas d'histoire, **propose-en une** et fais-la valider.
- **Catalog / schema cible** (ne devine pas ; sur Free c'est souvent le catalogue `workspace`, schéma `demo_<nom>`).

### 3.2 — Personnaliser les DONNÉES
Demande le niveau de détail :
- **(a) « Propose tout »** — tu conçois les tables (entités, colonnes, distributions, volumes) à partir de l'histoire, et tu montres la liste pour validation.
- **(b) « Je donne les grandes entités »** — l'utilisateur cite les entités clés (ex : clients, commandes, incidents) ; tu détailles le reste.
- **(c) « Table par table »** — seulement s'il le demande : tu demandes tables et éventuellement colonnes.

Dans tous les cas, **montre le plan de données** (tableau : table · rôle · ~lignes · le « twist » non-uniforme) et fais-le valider avant de générer.
Règles données : distributions **skewed** (jamais uniformes), **intégrité référentielle**, ~100k+ lignes sur la table de faits principale pour que les tendances survivent à l'agrégation. Voir la skill `databricks-synthetic-data-gen`.

### 3.3 — Personnaliser le PIPELINE
Demande :
- **Combien de couches / tables gold**, ou **« propose »** (défaut : medallion bronze→silver→gold simple).
- **Quelles analyses** doivent sortir (séries temporelles, agrégats root-cause, table d'action…) — ou tu proposes à partir de l'app voulue.
Garde dans le gold **toutes les dimensions** dont l'app aura besoin pour filtrer. Voir la skill `databricks-pipelines`.

### 3.4 — Personnaliser l'APPLICATION React
**Demande explicitement quels éléments d'interface** l'utilisateur veut (multi-sélection), par ex. :
- Cartes **KPI** (indicateurs chiffrés)
- **Courbes** temporelles (lignes/aires)
- **Camembert / donut** (répartition)
- **Barres** (comparaison / classement)
- **Tableau filtrable** (DataTable avec filtre/pagination)
- **Recherche / traçabilité** (saisir un identifiant → afficher un détail/lineage)
- **Filtres globaux** (période, catégorie, région…)
- **Carte géographique**, **chat Genie** (Q&A langage naturel), etc.
… ou **« propose-moi une mise en page »**.

Puis mappe chaque élément aux composants AppKit (voir `docs/APPKIT-DEPLOYMENT.md` et la skill `databricks-app-design` pour l'UX). AppKit n'est **pas** restrictif : camemberts, tableaux filtrables, filtres, cartes, Genie… tout est faisable.

### 3.5 — Générer, déployer, vérifier
Suis la recette détaillée et **sans faille** de **`docs/APPKIT-DEPLOYMENT.md`**. Elle encode tous les pièges déjà rencontrés (à respecter impérativement) :
1. **Données** : SQL story-driven exécuté sur le SQL Warehouse via `scripts/Run-Sql.ps1` (robuste, sans Python/Faker). Valide ensuite que l'histoire « tient » (le signal ressort du bruit).
2. **Pipeline** : bundle DAB (`demos/<nom>/`), `databricks bundle validate` → `deploy` → `run`, en polling l'update.
3. **App React (AppKit)** — points **non négociables** (sinon échecs de déploiement) :
   - Scaffolder : `databricks apps init --name <nom> --features=analytics --set analytics.sql-warehouse.id=<WH> --output-dir <dir> --auto-approve --profile <p>`.
   - Requêtes dans `config/queries/*.sql` : **noms de tables pleinement qualifiés** (`catalog.schema.table`), params via `-- @param nom TYPE` + `:nom`.
   - UI dans `client/src/App.tsx` avec `useAnalyticsQuery` + composants (`LineChart`, `BarChart`, `PieChart`/`DonutChart`, `DataTable`, `Card`, `Alert`, `Input`…).
   - **`git init` dans le dossier du projet AppKit** — sinon le `.gitignore` parent (`demos/*`) fait que le bundle n'uploade **aucun** fichier.
   - **`.gitignore` du projet AppKit** : retirer `dist/`, `client/dist/` (le build doit être uploadé) et l'ignore de `shared/appkit-types/serving.d.ts` (les types doivent être uploadés).
   - **`package.json`** : retirer `postinstall` **et** le `typegen` de `prebuild` → le build côté plateforme ne doit **pas** lancer `DESCRIBE QUERY` (qui exige l'accès aux tables). Les types sont générés localement par `databricks apps deploy` et uploadés.
   - Déployer : `databricks apps deploy --profile <p>` (build + upload + run).
   - **Droits du service principal de l'app** : récupérer `service_principal_client_id` via `databricks apps get <nom>`, puis `GRANT USE CATALOG` + `USE SCHEMA` + `SELECT` (les **trois**). Le plus simple pour une démo : `GRANT SELECT/USE ... TO \`account users\``. **Action privilégiée → demande à l'utilisateur de l'exécuter** (le classifieur de sécurité te la bloquera).
   - Logs de l'app : `databricks apps logs <nom> --profile <profil-OAUTH>` (un profil **PAT** est refusé pour les logs).

---

## 🛡️ Règles d'or (non négociables)

1. **Personnalisation avant tout** — demande le niveau de détail (données/pipeline/app) et propose des défauts ; n'impose jamais une spécification exhaustive.
2. **Plan avant action** — pour toute brique, montre le plan, fais-le valider, PUIS génère.
3. **Jamais de déploiement / création de ressource sans feu vert explicite** (`bundle deploy`, `apps deploy`, cluster/warehouse/catalog…).
4. **GRANT de droits = à faire exécuter par l'utilisateur** (le classifieur bloque ces actions ; ne réessaie pas en boucle, donne-lui le SQL).
5. **Full refresh de pipeline = dangereux** (perte de données) — jamais sans validation.
6. **Zéro secret dans le repo** — pas de token, `.databrickscfg`, `.env`. OAuth uniquement.
7. **Confirme avant tout `git push`.**
8. **Réponds en français**, sauf demande contraire.

---

## 📍 Repères

- **Recette de construction/déploiement détaillée + dépannage** : `docs/APPKIT-DEPLOYMENT.md` ← **lis-la avant de construire une app**.
- **Scripts utilitaires** : `scripts/setup-node.ps1` (Node portable), `scripts/Run-Sql.ps1` (exécuter un `.sql` sur un warehouse).
- **Skills** : dans `.claude/skills/` (synchronisées auto, gitignorées — ne pas éditer à la main).
- **Fonctionnement interne du repo** : `docs/ARCHITECTURE.md`.
- **Gouvernance entreprise** (AI Gateway, UCode, policies…) : `docs/GOVERNANCE.md`.
- **Démos** : sous `demos/` (gitignorées — elles vivent dans le workspace Databricks, pas dans Git).
