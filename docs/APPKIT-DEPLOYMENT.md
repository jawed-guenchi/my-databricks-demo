# Recette : construire & déployer une démo (données → pipeline → app React AppKit)

Guide de référence **testé et durci**. Il encode les pièges réels rencontrés pour qu'ils ne se reproduisent plus. À lire avant de construire une démo. Les questions de **personnalisation** (quelles tables, quel pipeline, quels éléments d'UI) sont décrites dans `CLAUDE.md` (ÉTAPE 3) — ce document couvre le **comment** technique.

Convention : `<WH>` = id du SQL Warehouse (`databricks warehouses list`), `<p>` = profil CLI, `<CAT>.<SCH>` = catalog.schema cible.

---

## 1. Données synthétiques (SQL sur le SQL Warehouse)

**Pourquoi SQL et pas Spark+Faker en local ?** Sur un poste sans Python 3.12 / sans `databricks-connect`, la génération en **SQL pur sur le warehouse** est la plus robuste : aucune dépendance locale, tout tourne côté Databricks, 100 % reproductible.

1. Écris `demos/<nom>/setup/generate_data.sql` :
   - `CREATE SCHEMA IF NOT EXISTS <CAT>.<SCH>;` puis un `CREATE OR REPLACE TABLE <CAT>.<SCH>.<table> AS SELECT ...` par table.
   - **Noms pleinement qualifiés** (`<CAT>.<SCH>.<table>`) — chaque instruction est exécutée dans une session indépendante.
   - Génère avec `range(...)`, `rand()`, `CASE WHEN`, `element_at(array(...), ...)`, `date_add(...)`, `pmod(hash(...), n)` pour les FK.
   - **Distributions non-uniformes** (skew 80/20, log-normal via `exp(...)`), **intégrité référentielle** (FK par `pmod(hash(id), N)` ou jointure), et **injecte l'anomalie** de l'histoire (ex. un lot défectueux sur une fenêtre de dates) pour qu'un signal net ressorte.
   - Master tables d'abord, puis tables enfants qui les référencent.
2. Exécute :
   ```powershell
   ./scripts/Run-Sql.ps1 -SqlFile demos/<nom>/setup/generate_data.sql -WarehouseId <WH> -Profile <p>
   ```
3. **Valide que l'histoire tient** (écris `demos/<nom>/setup/validate.sql`, lance avec `-ShowResults`) : compte des lignes, et surtout **le signal ressort du bruit** (ex. taux d'incident ×N sur le segment touché, pic temporel visible). Si tout est plat → la donnée ne raconte rien, refais les distributions.

---

## 2. Pipeline Lakeflow (bundle DAB)

1. `demos/<nom>/databricks.yml` : `bundle.name`, `variables` (catalog, schema, warehouse_id), `targets.dev` (avec `profile: <p>` si plusieurs profils matchent le host), `include: [resources/*.yml]`.
2. `demos/<nom>/src/pipeline/*.sql` : un dataset par fichier. `CREATE OR REFRESH MATERIALIZED VIEW <nom> AS SELECT ...` (batch) ou `STREAMING TABLE` (flux). Lire les tables sources en **pleinement qualifié**, les datasets frères par nom simple. **Garde dans le gold toutes les dimensions filtrables par l'app.**
3. `demos/<nom>/resources/<nom>.pipeline.yml` :
   ```yaml
   resources:
     pipelines:
       <nom>_pipeline:
         name: <nom>-${bundle.target}
         catalog: ${var.catalog}
         schema: ${var.schema}
         serverless: true
         libraries:
           - glob: { include: ../src/pipeline/** }
   ```
4. `databricks bundle validate` → `databricks bundle deploy` → `databricks bundle run <nom>_pipeline`. **Poll l'update** (le CLI le fait), attends `COMPLETED`.

---

## 3. Application React (AppKit) — recette sans faille

> Chaque point marqué ⛔ correspond à une erreur réelle qui casse le déploiement. Ne les saute pas.

### 3.1 Scaffolder (non-interactif)
```powershell
databricks apps init --name <nom>-app `
  --features=analytics `
  --set analytics.sql-warehouse.id=<WH> `
  --output-dir demos/<nom>/react-app `
  --auto-approve --profile <p>
```
Crée un projet TypeScript+React sous `demos/<nom>/react-app/<nom>-app/` et lance `npm install`. Node ≥ 22 requis (voir `scripts/setup-node.ps1`).

### 3.2 Écrire les requêtes — `config/queries/*.sql`
- Une requête = un fichier ; la clé = le nom sans `.sql`.
- **Tables pleinement qualifiées** (`<CAT>.<SCH>.<table>`).
- Paramètres : entête `-- @param nom TYPE` (STRING, INT, DATE…) puis `:nom` dans le SQL.
- Pour un graphe multi-séries, renvoie un format **large** : une colonne d'axe X + une colonne numérique par série.
- Exécution en **service principal** par défaut (fichier `*.sql`) ; `*.obo.sql` = au nom de l'utilisateur.

### 3.3 Construire l'UI — `client/src/App.tsx`
- Hook data : `const { data, loading, error } = useAnalyticsQuery('clef', params)` — **`params` doit être `useMemo`isé** (sinon refetch en boucle). Pour une requête sans param, passe une constante `{}` définie hors composant.
- Composants graphes (import `@databricks/appkit-ui/react`) : `LineChart`, `AreaChart`, `BarChart`, `PieChart`, `DonutChart`, `RadarChart`, `ScatterChart`, `HeatmapChart` — props : `queryKey`, `parameters`, `xKey`, `yKey` (string|string[]), `colors`, `title`, `showLegend`, `stacked`, `height`…
- `DataTable` (tableau filtrable/paginé) : props `queryKey`, `parameters` (obligatoire), `filterColumn`, `pageSize`, `labels`.
- Primitives UI : `Card/CardHeader/CardTitle/CardContent`, `Input`, `Button`, `Select`, `Badge`, `Alert`, `Skeleton`, `Tabs`, `Label`… (liste dans `node_modules/@databricks/appkit-ui/CLAUDE.md`).
- `sql` helpers (`@databricks/appkit-ui/js`) : `sql.string(...)`, `sql.number(...)`, `sql.date(...)` pour binder les params.
- Icônes : `lucide-react`. Style : classes Tailwind.
- Vérifie les exports avant d'importer : `grep <Composant> node_modules/@databricks/appkit-ui/dist/react/index.d.ts`.

### 3.4 ⛔ Corrections OBLIGATOIRES avant déploiement
Ces trois points ont chacun cassé un déploiement :

1. **`git init` dans le dossier du projet AppKit.**
   Le repo parent gitignore `demos/*`. Le bundle Databricks respecte le `.gitignore` du repo Git **parent** → il considère tout le projet comme ignoré et **n'uploade aucun fichier** (dossier `files` vide → « no files found »). `git init` dans `demos/<nom>/react-app/<nom>-app/` fait de ce dossier sa propre racine Git ; le `.gitignore` parent ne s'applique plus.

2. **`.gitignore` du projet AppKit** — retire ces lignes :
   - `dist/` et `client/dist/` → le **build compilé doit être uploadé** (l'app l'exécute au runtime).
   - `shared/appkit-types/serving.d.ts` → **les types doivent être uploadés** (sinon `tsc` échoue côté plateforme).
   (Garde `node_modules/` ignoré : la plateforme réinstalle.)

3. **`package.json`** — le build côté plateforme ne doit **pas** avoir besoin d'accéder aux tables :
   - Supprime le script **`postinstall`** (`npm run typegen`).
   - Dans **`prebuild`**, retire `typegen` (garde `sync`) : `"prebuild": "npm run sync"`.
   Raison : `typegen` lance `DESCRIBE QUERY` sur les tables ; pendant `npm install`/`build` sur la plateforme, le service principal n'y a pas (encore) accès → le build échoue. Les types sont générés **localement** par l'étape « Generating types » de `databricks apps deploy` puis uploadés — inutile de les régénérer sur la plateforme.

### 3.5 Déployer
```powershell
databricks apps deploy --profile <p>
```
Pipeline : build local (types + tsc + bundle) → upload → run. Attends `App started successfully` + l'URL.

### 3.6 ⛔ Droits du service principal de l'app
L'app interroge les tables **en tant que son service principal**. Il faut lui donner **les trois** privilèges Unity Catalog (SELECT seul ne suffit pas) :
```powershell
databricks apps get <nom>-app --profile <p>   # -> service_principal_client_id
```
Puis (le plus simple pour une démo — couvre toutes les apps/futurs SP sur ce schéma) :
```sql
GRANT USE CATALOG ON CATALOG <CAT> TO `account users`;
GRANT USE SCHEMA  ON SCHEMA  <CAT>.<SCH> TO `account users`;
GRANT SELECT      ON SCHEMA  <CAT>.<SCH> TO `account users`;
```
ou, restreint au SP : remplacer `` `account users` `` par le `service_principal_client_id`.

> ⚠️ **Ces `GRANT` sont une action privilégiée : le classifieur de sécurité de Claude Code les bloque.** Ne réessaie pas en boucle — **donne le SQL à l'utilisateur** pour qu'il l'exécute dans l'éditeur SQL Databricks, puis reprends.

### 3.7 Vérifier
Demande à l'utilisateur d'ouvrir l'URL. En cas de souci : `databricks apps logs <nom>-app --profile <profil-OAUTH>` (⚠️ un profil **PAT** est refusé pour les logs — utilise un profil OAuth).

---

## Dépannage (symptôme → cause → fix)

| Symptôme | Cause | Fix |
|---|---|---|
| `apps deploy` : « no files found » / dossier `files` vide | `.gitignore` parent (`demos/*`) fait tout ignorer au bundle | `git init` dans le projet AppKit (§3.4-1) |
| Build plateforme échoue : « Type generation failed … DESCRIBE QUERY » | `postinstall`/`prebuild` lance `typegen` → besoin d'accès tables au build | Retirer `postinstall` + `typegen` de `prebuild` (§3.4-3) |
| App démarre mais panneaux de données en erreur | Service principal sans droits UC | Les 3 `GRANT` (§3.6) — à faire exécuter par l'utilisateur |
| `apps logs` : « OAuth Token not supported for current auth type pat » | Logs appelés avec un profil PAT | Utiliser un profil **OAuth** (`databricks auth login`) |
| `bundle validate` : « multiple profiles matched » | Plusieurs profils sur le même host | Ajouter `profile: <p>` dans `databricks.yml` ou `--profile <p>` |
| `typegen` échoue au 1er essai puis marche | Warehouse en démarrage à froid | Relancer ; c'est transitoire |
| App runtime : refetch en boucle / clignote | `parameters` non mémoïsé | `useMemo` sur les params (§3.3) |
| `winget install NodeJS` : exit 1602 / UAC annulé | Élévation admin bloquée | `scripts/setup-node.ps1` (Node portable, sans admin) |
| `DESCRIBE QUERY` / requête : `TABLE_OR_VIEW_NOT_FOUND` | Nom non qualifié dans une session indépendante | Pleinement qualifier `<CAT>.<SCH>.<table>` |

---

## Rappel des scripts utilitaires
- `scripts/setup-node.ps1` — installe Node.js v22 portable (sans admin).
- `scripts/Run-Sql.ps1 -SqlFile <f> -WarehouseId <WH> [-Profile <p>] [-ShowResults]` — exécute un `.sql` sur un warehouse.
