# Gouvernance & usage entreprise (roadmap)

Ce starter est pensé pour un usage **rapide et individuel** (démos, pitchs). Pour un déploiement **à l'échelle entreprise** — plusieurs collaborateurs, données sensibles, maîtrise des coûts — il faut ajouter une couche de gouvernance. Ce document liste les briques recommandées. **Rien ici n'est encore implémenté** ; c'est une feuille de route.

## Rappel : deux niveaux d'usage

| Usage | Stack suffisante |
|---|---|
| **Projet perso / démo** | Claude Code + Databricks CLI (OAuth) + Agent Skills. C'est ce que fournit ce repo aujourd'hui. |
| **Projet entreprise** | Ajouter : AI Gateway + UCode + Service Policies + guardrails, pour gouvernance, budget et sécurité. |

## Briques entreprise à ajouter

### AI Gateway
Couche centrale pour **sécurité, gouvernance, suivi des coûts** et traçabilité des appels aux modèles. Point de passage unique pour gouverner l'usage de l'IA (quotas, logs, budgets).

### UCode — authentification & gouvernance
Gère l'**authentification** et la gouvernance des agents.
Réf : [github.com/databricks/ucode](https://github.com/databricks/ucode)

### Service Policies
Limiter ce que les agents ont le droit de faire : **bloquer certaines actions**, restreindre l'accès à certaines ressources / catalogues. Principe du moindre privilège appliqué aux agents.

### Guardrails (garde-fous contenu)
Mettre en place des protections sur le **contenu sensible** (entrées/sorties des modèles) pour éviter fuites de données ou usages non conformes.

### Smart Scaling
Optimiser l'usage du compute (montée/descente en charge automatique) pour **maîtriser les coûts** sans dégrader l'expérience.

## Principe directeur

Appliquer le **moindre privilège** aux agents et **tout tracer** (coûts, actions, accès). En entreprise, l'agent ne doit pouvoir agir que dans un périmètre explicitement autorisé, avec un suivi des coûts et des garde-fous sur les données sensibles.

## Pistes complémentaires à évaluer

- **DAB (Databricks Asset Bundles)** — déjà adopté ici : toute la structure du projet « as code » (déploiement, config). C'est la base d'une gouvernance reproductible.
- **Genie / Genie Code / Genie App Builder** — utiles pour accélérer la création rapide de pipelines, dashboards, Genie Spaces et autres objets Databricks (moins adaptés au développement d'applications complètes).

## Prochaines étapes suggérées

1. Choisir un **workspace Databricks partagé** pour l'équipe (plutôt qu'un compte perso).
2. Prototyper **UCode + AI Gateway** sur ce workspace.
3. Définir des **Service Policies** correspondant à ce que les agents ont le droit de faire pour des démos.
4. Ajouter des **guardrails** sur les données sensibles.
