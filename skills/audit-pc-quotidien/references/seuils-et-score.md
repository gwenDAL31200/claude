# Seuils d'anomalie et barème de notation

## Niveaux

| Note | Niveau |
|---|---|
| 90–100 | 🟢 Excellent |
| 75–89 | 🟡 Bon |
| 55–74 | 🟠 Moyen |
| 0–54 | 🔴 Critique |

Toute condition CRITIQUE (section finale) plafonne la note à 54 maximum, quel que soit le total.

## Barème (départ : 100 points, on retranche)

### Stockage et SMART (max −25)

| Constat | Retrait |
|---|---|
| Disque système libre < 15 % | −5 |
| Disque système libre < 10 % | −10 (remplace le −5) |
| Autre disque libre < 10 % | −3 par disque (max −6) |
| Usure SSD 50–79 % | −5 |
| Usure SSD 80–89 % | −12 |
| Erreurs de lecture/écriture SMART > 0 | −10 |
| Tendance : usure +2 pts ou plus en 7 jours | −5 |

### Sécurité (max −20)

| Constat | Retrait |
|---|---|
| Signatures antivirus > 7 jours | −5 |
| Dernière analyse rapide > 14 jours | −3 |
| Un profil de pare-feu désactivé | −6 |
| Menace détectée non traitée | −15 |

### Stabilité / événements (max −20)

| Constat | Retrait |
|---|---|
| 1–5 erreurs critiques (niveau 1–2) en 24 h | −4 |
| > 5 erreurs critiques en 24 h | −8 |
| Erreurs disque (source disk/ntfs/storahci) en 24 h | −8 |
| Arrêt inattendu Kernel-Power 41 en 24 h | −6 |
| Erreur matérielle WHEA en 7 jours | −8 |

### Mises à jour (max −15)

| Constat | Retrait |
|---|---|
| Mises à jour Windows importantes en attente | −5 |
| Mise à jour de sécurité en attente | −8 (remplace le −5) |
| Redémarrage en attente depuis > 7 jours | −4 |
| ≥ 5 applications winget obsolètes | −3 |
| Pilote GPU en retard de plus de 2 versions majeures (si vérifié) | −4 |

### Températures (max −10, seulement si mesurées)

| Constat | Retrait |
|---|---|
| CPU 80–89 °C au repos/bureautique | −5 |
| CPU ≥ 90 °C | −10 |
| GPU ≥ 85 °C hors charge de jeu | −5 |
| Tendance : +5 °C ou plus de moyenne en 7 jours | −4 |

### Performances (max −10)

| Constat | Retrait |
|---|---|
| RAM utilisée > 85 % | −4 |
| CPU moyen > 70 % sans charge identifiée | −4 |
| > 12 programmes au démarrage | −3 |
| Temps de démarrage > 90 s ou +30 s vs moyenne 7 j | −3 |

### Réseau (max −5)

| Constat | Retrait |
|---|---|
| Perte de paquets > 2 % | −3 |
| Latence moyenne > 60 ms vers 1.1.1.1 | −2 |
| Résolution DNS > 200 ms | −2 |

## Conditions CRITIQUES (alerte immédiate + note ≤ 54)

- SMART : `PredictiveFailure` vrai, ou usure SSD ≥ 90 %, ou erreurs non corrigées > 0
- Température CPU ≥ 95 °C ou GPU ≥ 95 °C
- Defender : service antivirus ou protection temps réel désactivés
- Menace active détectée par Defender
- BSOD (BugCheck 1001 ou minidump) dans les dernières 24 h
- Disque système < 5 % d'espace libre

## Estimation de l'espace récupérable

Somme des tailles mesurées : `%TEMP%` + `C:\Windows\Temp` + `SoftwareDistribution\Download` + corbeille + caches navigateurs + journaux > 30 jours. Arrondir au dixième de Go. Si > 5 Go, en faire une action recommandée (jamais automatique).
