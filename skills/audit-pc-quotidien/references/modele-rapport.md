# Gabarit du rapport quotidien

Utiliser EXACTEMENT cette structure (remplacer les crochets). Omettre une sous-section seulement si la donnée est absente du JSON, en le mentionnant dans « Limites de l'audit ».

```markdown
# Audit PC — [AAAA-MM-JJ]

## Santé globale : [note]/100 — [🟢|🟡|🟠|🔴] [Excellent|Bon|Moyen|Critique]

[Si alerte critique : bloc « ⚠️ ALERTE » ici, en premier, avec les problèmes et l'action immédiate.]

## Résumé
[3 à 6 phrases : état général, ce qui a changé depuis hier/7 jours, les points d'attention.]

## Actions prioritaires
1. [Action la plus urgente — pourquoi — comment]
2. [...]
[Classées par urgence réelle. 0 action = l'écrire explicitement. Maximum 6.]

## Détail

### État général
| Mesure | Valeur | Tendance 7 j | Statut |
|---|---|---|---|
| Temps de démarrage | | | |
| CPU | | | |
| RAM | | | |
| GPU | | | |
| Temp. CPU / GPU | | | |
| Disques (libre) | | | |
| SMART / usure SSD | | | |

### Sécurité
[Defender, temps réel, signatures, dernière analyse, pare-feu — une ligne chacun.]

### Mises à jour
[Windows : version, mises à jour en attente, dernier redémarrage. Applications winget obsolètes : liste courte. Pilotes : état, et si contrôle fabricants fait cette semaine, tableau version installée / disponible / lien.]

### Stabilité
[Erreurs critiques 24 h, erreurs disque, crashs/BSOD, WHEA. « RAS » si rien.]

### Performances et démarrage
[Programmes au démarrage superflus (nom + impact), processus gourmands anormaux, recommandations SANS application automatique.]

### Nettoyage
[Espace récupérable estimé : détail par poste + total. Proposition, pas d'action.]

### Réseau
[Latence, perte, DNS, débit lien. Anomalies éventuelles.]

## Limites de l'audit
[Sections en erreur ou absentes : cause probable et remède (admin, LHM, etc.). « Aucune » sinon.]
```

Règles :
- Tendance : ↗ (dégradation), ↘ (amélioration), → (stable), NA (pas d'historique).
- Statut : ✅ / ⚠️ / ❌ selon les seuils de `seuils-et-score.md`.
- Chiffres arrondis lisibles (Go au dixième, % entiers, °C entiers).
- Aucune donnée inventée : tout vient du JSON ou de l'historique.
