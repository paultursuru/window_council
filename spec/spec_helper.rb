# frozen_string_literal: true

require 'tmpdir'
require_relative '../window_council_app/controller'

# Reports built offline, with fixed xbar variables and MeteoSwiss measurement
module ReportHelpers
  MEASUREMENT = { temp: 10.0, rh: 60.0, dew: 2.6, time: Time.new(2026, 10, 14, 10, 50) }.freeze

  def build_report(indoor_temp: '18', indoor_rh: '68', measurement: MEASUREMENT)
    stub_const('ENV', ENV.to_h.merge('VAR_INDOOR_TEMP' => indoor_temp, 'VAR_INDOOR_RH' => indoor_rh))
    allow(MeteoSwiss).to receive(:current).and_return(measurement)
    controller.build_report
  end

  def controller
    Controller.new(plugin_path: File.join(Dir.tmpdir, 'missing.10m.rb'))
  end
end

RSpec.configure do |config|
  config.include ReportHelpers
end
