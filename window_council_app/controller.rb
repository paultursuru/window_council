# frozen_string_literal: true

require 'json'
require 'timeout' # Timeout::Error, without waiting for open-uri to load net/http
require_relative 'config/settings'
require_relative 'helpers/application_helper'
require_relative 'services/airing'
require_relative 'services/council'
require_relative 'services/history'
require_relative 'services/meteoswiss'
require_relative 'services/psychrometrics'
require_relative 'services/readings'
require_relative 'services/storage'
require_relative 'views/menu'
require_relative 'views/page'

# One plugin run: build the report, write the JSON and HTML, print the xbar menu.
class Controller
  include ApplicationHelper

  def initialize(plugin_path:)
    # Where xbar saves its variables, read when the form server runs the controller
    @vars_file = "#{File.expand_path(plugin_path)}.vars.json"
  end

  def run
    report = build_report
    puts Menu.new(report, save(report)).lines
  end

  # After a reading from the form; returns an error message, or nil
  def refresh
    save(build_report)
  end

  def build_report
    now = Time.now
    report = { updated_at: iso(now), station: STATION }
    ideals = { temp: variable('VAR_TEMP_IDEAL', TEMP_IDEAL), rh: variable('VAR_RH_IDEAL', RH_IDEAL) }
    raise "VAR_RH_IDEAL doit être entre 0 et 100 (« #{fmt(ideals[:rh])} »)" unless ideals[:rh].between?(1, 99)

    readings = Readings.load
    report[:readings] = Readings.recent(readings, now)
    raise 'Aucun relevé intérieur : saisis-en un avec « Saisir un relevé… »' if readings.empty?

    report.merge(assess(readings, MeteoSwiss.current, ideals, now))
  rescue StandardError => e
    report.merge(error: e.is_a?(Timeout::Error) ? "Délai réseau dépassé (#{TIMEOUT} s)" : e.message)
  end

  # Writes the JSON (with history) and the page; returns an error message, or nil
  def save(report)
    Storage.locked do
      history = History.read(JSON_FILE)
      history << History.entry(report) unless report[:error]
      report = report.merge(history: History.prune(history, Time.now))
      Storage.write_atomically(JSON_FILE, JSON.pretty_generate(report))
      Storage.write_atomically(HTML_FILE, Page.new(report).render)
    end
    nil
  rescue StandardError => e
    "Écriture impossible : #{e.message}"
  end

  private

  # The latest reading against outdoor air, and how long to air
  def assess(readings, outdoor, ideals, now)
    reading = readings.last
    temp = reading['temperature']
    decision = Council.decide(temp, reading['humidity'], outdoor[:temp], outdoor[:dew],
                              rh_ideal: ideals[:rh], temp_ideal: ideals[:temp])
    { verdict: decision.verdict, reason: decision.reason,
      projected_rh: Psychrometrics.projected_rh(outdoor[:dew], temp).round(1),
      axes: { humidity: axis_fields(decision.humidity, [RH_MIN, RH_MAX], ideals[:rh]),
              temperature: axis_fields(decision.temperature, [TEMP_MIN, TEMP_MAX], ideals[:temp]) },
      indoor: indoor_fields(reading),
      outdoor: outdoor_fields(outdoor),
      airing: Airing.plan(readings, humidity_open: decision.humidity.verdict == :open, outdoor_dew: outdoor[:dew],
                                    rh_ideal: ideals[:rh], now: now),
      settings: { temp_ideal: ideals[:temp], rh_ideal: ideals[:rh], temp_margin: TEMP_MARGIN, rh_margin: RH_MARGIN,
                  min_outdoor_temp: MIN_OUTDOOR_TEMP } }
  end

  # xbar variable (VAR_*) or default: from the environment when xbar runs the plugin,
  # else from the file where xbar saves them. Accepts "21,5" as "21.5".
  def variable(name, default)
    raw = (ENV[name] || saved_variables[name]).to_s.strip
    return default if raw.empty?

    Float(raw.tr(',', '.'), exception: false) or raise "#{name} invalide : « #{raw} »"
  end

  def saved_variables
    @saved_variables ||= File.exist?(@vars_file) ? JSON.parse(File.read(@vars_file, encoding: 'UTF-8')) : {}
  rescue JSON::ParserError
    @saved_variables = {}
  end

  def axis_fields(axis, target, ideal)
    { target: target, ideal: ideal, verdict: axis.verdict, reason: axis.reason }
  end

  def indoor_fields(reading)
    { entered_at: reading['at'], temperature: reading['temperature'], humidity: reading['humidity'],
      windows: reading['windows'] || 'closed',
      dew_point: Psychrometrics.dew_point(reading['temperature'], reading['humidity']).round(1) }
  end

  def outdoor_fields(outdoor)
    { measured_at: iso(outdoor[:time]), temperature: outdoor[:temp], humidity: outdoor[:rh],
      dew_point: outdoor[:dew], incomplete_update_at: outdoor[:incomplete] && iso(outdoor[:incomplete]) }.compact
  end
end
