# frozen_string_literal: true

require 'tmpdir'
require_relative '../window_council_app/controller'

# Reports built offline, from fixed readings and MeteoSwiss measurement
module ReportHelpers
  MEASUREMENT = { temp: 10.0, rh: 60.0, dew: 2.6, time: Time.new(2026, 10, 14, 10, 50) }.freeze

  def reading(temp, rh, time: '2026-10-14T10:40:00+02:00', windows: 'closed', dew: nil)
    { 'at' => time, 'temperature' => temp, 'humidity' => rh, 'windows' => windows, 'outdoor_dew_point' => dew }.compact
  end

  def build_report(indoor_temp: 18.0, indoor_rh: 68.0, readings: nil, vars: {}, measurement: MEASUREMENT)
    Readings.write(readings || [reading(indoor_temp, indoor_rh)])
    stub_const('ENV', ENV.to_h.merge(vars))
    allow(MeteoSwiss).to receive(:current).and_return(measurement)
    controller.build_report
  end

  def controller
    Controller.new(plugin_path: File.join(DATA_DIR, 'missing.10m.rb'))
  end
end

RSpec.configure do |config|
  config.include ReportHelpers

  # Generated files go to a temporary folder, never to the real data/
  config.around do |example|
    Dir.mktmpdir do |dir|
      @data_dir = dir
      example.run
    end
  end

  config.before do
    stub_const('DATA_DIR', @data_dir)
    { 'JSON_FILE' => 'report.json', 'HTML_FILE' => 'report.html', 'READINGS_FILE' => 'readings.json',
      'LOCK_FILE' => '.lock' }.each { |name, file| stub_const(name, File.join(@data_dir, file)) }
  end
end
