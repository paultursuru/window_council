# frozen_string_literal: true

require 'csv'
require 'date'
require 'open-uri'
require_relative '../config/settings'

# Outdoor temperature, RH and dew point at STATION (SwissMetNet open data).
module MeteoSwiss
  module_function

  # { temp:, rh:, dew:, time: }, plus incomplete: (update time) when using the fallback
  def current
    table = read_csv(CSV_URL)
    check_columns(table)
    row = table.find { |r| r[0].to_s.strip == STATION } or raise "Station #{STATION} absente du CSV"
    time = utc_time(row[DATE_COL], '%Y%m%d%H%M')
    measured = measurements(row)
    measured.values.all? ? measured.merge(time: time) : fallback(measured, time)
  end

  # On a missing column, lists the headers actually found
  def check_columns(table)
    missing = COLS.values + [DATE_COL] - table.headers
    return if missing.empty?

    found = table.headers.compact.each_slice(6).map { |s| s.join(', ') }
    raise ["Colonne(s) absente(s) : #{missing.join(', ')}", 'En-têtes trouvés :', *found].join("\n")
  end

  # Incomplete update (often network-wide): last complete station row, if recent enough
  def fallback(incomplete, time)
    last = last_station_measurement
    if last.nil? || Time.now - last[:time] > FALLBACK_MAX_AGE * 60
      missing = COLS.values_at(*incomplete.select { |_, v| v.nil? }.keys).join(', ')
      raise "Valeur manquante à #{STATION} pour #{missing} (mise à jour de #{time.strftime('%H:%M')}), " \
            "et pas de mesure complète de moins de #{FALLBACK_MAX_AGE} min"
    end
    last.merge(incomplete: time)
  end

  def last_station_measurement
    row = last_complete(read_csv(format(FALLBACK_URL, station: STATION.downcase)))
    row && measurements(row).merge(time: utc_time(row['reference_timestamp'], '%d.%m.%Y %H:%M'))
  rescue StandardError
    nil
  end

  def read_csv(url)
    body = URI.parse(url).open(open_timeout: TIMEOUT, read_timeout: TIMEOUT, &:read)
    text = body.force_encoding('UTF-8').scrub.delete_prefix(0xFEFF.chr(Encoding::UTF_8)) # strip BOM
    CSV.parse(text, col_sep: ';', headers: true)
  end

  # Row values; nil when missing ("-" or empty)
  def measurements(row)
    COLS.transform_values { |col| Float(row[col].to_s, exception: false) }
  end

  # Last row with all three values
  def last_complete(rows)
    rows.reverse_each.find { |r| measurements(r).values.all? }
  end

  def utc_time(text, pattern)
    DateTime.strptime(text, pattern).to_time.localtime
  end
end
