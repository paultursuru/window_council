# Window Council

Plugin [xbar](https://xbarapp.com) qui dit s'il faut ouvrir ou fermer les fenêtres, et combien de temps. Il confronte tes valeurs idéales de température et d'humidité à l'air extérieur (mesures MétéoSuisse à Pully), à partir des relevés de ton hygromètre, saisis sur sa page.

| Barre de menu | Signification |
|---|---|
| `🪟✅` | Ouvrir : l'air extérieur rapproche la pièce de ses cibles |
| `🪟❌` | Fermer : l'air extérieur l'en éloignerait |
| `🪟➖` | Indifférent : tout est dans la cible |
| `🪟⚠️` | Conflit : un axe dit d'ouvrir, l'autre de fermer (la raison est dans le menu, ex. « air sec mais trop froid dehors ») |
| `🪟?` | Pas de verdict (réseau, station, valeur invalide…) : le détail est dans le menu |
| `🪟✅ 18:40` | Aération en cours : fermer vers 18:40 |
| `🪟⏰` | Aération en cours : c'est l'heure de fermer |

## Principe

Deux axes sont évalués séparément, puis combinés.

**Humidité.** On ne compare jamais les humidités relatives brutes : 70 % à 12 °C contient moins d'eau que 55 % à 21 °C. Le plugin calcule la **HR projetée**, c'est-à-dire l'humidité qu'aurait l'air extérieur une fois amené à la température de la pièce. Elle se déduit du point de rosée extérieur (formule de Magnus, a = 17.62, b = 243.12) : `HR = 100 × e_s(rosée ext) / e_s(T int)`, avec `e_s(T) = 6.112 × exp(17.62·T / (243.12 + T))`. Exemple : de l'air à 5 °C et 90 %, amené à 21 °C, ne fait plus que 32 %.

L'humidité vise l'humidité idéale (`VAR_RH_IDEAL`, 50 % par défaut), pas seulement la fourchette `RH_MIN`–`RH_MAX`. On ouvre ou on ferme dès que la pièce s'en écarte de plus de `RH_MARGIN`, sans attendre d'atteindre un bord de la fourchette. Seul le sens compte : quelques minutes d'aération rapprochent la pièce de l'idéal bien avant qu'elle n'atteigne la HR projetée. Exemple : à 55 % dedans, un air extérieur qui donnerait 39 % fait ouvrir, et quelques minutes suffisent pour revenir vers 50 %.

| HR intérieure | Ouvrir si… | Sinon |
|---|---|---|
| > idéal + `RH_MARGIN` (plutôt humide, trop humide au-dessus de `RH_MAX`) | HR projetée < HR intérieure − `RH_MARGIN` | fermer |
| < idéal − `RH_MARGIN` (plutôt sec, trop sec sous `RH_MIN`) | HR projetée > HR intérieure + `RH_MARGIN` | fermer |
| proche de l'idéal | — (indifférent si la HR projetée reste à ±`RH_MARGIN` de la HR intérieure) | fermer si elle s'en écarte davantage |

**Température.** Elle vise la température idéale (`VAR_TEMP_IDEAL`, 21 °C par défaut). Près de l'idéal, l'aération est indifférente : les murs gardent la chaleur, et une aération courte ne refroidit presque pas la pièce.

| Température intérieure | Ouvrir si… | Sinon |
|---|---|---|
| > idéal + `TEMP_MARGIN` (plutôt chaud, trop chaud au-dessus de `TEMP_MAX`) | T ext < T int − `TEMP_MARGIN` | fermer |
| < idéal − `TEMP_MARGIN` (plutôt froid, trop froid sous `TEMP_MIN`) | T ext > T int + `TEMP_MARGIN` | fermer |
| proche de l'idéal | — | indifférent |

**Combinaison.**
- Ouvrir + ouvrir, ou ouvrir + indifférent, donne **ouvrir**.
- Fermer + fermer, ou fermer + indifférent, donne **fermer**.
- Ouvrir + fermer donne un **conflit**.
- Indifférent + indifférent donne **indifférent**.

**Règle du froid.** Sous `MIN_OUTDOOR_TEMP` (5 °C dehors), l'humidité ne justifie pas à elle seule d'ouvrir, car la perte de chaleur coûte trop cher. Son « ouvrir » devient alors « fermer ». Exception : si la température pousse aussi à ouvrir (pièce trop chaude), le verdict reste « ouvrir ».

## Combien de temps aérer

Fenêtres ouvertes, l'écart entre l'humidité de la pièce et celle de l'air extérieur fond de façon exponentielle : chaque minute en retire la même part. Ce sont donc les premières minutes qui comptent le plus. Le calcul se fait sur la pression de vapeur (la quantité d'eau dans l'air), à température intérieure constante. C'est ce qu'on observe en pratique, car la chaleur est stockée dans les murs, pas dans l'air.

- **Quand l'humidité dit d'ouvrir**, le menu et la page donnent la durée pour atteindre l'idéal, avec une fenêtre ou en courant d'air. Exemple : « Aérer jusqu'à 45.0 % : 1 fenêtre ~46 min · courant d'air ~12 min ». Si l'air extérieur ne permet pas d'aller jusqu'à l'idéal, la cible s'arrête à `RH_MARGIN` de la HR projetée.
- **Pendant une aération** (le dernier relevé indique des fenêtres ouvertes), ils donnent l'humidité estimée et l'heure de fermeture, aussi dans la barre de menu (`🪟✅ 18:40`, puis `🪟⏰`). Après 6 h sans relevé, le plugin suppose que tu as fermé sans le noter.
- **La vitesse se mesure sur tes aérations.** Saisis un relevé en ouvrant, avec l'état des fenêtres (1 fenêtre ou courant d'air), puis un autre en fermant. Le plugin en déduit la vitesse de cette aération, et garde la médiane des 5 dernières pour chaque façon d'ouvrir. Une aération n'est retenue que si elle a duré entre 5 min et 3 h, que l'humidité de la pièce n'était pas déjà proche de celle de l'air extérieur, et que l'humidité s'est bien rapprochée de celle de l'air extérieur.
  - Sans mesure, la page affiche « valeur par défaut, pas encore mesurée ». Les valeurs par défaut sont dans `AIRING_RATES`. Celle d'une fenêtre (1 par heure) vient de l'aération du 22.10.2026 : 45 min pour passer de 46 à 41 % à 21 °C, avec un point de rosée de 5.5 °C dehors.
  - La page traduit la vitesse en demi-vie, c'est-à-dire le temps pour que l'écart avec l'air extérieur diminue de moitié (environ 42 min avec une fenêtre, d'après cette aération).
- **Après la fermeture**, l'humidité remonte un peu : les murs, les textiles et les meubles rendent de l'eau. Le modèle n'en tient pas compte ; un relevé une heure plus tard permet de le voir.

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

- Il ne touche ni aux valeurs saisies dans xbar ni aux données déjà enregistrées (`window_council_app/data/`).
- Au premier passage après la mise à jour, les anciennes saisies de l'hygromètre, faites dans xbar, sont reprises de l'historique dans `readings.json`. Les saisies faites à quelques secondes d'intervalle (une par variable) n'en font qu'une.
- Il supprime les fichiers de code qui n'existent plus dans le dépôt.

Pour changer la fréquence de rafraîchissement, renomme `window_council.10m.rb` (par exemple `window_council.5m.rb`), adapte le nom dans `copy_to_plugins.sh`, relance le script, puis supprime l'ancien fichier du dossier des plugins.

## Saisir un relevé

Dans le menu, **Saisir un relevé, voir le détail…** ouvre la page dans le navigateur. Le formulaire en haut de la page demande :

- la **température** et l'**humidité** lues sur l'hygromètre (`21,5` et `21.5` sont acceptés tous les deux) ;
- l'**heure** du relevé, l'heure actuelle si le champ reste vide. Une heure plus tardive que maintenant est celle de la veille, pour pouvoir saisir à 00:10 un relevé de 23:50 ; la confirmation affiche alors la date ;
- l'état des **fenêtres** à partir de ce relevé : fermées, 1 fenêtre ou courant d'air. Il sert à mesurer les aérations (voir [Combien de temps aérer](#combien-de-temps-aérer)) et reprend par défaut l'état du relevé précédent.

**Enregistrer** recalcule le verdict et la page tout de suite, et rafraîchit le menu xbar. Pour corriger un relevé, ressaisis-le à la même heure : il remplace l'ancien. En cas de valeur invalide, la page affiche l'erreur et garde ce qui a été saisi.

**Le serveur local.** Une page ouverte comme fichier ne peut rien enregistrer. Le lien du menu lance donc un petit serveur, sur `http://127.0.0.1:47830` (bibliothèque standard de Ruby, rien à installer).
- Il n'écoute que la machine locale, et refuse les requêtes venues d'un autre site ou d'un autre nom d'hôte.
- Il s'arrête après `SERVER_IDLE` (30 min) sans requête. La page ouverte se recharge toutes les 5 min, donc il tourne tant qu'elle reste ouverte.
- Si le serveur tourne déjà, le lien ouvre simplement la page.

En maintenant ⌥ dans le menu, **Voir le détail, sans formulaire…** ouvre la page comme fichier, sans lancer le serveur.

## Régler les idéaux

Dans le menu du plugin, **Open Plugin…** (⌘E) ouvre les variables :

- `VAR_TEMP_IDEAL` : température idéale en °C (21 par défaut).
- `VAR_RH_IDEAL` : humidité relative idéale en % (50 par défaut).

`21,5` et `21.5` sont acceptés tous les deux. Un champ vide reprend la valeur par défaut. xbar enregistre ces valeurs dans `window_council.10m.rb.vars.json`, à côté du plugin ; le serveur du formulaire les lit dans ce fichier.

## Réglages

Le reste se règle dans [`window_council_app/config/settings.rb`](window_council_app/config/settings.rb), puis on relance `./copy_to_plugins.sh` :

| Constante | Défaut | Rôle |
|---|---|---|
| `TEMP_IDEAL`, `RH_IDEAL` | 21 °C, 50 % | idéaux quand les variables xbar sont vides ; garde-les alignés avec les lignes `<xbar.var>` de `window_council.10m.rb` |
| `TEMP_MIN`, `TEMP_MAX` | 20, 25 °C | cible de température (« trop » ou « plutôt », jauge, graphique) |
| `RH_MIN`, `RH_MAX` | 40, 60 % | cible d'humidité (mêmes usages) |
| `TEMP_MARGIN` | 1.0 °C | écart minimal pour que l'air extérieur corrige la température, et tolérance autour de l'idéal |
| `RH_MARGIN` | 3 points | même chose pour l'humidité |
| `MIN_OUTDOOR_TEMP` | 5.0 °C | sous ce seuil, pas d'ouverture pour la seule humidité |
| `AIRING_RATES` | 1 fenêtre : 1.0 /h, courant d'air : 4.0 /h | vitesse d'aération tant qu'aucune aération n'a été mesurée |
| `SERVER_PORT` | 47830 | port du serveur local du formulaire |
| `SERVER_IDLE` | 30 min | arrêt du serveur après ce délai sans requête |
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
        ├── readings.json             ← relevés de l'hygromètre, saisis sur la page
        ├── report.json               ← dernier verdict + historique
        ├── report.html               ← la page (menu > « Saisir un relevé, voir le détail… »)
        └── server.log                ← erreurs du serveur local, s'il y en a
```

Tout est dans un sous-dossier : xbar exécute comme un plugin tout fichier posé directement dans son dossier, sauf les fichiers cachés, les dossiers et les `.vars.json`.

- **`readings.json`** contient tous les relevés de l'hygromètre, triés par heure : `at`, `temperature`, `humidity`, `windows` (`closed`, `one` ou `cross` ; absent pour les anciennes saisies, comptées comme fermées) et `outdoor_dew_point`. Le point de rosée extérieur au moment du relevé est repris de l'historique ; il sert à mesurer les aérations. Ce fichier n'est jamais purgé. S'il devenait illisible, le menu afficherait l'erreur plutôt que de repartir de zéro.
- **`report.json`** contient le dernier verdict complet, le plan d'aération (`airing`), les relevés des `HISTORY_DAYS` derniers jours et un `history`.
  - L'historique compte une ligne par passage réussi du plugin, sur `HISTORY_DAYS` jours : environ 1 000 lignes et 400 Ko pour 7 jours.
  - Chaque valeur y garde sa vraie date : `entered_at` pour le relevé de l'hygromètre, `measured_at` pour MétéoSuisse et `recorded_at` pour l'exécution du plugin.
  - Un relevé en erreur (réseau, valeur « - » publiée par MétéoSuisse) n'est pas ajouté, mais l'historique est conservé.
  - Le fichier est écrit de façon atomique, pour qu'un plantage au mauvais moment ne le corrompe pas. S'il devenait illisible, il serait copié en `report.json.unreadable` et l'historique repartirait de zéro.
  - Le plugin et le serveur du formulaire n'écrivent jamais en même temps : ils passent par un verrou (`data/.lock`).
- **`report.html`** montre :
  - le verdict et sa raison ;
  - le formulaire de relevé ;
  - une jauge par axe : la cible en vert, l'idéal (trait), la valeur intérieure et la valeur extérieure ;
  - la carte **Aération** : durée conseillée ou aération en cours, et vitesse mesurée pour chaque façon d'ouvrir ;
  - la section **Évolution**, décrite ci-dessous ;
  - les mesures et une courte explication.

  La page suit le thème clair ou sombre de macOS et se recharge toute seule toutes les 5 min, sans perdre la période choisie, sauf pendant une saisie dans le formulaire.

### Section Évolution

- **Deux graphiques** sur la période choisie (3 h, 24 h ou 7 jours) : la température (intérieur et extérieur), puis l'humidité (intérieur et air extérieur ramené à la température intérieure). Ce sont deux graphiques séparés, avec la cible en fond et l'idéal en pointillés, plutôt qu'un seul graphique à deux échelles.
  - Les points bleus sont tes relevés, placés à leur heure. Le trait atténué prolonge le dernier relevé jusqu'à maintenant.
  - Une bande bleutée marque les périodes où les fenêtres étaient ouvertes (plus foncée en courant d'air).
  - La courbe extérieure est coupée quand le Mac a dormi plus de 30 min, plutôt que de relier deux mesures éloignées.
- **Survol :** un réticule et une bulle donnent toutes les valeurs à cet instant (relevé et fenêtres, extérieur, HR projetée, verdict). Au clavier : Tab, puis ← et →.
- **Tableau « Relevés de l'hygromètre » :** chaque relevé avec l'état des fenêtres, sa variation depuis le précédent et la vitesse correspondante, par exemple `−0.9 °C, −5.0 pts en 12 min` soit `−4.5 °C/h, −25.0 pts/h`.
- **« Tous les passages du plugin sur la période »** (repliable) liste les données brutes du graphique.

Exemple de `report.json` (cas de conflit ; `readings` et `history` raccourcis à une ligne). Le `verdict` vaut `open`, `close`, `indifferent` ou `conflict` :

```json
{
  "updated_at": "2026-10-13T14:41:53+02:00",
  "station": "PUY",
  "readings": [
    { "at": "2026-10-13T14:38:12+02:00", "temperature": 18.0, "humidity": 68.0, "windows": "closed", "outdoor_dew_point": 9.2 }
  ],
  "verdict": "conflict",
  "reason": "air sec mais trop froid dehors",
  "projected_rh": 56.4,
  "axes": {
    "humidity":    { "target": [40.0, 60.0], "ideal": 50.0, "verdict": "open", "reason": "trop humide, l'air extérieur donnerait 56.4 %" },
    "temperature": { "target": [20.0, 25.0], "ideal": 21.0, "verdict": "close", "reason": "trop froid, mais 15.2 °C dehors" }
  },
  "indoor":   { "entered_at": "2026-10-13T14:38:12+02:00", "temperature": 18.0, "humidity": 68.0, "windows": "closed", "dew_point": 12.0 },
  "outdoor":  { "measured_at": "2026-10-13T14:30:00+02:00", "temperature": 15.2, "humidity": 67.3, "dew_point": 9.2 },
  "airing": {
    "rates": { "one": { "half_life": 42, "samples": 1 }, "cross": { "half_life": 10, "samples": 0 } },
    "target_rh": 59.4,
    "durations": { "one": 82, "cross": 20 }
  },
  "settings": { "temp_ideal": 21.0, "rh_ideal": 50.0, "temp_margin": 1.0, "rh_margin": 3.0, "min_outdoor_temp": 5.0 },
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
├── config/settings.rb            ← idéaux par défaut, cibles, marges, station, serveur, fichiers
├── controller.rb                 ← un passage : relevé, décision, aération, écriture, menu
├── server.rb                     ← serveur local de la page et du formulaire
├── helpers/application_helper.rb ← libellés des verdicts et des fenêtres, formats
├── models/                       ← Axis, Decision
├── services/
│   ├── council.rb                ← la décision (fonctions pures)
│   ├── airing.rb                 ← durée d'aération et mesure des aérations (fonctions pures)
│   ├── psychrometrics.rb         ← formules de Magnus
│   ├── meteoswiss.rb             ← mesures MétéoSuisse et mesure de secours
│   ├── readings.rb               ← relevés de readings.json, lecture du formulaire
│   ├── history.rb                ← historique de report.json
│   └── storage.rb                ← écriture atomique et verrou
└── views/
    ├── menu.rb                   ← sortie xbar
    ├── page.rb                   ← page HTML
    ├── templates/                ← report.html.erb, _reading_form.html.erb, _evolution.html
    └── assets/                   ← report.css, evolution.js, form.js (intégrés à la page)
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
- la visée des idéaux d'humidité et de température ;
- la mesure d'une aération (celle du 22.10.2026 : environ 1 par heure), la cible, la durée conseillée, l'aération en cours et l'heure de fermeture ;
- la lecture du formulaire (virgule décimale, heure vide ou de la veille, erreurs), la correction d'un relevé et la reprise des anciennes saisies ;
- le serveur : page, refus d'un autre hôte ou d'un autre site, enregistrement d'un relevé, retour d'une erreur au formulaire ;
- le choix de la dernière ligne complète quand une mise à jour MétéoSuisse est incomplète ;
- la purge et la relecture de l'historique ;
- la lecture des variables xbar (environnement ou fichier), les erreurs, le menu et la page.

Toutes les specs écrivent dans un dossier temporaire, jamais dans `window_council_app/data/`.

La CI GitHub les lance avec Ruby 2.6 (celui de xbar) et 3.4, et passe RuboCop.

Pour lancer le plugin réel, avec les mesures du moment :

```sh
ruby window_council.10m.rb                 # ton Ruby
/usr/bin/ruby window_council.10m.rb        # Ruby système 2.6, celui que lance xbar

# simuler les variables passées par xbar
VAR_RH_IDEAL=45 ruby window_council.10m.rb     # autre humidité idéale
VAR_TEMP_IDEAL=abc ruby window_council.10m.rb  # → 🪟? + message d'erreur

# la page et son formulaire (détaché, ouvre le navigateur)
ruby window_council_app/server.rb
```

Lancé depuis le dépôt, le script écrit dans `window_council_app/data/` du dépôt (ignoré par git). Sans relevé, il affiche `🪟?` et demande d'en saisir un sur la page.

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

Le plugin n'utilise que la bibliothèque standard de Ruby (`csv`, `date`, `erb`, `fileutils`, `io/wait`, `json`, `open-uri`, `socket`, `timeout`, `uri`) : aucune gem à installer pour s'en servir. Le serveur du formulaire est écrit directement sur `socket`, parce que WEBrick ne fait plus partie de la bibliothèque standard depuis Ruby 3.0. Le `Gemfile` ne sert qu'aux tests et à RuboCop. Le code reste compatible avec Ruby 2.6, parce que xbar ne charge pas le PATH de mise ou rbenv et lance `/usr/bin/ruby`.

## Pistes d'amélioration

- **Mesures intérieures automatiques.** Lire la température et l'humidité sur une station météo connectée (Netatmo, SwitchBot, Home Assistant, capteur ESPHome…) plutôt que de les saisir à la main. Le formulaire resterait la solution de secours.
- **Réglages hors du code.** Un `settings.json` ignoré par git, comme dans gitbar, pour garder ses cibles et sa station d'une mise à jour à l'autre.
- **Notification** quand le verdict change, par exemple quand il devient intéressant d'ouvrir.
- **Prévisions.** Conseiller le meilleur moment pour aérer d'après le point de rosée prévu, qui compte plus que la température : il bouge peu dans une journée, mais change avec la pluie, un front ou la bise. Le flux de prévisions MétéoSuisse des widgets n'a ni humidité ni point de rosée ; Open-Meteo les donne heure par heure avec le modèle MétéoSuisse ICON-CH (`models=meteoswiss_icon_ch1`), sans clé.
- **Remontée après fermeture.** Mesurer de combien l'humidité remonte dans l'heure qui suit une aération, et en tenir compte dans la durée conseillée.
- **Choix de la station** à partir d'une adresse ou de coordonnées, plutôt que par son abréviation.
- **Interface en anglais**, pour les personnes qui ne lisent pas le français.

## Crédits

- Données : [MétéoSuisse](https://www.meteosuisse.admin.ch), open data SwissMetNet.
- [xbar](https://github.com/matryer/xbar)
