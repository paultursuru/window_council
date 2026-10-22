# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'timeout' # Timeout::Error, without waiting for open-uri to load net/http
require_relative 'config/settings'
require_relative 'helpers/application_helper'
require_relative 'services/council'
require_relative 'services/history'
require_relative 'services/meteoswiss'
require_relative 'services/psychrometrics'
require_relative 'views/menu'
require_relative 'views/page'

# One plugin run: build the report, write the JSON and HTML, print the xbar menu.
class Controller
  include ApplicationHelper

  def initialize(plugin_path:)
    # xbar rewrites it on every change: its mtime is when the values were entered
    @vars_file = "#{File.expand_path(plugin_path)}.vars.json"
  end

  def run
    report = build_report
    puts Menu.new(report, save(report)).lines
  end

  def build_report
    report = { updated_at: iso(Time.now), station: STATION }
    temp = setting('VAR_INDOOR_TEMP', INDOOR_TEMP)
    rh = setting('VAR_INDOOR_RH', INDOOR_RH)
    raise "VAR_INDOOR_RH doit être entre 0 et 100 (« #{rh} »)" unless rh.positive? && rh <= 100

    outdoor = MeteoSwiss.current
    decision = Council.decide(temp, rh, outdoor[:temp], outdoor[:dew])
    report.merge(
      verdict: decision.verdict,
      reason: decision.reason,
      projected_rh: Psychrometrics.projected_rh(outdoor[:dew], temp).round(1),
      axes: { humidity: axis_fields(decision.humidity, [RH_MIN, RH_MAX]),
              temperature: axis_fields(decision.temperature, [TEMP_MIN, TEMP_MAX]) },
      indoor: indoor_fields(temp, rh),
      outdoor: outdoor_fields(outdoor),
      settings: { temp_margin: TEMP_MARGIN, rh_ideal: RH_IDEAL, rh_margin: RH_MARGIN,
                  min_outdoor_temp: MIN_OUTDOOR_TEMP }
    )
  rescue StandardError => e
    report.merge(error: e.is_a?(Timeout::Error) ? "Délai réseau dépassé (#{TIMEOUT} s)" : e.message)
  end

  # Writes the JSON (with history) and the page; returns an error message, or nil
  def save(report)
    FileUtils.mkdir_p(DATA_DIR)
    history = History.read(JSON_FILE)
    history << History.entry(report) unless report[:error]
    report = report.merge(history: History.prune(history, Time.now))
    write_atomically(JSON_FILE, JSON.pretty_generate(report))
    write_atomically(HTML_FILE, Page.new(report).render)
    nil
  rescue StandardError => e
    "Écriture impossible : #{e.message}"
  end

  private

  # xbar variable (VAR_*) or default; accepts "21,5" as "21.5"
  def setting(name, default)
    raw = ENV[name].to_s.strip
    return default if raw.empty?

    Float(raw.tr(',', '.'), exception: false) or raise "#{name} invalide : « #{raw} »"
  end

  def axis_fields(axis, target)
    { target: target, verdict: axis.verdict, reason: axis.reason }
  end

  def indoor_fields(temp, rh)
    entered_at = File.exist?(@vars_file) ? File.mtime(@vars_file) : Time.now
    { entered_at: iso(entered_at), temperature: temp, humidity: rh,
      dew_point: Psychrometrics.dew_point(temp, rh).round(1) }
  end

  def outdoor_fields(outdoor)
    { measured_at: iso(outdoor[:time]), temperature: outdoor[:temp], humidity: outdoor[:rh],
      dew_point: outdoor[:dew], incomplete_update_at: outdoor[:incomplete] && iso(outdoor[:incomplete]) }.compact
  end

  # Never leaves a half-written file (the history lives in it)
  def write_atomically(path, content)
    File.write("#{path}.tmp", content)
    File.rename("#{path}.tmp", path)
  end
end
