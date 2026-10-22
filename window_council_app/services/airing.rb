# frozen_string_literal: true

require_relative '../config/settings'
require_relative '../helpers/application_helper'
require_relative 'psychrometrics'

# How long to air. With windows open, the gap between indoor and outdoor vapour pressure
# shrinks as exp(-rate × time). The rate is measured on past airings (a reading with windows
# open, then the next reading), per window setting; AIRING_RATES until then.
module Airing
  extend ApplicationHelper

  module_function

  OPEN = %w[one cross].freeze
  SAMPLES = 5                             # latest airings kept per window setting
  SAMPLE_HOURS = ((5 / 60.0)..3.0).freeze # shorter or longer airings are not measured
  MIN_GAP = 0.5                           # hPa (~2 % RH at 21 °C): closer to outdoor air, an airing says nothing
  MAX_OPEN_HOURS = 6                      # beyond it, windows were probably closed without a reading

  # Rates, then either the airing in progress or how long to air when humidity says open
  def plan(readings, humidity_open:, outdoor_dew:, rh_ideal:, now:)
    rates = rates(readings)
    plan = { rates: OPEN.to_h { |w| [w, rate_fields(rates[w])] } }
    latest = readings.last
    projected = Psychrometrics.projected_rh(outdoor_dew, latest['temperature'])
    goal = target(latest['humidity'], projected, rh_ideal)
    open = OPEN.include?(latest['windows']) && in_progress(latest, rates, projected, goal, now)
    if open
      plan[:open] = open
    elsif humidity_open && goal
      plan[:target_rh] = goal.round(1)
      plan[:durations] = OPEN.to_h { |w| [w, minutes(hours_to(latest['humidity'], projected, goal, rates[w][:rate]))] }
    end
    plan
  end

  # Median of the latest airings per window setting, or the default rate
  def rates(readings)
    all = samples(readings)
    OPEN.to_h do |w|
      found = all.select { |s| s['windows'] == w }.last(SAMPLES).map { |s| s['rate'] }.sort
      median = found.empty? ? AIRING_RATES[w] : (found[(found.size - 1) / 2] + found[found.size / 2]) / 2.0
      [w, { rate: median, samples: found.size }]
    end
  end

  def samples(readings)
    readings.each_cons(2).map { |from, till| sample(from, till) }.compact
  end

  # Rate (per hour) of the airing between two readings, or nil when it says nothing: windows closed,
  # too short or too long, no outdoor measurement, room already near outdoor air, humidity not moving toward it
  def sample(from, till)
    hours = (time_at(till['at']) - time_at(from['at'])) / 3600.0
    dews = [from, till].map { |r| r['outdoor_dew_point'] }.compact
    return unless OPEN.include?(from['windows']) && SAMPLE_HOURS.cover?(hours) && dews.any?

    outdoor = Psychrometrics.saturation_pressure(dews.sum / dews.size)
    before = vapour(from) - outdoor
    after = vapour(till) - outdoor
    return unless before.abs >= MIN_GAP && (after / before).between?(0.05, 0.95)

    { 'windows' => from['windows'], 'rate' => Math.log(before / after) / hours }
  end

  # RH to aim for: the ideal, unless outdoor air cannot get that far; nil if airing moves away from it
  def target(indoor_rh, projected_rh, ideal)
    goal = if projected_rh < indoor_rh then [ideal, projected_rh + RH_MARGIN].max
           else [ideal, projected_rh - RH_MARGIN].min
           end
    goal if ((indoor_rh - goal) * (indoor_rh - projected_rh)).positive?
  end

  # Hours of airing to go from indoor_rh to goal (indoor temperature barely moves: the walls hold the heat)
  def hours_to(indoor_rh, projected_rh, goal, rate)
    Math.log((indoor_rh - projected_rh) / (goal - projected_rh)) / rate
  end

  def estimate(indoor_rh, projected_rh, rate, hours)
    projected_rh + ((indoor_rh - projected_rh) * Math.exp(-rate * hours))
  end

  # Windows open since the latest reading: estimated RH now, and when to close
  def in_progress(reading, rates, projected, goal, now)
    rate = rates[reading['windows']][:rate]
    since = time_at(reading['at'])
    hours = [(now - since) / 3600.0, 0].max
    return if hours > MAX_OPEN_HOURS

    open = { windows: reading['windows'], since: reading['at'],
             estimated_rh: estimate(reading['humidity'], projected, rate, hours).round(1) }
    return open unless goal

    close_at = since + (hours_to(reading['humidity'], projected, goal, rate) * 3600)
    open.merge(close_at: iso(close_at), due: close_at <= now)
  end

  # Time for the gap with outdoor air to halve, and how many airings measured it
  def rate_fields(rate)
    { half_life: minutes(Math.log(2) / rate[:rate]), samples: rate[:samples] }
  end

  def minutes(hours)
    [(hours * 60).round, 1].max
  end

  def vapour(reading)
    reading['humidity'] / 100.0 * Psychrometrics.saturation_pressure(reading['temperature'])
  end
end
