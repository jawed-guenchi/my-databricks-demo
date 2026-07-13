# 🎯 Databricks Demo Starter

> Créez une **démo Databricks complète** (fausses données réalistes + pipeline + application) pour un pitch client, en **quelques heures au lieu de plusieurs jours** — simplement en la décrivant à Claude Code en français.

Ce repo est un **point de départ prêt à l'emploi** pour toute l'équipe. Vous clonez, vous ouvrez dans VS Code, et vous discutez avec Claude Code : il s'occupe d'installer ce qu'il faut, de se connecter à Databricks, et de construire la démo avec vous.

---

## 🧩 C'est quoi, concrètement ?

Quand vous décrivez une démo (« un cas de churn client pour un opérateur télécom », « de la détection de fraude pour une banque »…), Claude Code produit, **étape par étape et avec votre validation** :

1. 🗃️ **De fausses données réalistes** qui racontent une histoire métier (un incident, un impact en €, une analyse possible).
2. 🔄 **Un pipeline** de transformation (Lakeflow / Spark) qui prépare ces données.
3. 🖥️ **Une application web React** (via AppKit, le SDK Databricks) — soignée et interactive, **pensée pour être montrée aux métiers**, pas un simple prototype.

Le tout est structuré « as code » (Databricks Asset Bundles), donc **déployable et réutilisable**.

---

## ✅ Prérequis (poste Windows)

| Il vous faut… | Détail |
|---|---|
| **VS Code + extension Claude Code** | L'extension `anthropic.claude-code` |
| **git** et **winget** | Fournis avec Windows 11 |
| **Un workspace Databricks** | Un compte [Databricks Free](https://www.databricks.com/learn/free-edition) suffit pour commencer |

> 💡 Vous **n'avez pas besoin** d'installer à l'avance le CLI Databricks, **Node.js** (nécessaire aux apps React) ni de configurer la connexion : Claude Code détecte ce qui manque au premier lancement et vous guide pour tout installer. Ce starter est prévu pour **Windows** (le script d'automatisation est en PowerShell).

---

## 🚀 Démarrer en 3 étapes

### 1. Cloner et ouvrir dans VS Code
```bash
git clone https://github.com/jawed-guenchi/my-databricks-demo.git
```
Ouvrez le dossier dans VS Code. Si une bannière « **Do you trust the authors of this folder?** » apparaît, cliquez **Yes / Trust** — c'est indispensable pour que l'automatisation démarre.

### 2. Ouvrir Claude Code et se laisser guider
Lancez Claude Code dans ce dossier. À l'ouverture, un script se lance **tout seul** : il met à jour les compétences Databricks et vérifie votre environnement. Claude vous présente alors une **checklist** de ce qui est prêt et de ce qui manque, et propose de tout mettre en place :

- **CLI Databricks** manquant → Claude l'installe.
- **Node.js** manquant (nécessaire à l'app React) → Claude installe une version **portable, sans droits administrateur** (aucune fenêtre Windows à valider).
- **Pas connecté** → Claude vous demande l'URL de votre workspace et lance une connexion sécurisée dans le navigateur (**OAuth** — aucun mot de passe ni jeton n'est stocké dans le repo).

Vous n'avez qu'à **suivre ce qu'il propose et valider**.

### 3. Décrire votre démo… et la personnaliser étape par étape
Dites simplement ce que vous voulez, par exemple :

> « Fais-moi une démo pour un client de la **grande distribution** : une rupture de stock qui fait chuter le chiffre d'affaires. »

Ensuite, **Claude vous fait personnaliser chaque étape** (sans jamais vous imposer de tout spécifier — vous pouvez toujours répondre « propose-moi ») :

- 🗃️ **Les données** — Claude conçoit les tables, ou vous les cadrez (jusqu'au niveau table si vous le souhaitez).
- 🔄 **Le pipeline** — quelles transformations / analyses, combien de couches.
- 🖥️ **L'application** — quels éléments d'interface : **KPI, courbes, camembert, barres, tableau filtrable, recherche/traçabilité, filtres…**

À chaque étape, Claude **présente un plan que vous validez** avant qu'il génère. **Rien n'est déployé sur votre workspace sans votre accord explicite.**

---

## 🔒 Ce que le repo garantit

- **Personnalisable de bout en bout** : Claude vous fait choisir le niveau de détail à chaque étape (données, pipeline, interface), sans jamais vous forcer à tout spécifier.
- **Aucune install manuelle ni droits admin** : CLI, Node.js (portable) et connexion sont mis en place par Claude.
- **Compétences toujours à jour** : à chaque session, toutes les [Databricks Agent Skills](https://github.com/databricks/databricks-agent-skills) officielles sont resynchronisées automatiquement. Rien à maintenir.
- **Sécurité** : connexion par OAuth ; vos identifiants restent dans le gestionnaire d'identifiants de Windows, **jamais dans le repo**. Aucun secret n'est commité.
- **Garde-fous** : Claude propose toujours un plan avant d'agir, et ne déploie / ne crée jamais de ressources dans votre workspace sans confirmation.
- **Reproductible** : chaque démo vit dans son propre dossier `demos/<nom>/` sous forme de bundle déployable.

---

## 🗂️ Structure du repo

```
├── README.md               ← vous êtes ici (guide humain)
├── CLAUDE.md               ← les instructions que Claude Code suit automatiquement
├── .claude/
│   ├── settings.json       ← déclenche la mise à jour des skills à chaque session
│   ├── hooks/sync-skills.ps1 ← synchronise les skills + vérifie l'environnement
│   └── skills/             ← skills Databricks (remplies automatiquement, non versionnées)
├── scripts/
│   ├── setup-node.ps1      ← installe Node.js portable (sans admin)
│   └── Run-Sql.ps1         ← exécute un fichier .sql sur un SQL Warehouse
├── demos/                  ← vos démos client (une par sous-dossier, non versionnées)
└── docs/
    ├── APPKIT-DEPLOYMENT.md ← recette détaillée données→pipeline→app + dépannage
    ├── ARCHITECTURE.md      ← comment ça marche en détail
    └── GOVERNANCE.md        ← usage entreprise (sécurité, coûts, gouvernance)
```

---

## ❓ FAQ rapide

**Où sont les compétences (« skills ») Databricks ?**
Elles ne sont pas dans Git : le script `sync-skills.ps1` les télécharge dans `.claude/skills/` à chaque démarrage, toujours à la dernière version. C'est **normal** que ce dossier soit vide juste après le clone — il se remplit à la première session.

**Le script `.ps1` est-il partagé ?**
Oui, il est **versionné dans le repo** (c'est le mécanisme). Ce qu'il *produit* (les skills) est régénéré localement.

**Faut-il des droits administrateur ?**
Non. Node.js est installé en version **portable** dans votre profil utilisateur (script `scripts/setup-node.ps1`) — aucune fenêtre d'élévation Windows.

**Puis-je tout personnaliser, ou c'est imposé ?**
Tout est personnalisable : les tables, le pipeline, et l'interface de l'app (KPI, camembert, tableau filtrable, filtres, recherche…). Claude vous demande le niveau de détail voulu et propose des défauts — vous ne subissez rien.

**Je suis sur Mac ?**
Ce starter cible Windows (scripts PowerShell). Sur Mac, dites-le à Claude Code pour adapter les scripts.

**Ça a coûté / déployé quelque chose sans que je le veuille ?**
Non. Toute création de ressource dans votre workspace passe par une confirmation explicite.

---

## 📚 Pour aller plus loin

- **Comment ça marche en détail** → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Usage entreprise (gouvernance, sécurité, coûts)** → [docs/GOVERNANCE.md](docs/GOVERNANCE.md)
- **Les règles que Claude Code applique** → [CLAUDE.md](CLAUDE.md)
