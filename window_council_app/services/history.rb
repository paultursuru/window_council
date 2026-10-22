# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require_relative '../config/settings'

# One entry per successful run, kept HISTORY_DAYS days in report.json for the charts.
module History
  module_function

  # Saved history; an unreadable file is kept as .unreadable and history restarts
  def read(file)
    return [] unless File.exist?(file)

    Array(JSON.parse(File.read(file, encoding: 'UTF-8'))['history'])
  rescue StandardError
    FileUtils.cp(file, "#{file}.unreadable")
    []
  end

  # Flat entry; each value keeps its own timestamp (xbar entry, MeteoSwiss measurement)
  def entry(report)
    indoor = report[:indoor]
    outdoor = report[:outdoor]
    { 'recorded_at' => report[:updated_at], 'verdict' => report[:verdict].to_s,
      'entered_at' => indoor[:entered_at], 'indoor_temp' => indoor[:temperature], 'indoor_rh' => indoor[:humidity],
      'measured_at' => outdoor[:measured_at], 'outdoor_temp' => outdoor[:temperature],
      'outdoor_rh' => outdoor[:humidity], 'outdoor_dew_point' => outdoor[:dew_point],
      'projected_rh' => report[:projected_rh] }
  end

  # Keeps the last HISTORY_DAYS days
  def prune(history, now)
    limit = now - (HISTORY_DAYS * 86_400)
    history.select { |e| DateTime.iso8601(e['recorded_at']).to_time >= limit }
  end

  # Outdoor dew point measured closest to time, within 45 min, or nil
  def dew_point_at(history, time)
    gap = ->(e) { (DateTime.iso8601(e['measured_at']).to_time - time).abs }
    closest = history.select { |e| e['measured_at'] && e['outdoor_dew_point'] }.min_by(&gap)
    closest['outdoor_dew_point'] if closest && gap.call(closest) <= 45 * 60
  end
end
