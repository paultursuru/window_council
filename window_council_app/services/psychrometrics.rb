# frozen_string_literal: true

# Magnus formulas (a = 17.62, b = 243.12).
module Psychrometrics
  module_function

  MAGNUS_A = 17.62
  MAGNUS_B = 243.12

  # Saturation vapour pressure, hPa
  def saturation_pressure(t)
    6.112 * Math.exp(MAGNUS_A * t / (MAGNUS_B + t))
  end

  # Dew point, °C
  def dew_point(t, rh)
    g = Math.log(rh / 100.0) + (MAGNUS_A * t / (MAGNUS_B + t))
    MAGNUS_B * g / (MAGNUS_A - g)
  end

  # RH of outdoor air once brought to indoor_temp
  def projected_rh(outdoor_dew_point, indoor_temp)
    100.0 * saturation_pressure(outdoor_dew_point) / saturation_pressure(indoor_temp)
  end
end
