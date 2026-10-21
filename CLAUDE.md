# Consignes

## Règles

1. Ne fais jamais le travail toi-même.
2. Délègue toujours à des sub-agents.
3. N'utilise pas constamment Fable.
4. Utilise Opus 5.5 pour les tâches les plus simples.
Exception aux règles 1 et 2 : en mode headless (claude -p), ou si l’outil de sub-agents n’est pas disponible, fais le travail toi-même. C’est le cas de l’audit planifié audit-pc-quotidien.
## Routage des modèles

- Code simple, résumés = Opus 5.5
- Architecture, refacto = Fable 5.1
- Contexte minimal pour chaque sub-agent
- Résume chaque résultat en 3 lignes

## Vérification

- Relis le diff avant de conclure
