# frozen_string_literal: true

require_relative '../config/settings'
require_relative '../helpers/application_helper'
require_relative '../models/axis'
require_relative '../models/decision'
require_relative 'psychrometrics'

# Decides whether to open: each axis checks if outdoor air would bring the room
# closer to its target, then both are combined. Pure functions.
module Council
  extend ApplicationHelper

  module_function

  def humidity_axis(indoor_rh, projected_rh)
    air = "l'air extérieur donnerait #{fmt(projected_rh)} %"
    if indoor_rh > RH_MAX
      if projected_rh < indoor_rh - RH_MARGIN then Axis.new(:open, "trop humide, #{air}", 'air sec')
      else Axis.new(:close, "trop humide, mais #{air}", 'trop humide dehors')
      end
    elsif indoor_rh < RH_MIN
      if projected_rh > indoor_rh + RH_MARGIN then Axis.new(:open, "trop sec, #{air}", 'air humide')
      else Axis.new(:close, "trop sec, mais #{air}", 'trop sec dehors')
      end
    elsif projected_rh.between?(RH_MIN, RH_MAX)
      Axis.new(:indifferent, "dans la cible, #{air}", nil)
    else
      Axis.new(:close, "dans la cible, mais #{air}", projected_rh < RH_MIN ? 'trop sec dehors' : 'trop humide dehors')
    end
  end

  def temperature_axis(indoor_temp, outdoor_temp)
    outside = "#{fmt(outdoor_temp)} °C dehors"
    if indoor_temp > TEMP_MAX
      if outdoor_temp < indoor_temp - TEMP_MARGIN then Axis.new(:open, "trop chaud, #{outside}", 'air plus frais')
      else Axis.new(:close, "trop chaud, mais #{outside}", 'trop chaud dehors')
      end
    elsif indoor_temp < TEMP_MIN
      if outdoor_temp > indoor_temp + TEMP_MARGIN then Axis.new(:open, "trop froid, #{outside}", 'air plus chaud')
      else Axis.new(:close, "trop froid, mais #{outside}", 'trop froid dehors')
      end
    else
      Axis.new(:indifferent, 'dans la cible', nil)
    end
  end

  # Below MIN_OUTDOOR_TEMP, humidity alone turns from open to close,
  # unless temperature also says open.
  def combine(humidity, temperature, outdoor_temp)
    if humidity.verdict == :open && temperature.verdict != :open && outdoor_temp < MIN_OUTDOOR_TEMP
      too_cold = "#{humidity.reason}, mais trop froid dehors pour aérer (< #{fmt(MIN_OUTDOOR_TEMP)} °C)"
      humidity = Axis.new(:close, too_cold, 'trop froid dehors')
    end
    pro = [humidity, temperature].select { |a| a.verdict == :open }
    con = [humidity, temperature].select { |a| a.verdict == :close }
    verdict, reason =
      if pro.any? && con.any? then [:conflict, "#{pro[0].short} mais #{con[0].short}"]
      elsif pro.any?          then [:open, pro.map(&:short).join(' et ')]
      elsif con.any?          then [:close, con.map(&:short).join(' et ')]
      else                         [:indifferent, 'humidité et température dans la cible']
      end
    Decision.new(verdict, reason, humidity, temperature)
  end

  # From measurements to decision
  def decide(indoor_temp, indoor_rh, outdoor_temp, outdoor_dew_point)
    projected = Psychrometrics.projected_rh(outdoor_dew_point, indoor_temp)
    combine(humidity_axis(indoor_rh, projected), temperature_axis(indoor_temp, outdoor_temp), outdoor_temp)
  end
end
