# frozen_string_literal: true

require 'date'
require 'json'
require_relative '../config/settings'
require_relative '../helpers/application_helper'
require_relative 'history'
require_relative 'storage'

# Hygrometer readings entered on the page, sorted by time in readings.json:
# { "at", "temperature", "humidity", "windows", "outdoor_dew_point" }.
module Readings
  extend ApplicationHelper

  module_function

  # A form value no reading can be built from; its message is shown on the page
  class Invalid < StandardError; end

  # An unreadable file raises rather than restarting: these are the only copy of the readings
  def read(file = READINGS_FILE)
    return [] unless File.exist?(file)

    sort(JSON.parse(File.read(file, encoding: 'UTF-8')))
  end

  # Readings, taken from the history on the first run after entries moved from xbar to the page
  def load(file = READINGS_FILE, history_file = JSON_FILE)
    unless File.exist?(file)
      Storage.locked { write(seed(History.read(history_file)), file) unless File.exist?(file) }
    end
    read(file)
  end

  # Adds a reading, replacing the one at the same time: entering it again corrects it
  def add(reading, file = READINGS_FILE)
    Storage.locked do
      write(read(file).reject { |r| r['at'] == reading['at'] } << reading, file)
    end
  end

  def write(readings, file = READINGS_FILE)
    Storage.write_atomically(file, JSON.pretty_generate(sort(readings)))
  end

  # Last HISTORY_DAYS days, and the reading before them: the latest one is always kept
  def recent(readings, now)
    limit = now - (HISTORY_DAYS * 86_400)
    first = readings.index { |r| time_at(r['at']) >= limit } || readings.size
    readings.drop([first - 1, 0].max)
  end

  # One reading per xbar entry; entries a few seconds apart (one per variable typed) count once
  def seed(history)
    readings = history.select { |e| e['entered_at'] && e['indoor_temp'] }.map do |e|
      { 'at' => e['entered_at'], 'temperature' => e['indoor_temp'], 'humidity' => e['indoor_rh'],
        'outdoor_dew_point' => e['outdoor_dew_point'] }
    end
    readings = sort(readings.uniq { |r| r['at'] })
    readings.reject.with_index do |r, i|
      following = readings[i + 1]
      following && time_at(following['at']) - time_at(r['at']) < 120
    end
  end

  # Form fields → reading. Empty time is now; "18:45" is today, or yesterday if later than now.
  def parse(params, now)
    temp = number(params['temperature'], 'Température')
    rh = number(params['humidity'], 'Humidité')
    raise Invalid, "Humidité entre 0 et 100 % (« #{fmt(rh)} »)" unless rh.positive? && rh <= 100
    raise Invalid, "Température peu plausible (« #{fmt(temp)} °C »)" unless temp.between?(0, 40)

    windows = params['windows'].to_s
    raise Invalid, "État des fenêtres inconnu (« #{windows} »)" unless ApplicationHelper::WINDOWS.key?(windows)

    { 'at' => iso(time_of_day(params['time'], now)), 'temperature' => temp, 'humidity' => rh, 'windows' => windows }
  end

  # Accepts "21,5" as "21.5"
  def number(raw, name)
    raw = raw.to_s.strip
    raise Invalid, "#{name} manquante" if raw.empty?

    Float(raw.tr(',', '.'), exception: false) or raise Invalid, "#{name} invalide : « #{raw} »"
  end

  def time_of_day(raw, now)
    raw = raw.to_s.strip
    return now if raw.empty?

    match = raw.match(/\A(\d{1,2})[:h.](\d{2})\z/)
    hour, min = match && [match[1].to_i, match[2].to_i]
    raise Invalid, "Heure invalide : « #{raw} » (par exemple 18:45)" unless hour && hour < 24 && min < 60

    day = now.to_date
    day -= 1 if Time.local(day.year, day.month, day.day, hour, min) > now + 300
    Time.local(day.year, day.month, day.day, hour, min)
  end

  # By time, not by string: the UTC offset changes with daylight saving time
  def sort(readings)
    readings.sort_by { |r| time_at(r['at']) }
  end
end
