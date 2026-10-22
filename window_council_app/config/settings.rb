# frozen_string_literal: true

# Indoor readings are set in xbar (Open Plugin…, ⌘E) as VAR_INDOOR_TEMP / VAR_INDOOR_RH.
# These defaults apply outside xbar: keep them in sync with the <xbar.var> lines.
INDOOR_TEMP = 21.0 # °C
INDOOR_RH   = 60.0 # %

# Comfort targets
TEMP_MIN    = 20.0 # °C
TEMP_MAX    = 25.0 # °C
RH_MIN      = 40.0 # %
RH_MAX      = 60.0 # %
RH_IDEAL    = 50.0 # %: humidity aims at it, opening or closing as soon as the room drifts away
TEMP_MARGIN = 1.0  # °C: minimal gap for outdoor air to correct the temperature
RH_MARGIN   = 3.0  # % points: same for humidity, and tolerance around RH_IDEAL
MIN_OUTDOOR_TEMP = 5.0 # °C: below it, humidity alone never opens the windows

# MeteoSwiss data
STATION  = 'PUY' # Pully
CSV_URL  = 'https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/VQHA80.csv'
DATE_COL = 'Date' # YYYYMMDDhhmm, UTC
COLS     = { temp: 'tre200s0', rh: 'ure200s0', dew: 'tde200s0' }.freeze
TIMEOUT  = 5 # s
# Station file (~15 h, 10 min steps), used when the latest update has missing values
FALLBACK_URL     = 'https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn/%<station>s/ogd-smn_%<station>s_t_now.csv'
FALLBACK_MAX_AGE = 60 # min
# Local forecast, linked from the menu and the page
FORECAST_NAME = 'Lausanne'
FORECAST_URL  = 'https://www.meteosuisse.admin.ch/previsions-locales/lausanne/1003.html'

# Generated files, in a subfolder: xbar would run any file at the top of its plugins folder
DATA_DIR     = File.expand_path('../data', __dir__)
JSON_FILE    = File.join(DATA_DIR, 'report.json')
HTML_FILE    = File.join(DATA_DIR, 'report.html')
HISTORY_DAYS = 7
