---
name: audit-pc-quotidien
description: >
  Audit quotidien complet des performances et de la santé d'un PC Windows,
  exécuté via Claude Code sur la machine (manuellement ou par tâche planifiée
  à 8h00). Collecte les métriques système (CPU, RAM, GPU, températures, SMART,
  espace disque, pilotes, Windows Update, sécurité Defender, réseau, journaux
  d'événements, logiciels à mettre à jour), calcule une note de santé sur 100,
  génère un rapport quotidien priorisé et maintient un historique pour détecter
  les dégradations dans le temps. Déclencher DÈS QUE l'utilisateur demande :
  "audit du PC", "audit quotidien", "état du PC", "santé du PC", "check du PC",
  "vérifie mon ordinateur", "rapport PC", "performances du PC", "mon PC rame",
  "températures", "état des disques", "SMART", "pilotes à jour", "nettoyage PC",
  "espace disque", "pourquoi le PC est lent", "installer l'audit planifié",
  ou toute demande de diagnostic, maintenance ou optimisation Windows.
compatibility: >
  Claude Code sur Windows 10/11. PowerShell 5.1+ requis. Températures via
  LibreHardwareMonitor (optionnel). Certaines mesures nécessitent une console
  administrateur (SMART complet, SFC/DISM).
---

# Audit PC quotidien

Skill de contrôle quotidien des performances d'un PC Windows. Deux modes :

- **Interactif** : l'utilisateur demande un audit dans Claude Code → exécuter le workflow complet ci-dessous.
- **Headless (tâche planifiée à 8h00)** : `run-audit.cmd` a déjà lancé la collecte ; Claude reçoit un prompt du type « les métriques du jour sont dans %USERPROFILE%\AuditPC\donnees\ » → passer directement à l'étape 3 (Analyse). En headless, ne pas exécuter de commandes : uniquement lire les fichiers et écrire le rapport.

## Dossiers de travail

Tout vit dans `%USERPROFILE%\AuditPC\` :

```
AuditPC/
├── donnees/      → metriques-AAAA-MM-JJ.json (sortie brute de la collecte)
├── rapports/     → rapport-AAAA-MM-JJ.md + ALERTE-AAAA-MM-JJ.md si critique
└── historique.csv → une ligne par jour (tendances)
```

Créer ces dossiers s'ils n'existent pas.

## Workflow

### Étape 1 — Collecte (mode interactif uniquement)

Exécuter le script de collecte du skill :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<dossier-du-skill>\scripts\collect-metrics.ps1"
```

Il écrit `%USERPROFILE%\AuditPC\donnees\metriques-AAAA-MM-JJ.json`. Chaque section est enveloppée dans un try/catch : une section en échec contient un champ `erreur` au lieu de faire planter le tout. La collecte prend 1 à 3 minutes (Windows Update et winget sont lents).

Si la console n'est pas administrateur, le JSON contient `"admin": false` : signaler dans le rapport que SMART détaillé et certains compteurs sont partiels, et proposer de relancer en admin.

### Étape 2 — Vérifications complémentaires (interactif, si pertinent)

- **Pilotes vs fabricants** : uniquement en interactif, et au plus une fois par semaine (vérifier la date du dernier contrôle dans `historique.csv`, colonne `pilotes_verifies`). Faire une recherche web pour la carte graphique et le chipset uniquement (les autres pilotes passent par Windows Update). Indiquer version installée, dernière version, date, priorité et lien officiel (nvidia.com, amd.com, intel.com, site du fabricant de la carte mère).
- **SFC / DISM** : ne jamais lancer automatiquement. Si le JSON montre des erreurs CBS, des erreurs disque ou des crashs récents, recommander dans les « Actions prioritaires » : `sfc /scannow` puis `DISM /Online /Cleanup-Image /RestoreHealth` en console administrateur. Les lancer seulement si l'utilisateur le demande explicitement.
- **Nettoyage** : le JSON estime l'espace récupérable. Proposer, ne jamais supprimer sans accord explicite.

### Étape 3 — Analyse

1. Lire le JSON du jour dans `donnees\`.
2. Lire `references/seuils-et-score.md` pour les seuils d'anomalie et le barème de la note /100.
3. Lire les 7 derniers JSON (ou moins) et `historique.csv` pour la tendance : dégradation d'usure SSD, températures qui montent, RAM de plus en plus chargée, temps de démarrage qui s'allonge, espace disque qui fond. Signaler toute dérive sur 7 jours même si les valeurs absolues restent sous les seuils.
4. Calculer la note /100 selon le barème. Ne pas improviser d'autres pondérations : la note doit être comparable d'un jour à l'autre.

### Étape 4 — Rapport

Écrire `rapports\rapport-AAAA-MM-JJ.md` en suivant EXACTEMENT le gabarit de `references/modele-rapport.md`. Puis ajouter une ligne à `historique.csv` (créer avec l'en-tête si absent) :

```
date;note;niveau;cpu_pct;ram_pct;temp_cpu;temp_gpu;disque_sys_libre_pct;usure_ssd_pct;erreurs_critiques_24h;maj_windows_en_attente;apps_a_jour;espace_recuperable_go;pilotes_verifies
```

`niveau` ∈ {Excellent, Bon, Moyen, Critique}. Valeurs inconnues : `NA`. `pilotes_verifies` : `oui` seulement si le contrôle fabricants a été fait ce jour.

En mode interactif, afficher aussi le rapport dans la conversation (résumé + actions prioritaires, pas besoin de recopier tout le fichier).

### Étape 5 — Alerte critique

Si au moins un critère CRITIQUE de `references/seuils-et-score.md` est atteint (SMART en échec ou usure ≥ 90 %, température soutenue excessive, Defender/temps réel désactivé, BSOD dans les 24 h, disque système < 5 % libre) :

1. Écrire `rapports\ALERTE-AAAA-MM-JJ.md` : liste des problèmes critiques + actions recommandées, rien d'autre. (`run-audit.cmd` détecte ce fichier et affiche une boîte de dialogue Windows.)
2. En interactif, ouvrir le rapport par la section alerte, en premier.

Une alerte matérielle (SMART, température) prime toujours sur le reste : la recommander en action n° 1 avec sauvegarde immédiate des données si le disque est en cause.

## Installation de la tâche planifiée

Quand l'utilisateur demande l'installation de l'audit automatique :

1. Vérifier que le skill est bien présent dans `%USERPROFILE%\.claude\skills\audit-pc-quotidien\` (les scripts doivent être sur le disque, pas seulement dans le profil claude.ai).
2. Exécuter en console administrateur :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<dossier-du-skill>\scripts\install-tache-planifiee.ps1"
```

Le script crée la tâche « AuditPC-Quotidien » à 8h00 (avec `StartWhenAvailable` : si le PC était éteint, l'audit part au prochain démarrage). La tâche lance `run-audit.cmd`, qui enchaîne collecte puis `claude -p` avec des outils restreints (`Read,Write,Edit,Glob`) et journalise dans `AuditPC\logs\`.

3. Pour les températures, vérifier que LibreHardwareMonitor est configuré : lancé au démarrage de Windows, option « Remote Web Server » activée (port 8085). Sinon, guider l'utilisateur : téléchargement depuis le dépôt GitHub officiel LibreHardwareMonitor, Options → Run On Windows Startup + Remote Web Server. Sans LHM, les températures sont marquées `NA` et exclues de la note.

## Règles de conduite

- **Jamais de modification sans accord** : pas de suppression de fichiers, pas de désactivation de service ou de programme au démarrage, pas d'installation de pilote. L'audit observe et recommande ; l'utilisateur décide.
- **Priorité aux faits mesurés** : chaque anomalie citée dans le rapport doit correspondre à une valeur du JSON. Ne pas inventer de problème plausible.
- **Tendance > instantané** : un CPU à 60 % au moment de la collecte n'est pas une anomalie ; un CPU moyen qui passe de 15 % à 45 % en une semaine, si.
- **Sections manquantes** : si une section du JSON contient `erreur`, l'indiquer dans le rapport (avec la cause probable : droits admin, LHM absent, réseau coupé) sans pénaliser la note, sauf si l'information manquante est elle-même le symptôme (ex. Defender injoignable).
- **Concision** : le rapport doit se lire en 2 minutes. Les détails bruts restent dans le JSON.

## Fichiers du skill

| Fichier | Quand le lire / l'exécuter |
|---|---|
| `scripts/collect-metrics.ps1` | Étape 1, ou déjà exécuté par la tâche planifiée |
| `scripts/run-audit.cmd` | Lancé par la tâche planifiée (ne pas lancer à la main sauf test) |
| `scripts/install-tache-planifiee.ps1` | À la demande d'installation, console admin |
| `references/seuils-et-score.md` | Toujours, à l'étape 3 |
| `references/modele-rapport.md` | Toujours, à l'étape 4 |
