# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Controller do
  describe '#build_report' do
    it 'decides on the latest reading' do
      readings = [reading(18.0, 68.0, time: '2026-10-14T09:00:00+02:00'), reading(21.5, 50.0)]
      expect(build_report(readings: readings)[:indoor]).to include(temperature: 21.5, humidity: 50.0, windows: 'closed')
    end

    it 'takes the ideals from xbar variables, accepting a decimal comma' do
      settings = build_report(vars: { 'VAR_TEMP_IDEAL' => '20,5', 'VAR_RH_IDEAL' => '45' })[:settings]
      expect(settings).to include(temp_ideal: 20.5, rh_ideal: 45.0)
    end

    it 'reads the ideals from the xbar file when not run by xbar (form server)' do
      plugin = File.join(DATA_DIR, 'window_council.10m.rb')
      File.write("#{plugin}.vars.json", JSON.generate('VAR_RH_IDEAL' => '44'))
      Readings.write([reading(21.0, 46.0)])
      allow(MeteoSwiss).to receive(:current).and_return(ReportHelpers::MEASUREMENT)
      expect(described_class.new(plugin_path: plugin).build_report[:settings][:rh_ideal]).to eq(44.0)
    end

    it 'reports an invalid ideal' do
      expect(build_report(vars: { 'VAR_TEMP_IDEAL' => 'abc' })[:error]).to eq('VAR_TEMP_IDEAL invalide : « abc »')
    end

    it 'rejects an ideal humidity outside 0–100 %' do
      error = build_report(vars: { 'VAR_RH_IDEAL' => '120' })[:error]
      expect(error).to start_with('VAR_RH_IDEAL doit être entre 0 et 100')
    end

    it 'asks for a first reading' do
      expect(build_report(readings: [])[:error]).to start_with('Aucun relevé intérieur')
    end

    it 'summarises a network timeout' do
      Readings.write([reading(21.0, 46.0)])
      allow(MeteoSwiss).to receive(:current).and_raise(Timeout::Error)
      expect(controller.build_report[:error]).to eq("Délai réseau dépassé (#{TIMEOUT} s)")
    end
  end

  describe '#refresh' do
    it 'sets the reminder to close after a reading that opens the windows' do
      opened = reading(21.0, 46.0, time: ApplicationHelper.iso(Time.now - 60), windows: 'cross')
      build_report(readings: [opened], vars: { 'VAR_RH_IDEAL' => '42' })

      expect(controller.refresh).to be_nil
      expect(CloseReminder.read).to include('id' => 'x-apple-reminder://TEST')
    end
  end

  describe '#save' do
    it 'writes the JSON and the page, adding each successful run to the history' do
      report = build_report

      2.times { expect(controller.save(report)).to be_nil }
      expect(JSON.parse(File.read(JSON_FILE))['history'].size).to eq(2)
      expect(File.read(HTML_FILE, encoding: 'UTF-8')).to include('À vous de voir')
    end
  end
end
