# Window Council

Plugin [xbar](https://xbarapp.com) qui dit s'il faut ouvrir ou fermer les fenêtres. Il confronte tes objectifs de confort intérieur (température et humidité) à l'air extérieur (mesures MétéoSuisse à Pully), à partir des valeurs de ton hygromètre.

| Barre de menu | Signification |
|---|---|
| `🪟✅` | Ouvrir : l'air extérieur rapproche la pièce de ses cibles |
| `🪟❌` | Fermer : l'air extérieur l'en éloignerait |
| `🪟➖` | Indifférent : tout est dans la cible |
| `🪟⚠️` | Conflit : un axe dit d'ouvrir, l'autre de fermer (la raison est dans le menu, ex. « air sec mais trop froid dehors ») |
| `🪟?` | Pas de verdict (réseau, station, valeur invalide…) : le détail est dans le menu |

## Principe

Deux axes sont évalués séparément, puis combinés.

**Humidité.** On ne compare jamais les humidités relatives brutes : 70 % à 12 °C contient moins d'eau que 55 % à 21 °C. Le plugin calcule la **HR projetée**, c'est-à-dire l'humidité qu'aurait l'air extérieur une fois amené à la température de la pièce. Elle se déduit du point de rosée extérieur (formule de Magnus, a = 17.62, b = 243.12) : `HR = 100 × e_s(rosée ext) / e_s(T int)`, avec `e_s(T) = 6.112 × exp(17.62·T / (243.12 + T))`. Exemple : de l'air à 5 °C et 90 %, amené à 21 °C, ne fait plus que 32 %.

L'humidité vise `RH_IDEAL` (50 %), pas seulement la fourchette `RH_MIN`–`RH_MAX`. On ouvre ou on ferme dès que la pièce s'en écarte de plus de `RH_MARGIN`, sans attendre d'atteindre un bord de la fourchette. Seul le sens compte : quelques minutes d'aération rapprochent la pièce de l'idéal bien avant qu'elle n'atteigne la HR projetée. Exemple : à 55 % dedans, un air extérieur qui donnerait 39 % fait ouvrir, et 5 minutes suffisent pour revenir vers 45 %.

| HR intérieure | Ouvrir si… | Sinon |
|---|---|---|
| > `RH_IDEAL` + `RH_MARGIN` (plutôt humide, trop humide au-dessus de `RH_MAX`) | HR projetée < HR intérieure − `RH_MARGIN` | fermer |
| < `RH_IDEAL` − `RH_MARGIN` (plutôt sec, trop sec sous `RH_MIN`) | HR projetée > HR intérieure + `RH_MARGIN` | fermer |
| proche de `RH_IDEAL` | — (indifférent si la HR projetée reste à ±`RH_MARGIN` de la HR intérieure) | fermer si elle s'en écarte davantage |

**Température.**

| Température intérieure | Ouvrir si… | Sinon |
|---|---|---|
| > `TEMP_MAX` (trop chaud) | T ext < T int − `TEMP_MARGIN` | fermer |
| < `TEMP_MIN` (trop froid) | T ext > T int + `TEMP_MARGIN` | fermer |
| dans la cible | — | indifférent |

**Combinaison.**
- Ouvrir + ouvrir, ou ouvrir + indifférent, donne **ouvrir**.
- Fermer + fermer, ou fermer + indifférent, donne **fermer**.
- Ouvrir + fermer donne un **conflit**.
- Indifférent + indifférent donne **indifférent**.

**Règle du froid.** Sous `MIN_OUTDOOR_TEMP` (5 °C dehors), l'humidité ne justifie pas à elle seule d'ouvrir, car la perte de chaleur coûte trop cher. Son « ouvrir » devient alors « fermer ». Exception : si la température pousse aussi à ouvrir (pièce trop chaude), le verdict reste « ouvrir ».

## Installation

Il faut [xbar](https://xbarapp.com) :

```sh
brew install --cask xbar
```

Clone ce dépôt, puis lance le script d'installation depuis le dossier cloné. La même commande sert aux mises à jour :

```sh
git clone https://github.com/paultursuru/window_council.git
cd window_council
./copy_to_plugins.sh
```

Le script copie `window_council.10m.rb` et `window_council_app/` dans le dossier des plugins xbar, puis demande à xbar de rafraîchir ses plugins pour prendre la nouvelle version tout de suite.

- Il ne touche ni aux valeurs saisies dans xbar ni aux relevés déjà enregistrés (`window_council_app/data/`).
- Il supprime les fichiers de code qui n'existent plus dans le dépôt.

Pour changer la fréquence de rafraîchissement, renomme `window_council.10m.rb` (par exemple `window_council.5m.rb`), adapte le nom dans `copy_to_plugins.sh`, relance le script, puis supprime l'ancien fichier du dossier des plugins.

## Régler les valeurs intérieures

Dans le menu du plugin, **Open Plugin…** (⌘E) ouvre les variables :

- `VAR_INDOOR_TEMP` : température intérieure en °C.
- `VAR_INDOOR_RH` : humidité relative intérieure en %.

`21,5` et `21.5` sont acceptés tous les deux. Un champ vide reprend la valeur par défaut. xbar enregistre ces valeurs dans `window_council.10m.rb.vars.json`, à côté du plugin.

**Heure des saisies.** xbar réécrit ce fichier à chaque modification, mais ne relance pas le plugin. Le plugin prend donc la date de modification du fichier comme heure exacte de ta saisie. Ainsi, une saisie faite à 16:42 est datée de 16:42 dans l'historique, même si le relevé suivant n'a lieu qu'à 16:50. Pour la voir tout de suite dans le menu et sur la page, clique sur **Rafraîchir**.

## Réglages

Le reste se règle dans [`window_council_app/config/settings.rb`](window_council_app/config/settings.rb), puis on relance `./copy_to_plugins.sh` :

| Constante | Défaut | Rôle |
|---|---|---|
| `TEMP_MIN`, `TEMP_MAX` | 20, 25 °C | cible de température |
| `RH_MIN`, `RH_MAX` | 40, 60 % | cible d'humidité (libellés et jauge) |
| `RH_IDEAL` | 50 % | humidité visée : on ouvre ou ferme dès que la pièce s'en écarte |
| `TEMP_MARGIN` | 1.0 °C | écart minimal pour que l'air extérieur corrige la température |
| `RH_MARGIN` | 3 points | écart minimal pour qu'il corrige l'humidité, et tolérance autour de `RH_IDEAL` |
| `MIN_OUTDOOR_TEMP` | 5.0 °C | sous ce seuil, pas d'ouverture pour la seule humidité |
| `INDOOR_TEMP`, `INDOOR_RH` | 21 °C, 60 % | défauts utilisés hors de xbar ; garde-les alignés avec les lignes `<xbar.var>` de `window_council.10m.rb` |
| `STATION` | `PUY` (Pully) | station MétéoSuisse, par son abréviation (première colonne du CSV ci-dessous) |
| `FORECAST_NAME`, `FORECAST_URL` | Lausanne | lien vers les prévisions locales, dans le menu et la page |
| `TIMEOUT` | 5 s | timeout réseau |
| `HISTORY_DAYS` | 7 | jours d'historique gardés dans `report.json` |
| `FALLBACK_MAX_AGE` | 60 min | âge maximal de la mesure de secours quand MétéoSuisse publie une mise à jour incomplète |

## Fichiers générés

À chaque exécution, le plugin écrit dans `window_council_app/data/` :

```
~/Library/Application Support/xbar/plugins/
├── window_council.10m.rb
├── window_council.10m.rb.vars.json   ← valeurs saisies dans xbar
└── window_council_app/
    ├── …                             ← le code
    └── data/
        ├── report.json               ← dernier relevé + historique
        └── report.html               ← page lisible (menu > « Voir le détail… »)
```

Tout est dans un sous-dossier : xbar exécute comme un plugin tout fichier posé directement dans son dossier, sauf les fichiers cachés, les dossiers et les `.vars.json`.

- **`report.json`** contient le dernier relevé complet, plus un `history`.
  - L'historique compte une ligne par relevé réussi, sur `HISTORY_DAYS` jours : environ 1 000 lignes et 400 Ko pour 7 jours.
  - Chaque valeur y garde sa vraie date : `entered_at` pour tes saisies, `measured_at` pour MétéoSuisse et `recorded_at` pour l'exécution du plugin.
  - Un relevé en erreur (réseau, valeur « - » publiée par MétéoSuisse) n'est pas ajouté, mais l'historique est conservé.
  - Le fichier est écrit de façon atomique, pour qu'un plantage au mauvais moment ne le corrompe pas. S'il devenait illisible, il serait copié en `report.json.unreadable` et l'historique repartirait de zéro.
- **`report.html`** montre :
  - le verdict et sa raison ;
  - une jauge par axe : la cible en vert, la valeur intérieure et la valeur extérieure ;
  - la section **Évolution**, décrite ci-dessous ;
  - les mesures et une courte explication.

  La page suit le thème clair ou sombre de macOS et se recharge toute seule toutes les 5 min, sans perdre la période choisie.

### Section Évolution

- **Deux graphiques** sur la période choisie (3 h, 24 h ou 7 jours) : la température (intérieur et extérieur), puis l'humidité (intérieur et air extérieur ramené à la température intérieure). Ce sont deux graphiques séparés, avec la cible en fond, plutôt qu'un seul graphique à deux échelles.
  - Les points bleus sont tes saisies, placées à leur heure exacte. Le trait atténué prolonge la dernière valeur saisie jusqu'à maintenant.
  - La courbe extérieure est coupée quand le Mac a dormi plus de 30 min, plutôt que de relier deux mesures éloignées.
- **Survol :** un réticule et une bulle donnent toutes les valeurs à cet instant (saisie, extérieur, HR projetée, verdict). Au clavier : Tab, puis ← et →.
- **Tableau « Saisies de l'hygromètre » :** chaque saisie avec sa variation depuis la précédente et la vitesse correspondante, par exemple `−0.9 °C, −5.0 pts en 12 min` soit `−4.5 °C/h, −25.0 pts/h`. C'est la mesure directe de la vitesse à laquelle la pièce sèche ou refroidit quand tu aères.
- **« Tous les relevés de la période »** (repliable) liste les données brutes du graphique.

Exemple de `report.json` (cas de conflit ; `history` raccourci à une ligne). Le `verdict` vaut `open`, `close`, `indifferent` ou `conflict` :

```json
{
  "updated_at": "2026-10-13T14:41:53+02:00",
  "station": "PUY",
  "verdict": "conflict",
  "reason": "air sec mais trop froid dehors",
  "projected_rh": 56.4,
  "axes": {
    "humidity":    { "target": [40.0, 60.0], "verdict": "open", "reason": "trop humide, l'air extérieur donnerait 56.4 %" },
    "temperature": { "target": [20.0, 25.0], "verdict": "close", "reason": "trop froid, mais 15.2 °C dehors" }
  },
  "indoor":   { "entered_at": "2026-10-13T14:38:12+02:00", "temperature": 18.0, "humidity": 68.0, "dew_point": 12.0 },
  "outdoor":  { "measured_at": "2026-10-13T14:30:00+02:00", "temperature": 15.2, "humidity": 67.3, "dew_point": 9.2 },
  "settings": { "temp_margin": 1.0, "rh_ideal": 50.0, "rh_margin": 3.0, "min_outdoor_temp": 5.0 },
  "history": [
    { "recorded_at": "2026-10-13T14:41:53+02:00", "verdict": "conflict",
      "entered_at": "2026-10-13T14:38:12+02:00", "indoor_temp": 18.0, "indoor_rh": 68.0,
      "measured_at": "2026-10-13T14:30:00+02:00", "outdoor_temp": 15.2, "outdoor_rh": 67.3, "outdoor_dew_point": 9.2,
      "projected_rh": 56.4 }
  ]
}
```

## Structure du code

La structure suit celle de [gitbar](https://github.com/paultursuru/gitbar) :

```
window_council.10m.rb             ← point d'entrée lu par xbar (métadonnées, variables)
window_council_app/
├── config/settings.rb            ← cibles, marges, station, fichiers
├── controller.rb                 ← un passage : relevé, décision, écriture, menu
├── helpers/application_helper.rb ← libellés des verdicts, formats
├── models/                       ← Axis, Decision
├── services/
│   ├── council.rb                ← la décision (fonctions pures)
│   ├── psychrometrics.rb         ← formules de Magnus
│   ├── meteoswiss.rb             ← mesures MétéoSuisse et mesure de secours
│   └── history.rb                ← historique de report.json
└── views/
    ├── menu.rb                   ← sortie xbar
    ├── page.rb                   ← page HTML
    ├── templates/                ← report.html.erb, _evolution.html
    └── assets/                   ← report.css, evolution.js (intégrés à la page)
```

## Tests

```sh
bundle install
bundle exec rspec      # logique, menu et page, sans réseau
bundle exec rubocop
```

Les specs couvrent :
- la HR projetée (5 °C / 90 % → 32 % à 21 °C) et l'aller-retour de Magnus ;
- les verdicts ouvrir, fermer et indifférent, un conflit et la règle du froid dans ses deux sens ;
- la visée de `RH_IDEAL` : ouvrir ou fermer selon que l'air extérieur en rapproche la pièce ou l'en éloigne ;
- le choix de la dernière ligne complète quand une mise à jour MétéoSuisse est incomplète ;
- la purge et la relecture de l'historique ;
- la lecture des variables xbar, les erreurs, le menu et la page.

La CI GitHub les lance avec Ruby 2.6 (celui de xbar) et 3.4, et passe RuboCop.

Pour lancer le plugin réel, avec les mesures du moment :

```sh
ruby window_council.10m.rb                 # ton Ruby
/usr/bin/ruby window_council.10m.rb        # Ruby système 2.6, celui que lance xbar

# simuler les variables passées par xbar
VAR_INDOOR_TEMP=18 VAR_INDOOR_RH=68 ruby window_council.10m.rb   # pièce froide et humide
VAR_INDOOR_TEMP=22,5 VAR_INDOOR_RH=35 ruby window_council.10m.rb # pièce trop sèche
VAR_INDOOR_TEMP=abc ruby window_council.10m.rb                   # → 🪟? + message d'erreur
```

Lancé depuis le dépôt, le script écrit dans `window_council_app/data/` du dépôt (ignoré par git). `open window_council_app/data/report.html` permet alors de voir la page.

## Source des données

- CSV open data MétéoSuisse SwissMetNet : <https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/VQHA80.csv>.
  - Séparateur `;`, une ligne par station.
  - Colonnes utilisées : `tre200s0` (température), `ure200s0` (humidité relative) et `tde200s0` (point de rosée).
  - La colonne `Date` est en UTC ; le script la convertit en heure locale.
  - Les mesures arrivent avec 10 à 20 min de retard. Une valeur absente vaut `-`.
- **Secours si la mise à jour est incomplète.** Il arrive que MétéoSuisse publie une mise à jour sans valeurs pour presque tout le réseau. Le 13.10.2026 à 17:20, 158 stations sur 159 étaient à `-`.
  - Le plugin prend alors la dernière mesure complète dans le fichier de la station : <https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn/puy/ogd-smn_puy_t_now.csv>. Ce fichier couvre environ 15 h en pas de 10 min, avec des dates UTC au format `13.10.2026 15:10`.
  - Le menu et la page le signalent (« Mise à jour MétéoSuisse de 17:20 incomplète : dernière mesure complète utilisée »).
  - Si la dernière mesure complète a plus de `FALLBACK_MAX_AGE` (60 min), le plugin affiche `🪟?` avec la liste des valeurs manquantes.
- Si une colonne disparaît, le menu affiche les en-têtes réellement trouvés.
- Prévisions locales : <https://www.meteosuisse.admin.ch/previsions-locales/lausanne/1003.html>.

## Contraintes

Le plugin n'utilise que la bibliothèque standard de Ruby (`csv`, `date`, `erb`, `fileutils`, `json`, `open-uri`, `timeout`) : aucune gem à installer pour s'en servir. Le `Gemfile` ne sert qu'aux tests et à RuboCop. Le code reste compatible avec Ruby 2.6, parce que xbar ne charge pas le PATH de mise ou rbenv et lance `/usr/bin/ruby`.

## Pistes d'amélioration

- **Mesures intérieures automatiques.** Lire la température et l'humidité sur une station météo connectée (Netatmo, SwitchBot, Home Assistant, capteur ESPHome…) plutôt que de les saisir à la main dans xbar. Les variables xbar resteraient la solution de secours.
- **Réglages hors du code.** Un `settings.json` ignoré par git, comme dans gitbar, pour garder ses cibles et sa station d'une mise à jour à l'autre.
- **Notification** quand le verdict change, par exemple quand il devient intéressant d'ouvrir.
- **Prévisions.** Tenir compte des prochaines heures (MétéoSuisse publie aussi des prévisions locales) pour conseiller le meilleur moment pour aérer.
- **Choix de la station** à partir d'une adresse ou de coordonnées, plutôt que par son abréviation.
- **Interface en anglais**, pour les personnes qui ne lisent pas le français.

## Crédits

- Données : [MétéoSuisse](https://www.meteosuisse.admin.ch), open data SwissMetNet.
- [xbar](https://github.com/matryer/xbar)
