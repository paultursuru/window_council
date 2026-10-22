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

  # Humidity aims at its ideal, not just anywhere in the target. What counts is the direction:
  # a few minutes of airing move the room long before it gets near the projected RH.
  def humidity_axis(indoor_rh, projected_rh, ideal = RH_IDEAL)
    air = "l'air extérieur donnerait #{fmt(projected_rh)} %"
    if indoor_rh > ideal + RH_MARGIN
      state = indoor_rh > RH_MAX ? 'trop humide' : 'plutôt humide'
      if projected_rh < indoor_rh - RH_MARGIN then Axis.new(:open, "#{state}, #{air}", 'air sec')
      else Axis.new(:close, "#{state}, mais #{air}", 'trop humide dehors')
      end
    elsif indoor_rh < ideal - RH_MARGIN
      state = indoor_rh < RH_MIN ? 'trop sec' : 'plutôt sec'
      if projected_rh > indoor_rh + RH_MARGIN then Axis.new(:open, "#{state}, #{air}", 'air humide')
      else Axis.new(:close, "#{state}, mais #{air}", 'trop sec dehors')
      end
    elsif (projected_rh - indoor_rh).abs > RH_MARGIN
      away = projected_rh < indoor_rh ? 'trop sec dehors' : 'trop humide dehors'
      Axis.new(:close, "proche de l'idéal, mais #{air}", away)
    else
      Axis.new(:indifferent, "proche de l'idéal, #{air}", nil)
    end
  end

  # Temperature aims at its ideal too. Near it, airing is indifferent: the walls hold the heat,
  # so a short airing barely moves the room temperature.
  def temperature_axis(indoor_temp, outdoor_temp, ideal = TEMP_IDEAL)
    outside = "#{fmt(outdoor_temp)} °C dehors"
    if indoor_temp > ideal + TEMP_MARGIN
      state = indoor_temp > TEMP_MAX ? 'trop chaud' : 'plutôt chaud'
      if outdoor_temp < indoor_temp - TEMP_MARGIN then Axis.new(:open, "#{state}, #{outside}", 'air plus frais')
      else Axis.new(:close, "#{state}, mais #{outside}", 'trop chaud dehors')
      end
    elsif indoor_temp < ideal - TEMP_MARGIN
      state = indoor_temp < TEMP_MIN ? 'trop froid' : 'plutôt froid'
      if outdoor_temp > indoor_temp + TEMP_MARGIN then Axis.new(:open, "#{state}, #{outside}", 'air plus chaud')
      else Axis.new(:close, "#{state}, mais #{outside}", 'trop froid dehors')
      end
    else
      Axis.new(:indifferent, "proche de l'idéal", nil)
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
      else                         [:indifferent, "humidité et température proches de l'idéal"]
      end
    Decision.new(verdict, reason, humidity, temperature)
  end

  # From measurements to decision
  def decide(indoor_temp, indoor_rh, outdoor_temp, outdoor_dew_point, rh_ideal: RH_IDEAL, temp_ideal: TEMP_IDEAL)
    projected = Psychrometrics.projected_rh(outdoor_dew_point, indoor_temp)
    combine(humidity_axis(indoor_rh, projected, rh_ideal), temperature_axis(indoor_temp, outdoor_temp, temp_ideal),
            outdoor_temp)
  end
end
