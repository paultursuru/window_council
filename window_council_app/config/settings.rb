# frozen_string_literal: true

# Ideals are set in xbar (Open Plugin…, ⌘E) as VAR_TEMP_IDEAL / VAR_RH_IDEAL.
# These defaults apply when a variable is empty: keep them in sync with the <xbar.var> lines.
TEMP_IDEAL = 21.0 # °C: temperature aims at it
RH_IDEAL   = 50.0 # %: humidity aims at it, opening or closing as soon as the room drifts away

# Comfort band: "trop" vs "plutôt" in reasons, green zone of gauges and charts
TEMP_MIN    = 20.0 # °C
TEMP_MAX    = 25.0 # °C
RH_MIN      = 40.0 # %
RH_MAX      = 60.0 # %
TEMP_MARGIN = 1.0  # °C: minimal gap for outdoor air to correct the temperature, and tolerance around TEMP_IDEAL
RH_MARGIN   = 3.0  # % points: same for humidity, and tolerance around RH_IDEAL
MIN_OUTDOOR_TEMP = 5.0 # °C: below it, humidity alone never opens the windows

# Airing: rate (per hour) at which the gap between indoor and outdoor humidity shrinks,
# used until airings are measured (a reading when opening, another when closing)
AIRING_RATES = { 'one' => 1.0, 'cross' => 4.0 }.freeze

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

# Page with the readings form, served locally while it is open (menu > Saisir un relevé…)
SERVER_HOST = '127.0.0.1'
SERVER_PORT = 47_830
SERVER_IDLE = 30 # min without a request before the server stops; the open page reloads every 5 min
SERVER_FILE = File.expand_path('../server.rb', __dir__)

# Generated files, in a subfolder: xbar would run any file at the top of its plugins folder
DATA_DIR      = File.expand_path('../data', __dir__)
JSON_FILE     = File.join(DATA_DIR, 'report.json')
HTML_FILE     = File.join(DATA_DIR, 'report.html')
READINGS_FILE = File.join(DATA_DIR, 'readings.json')
LOCK_FILE     = File.join(DATA_DIR, '.lock')
LOG_FILE      = File.join(DATA_DIR, 'server.log')
HISTORY_DAYS  = 7
