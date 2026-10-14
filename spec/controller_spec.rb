# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Controller do
  describe '#build_report' do
    it 'accepts a decimal comma in xbar variables' do
      expect(build_report(indoor_temp: '21,5')[:indoor][:temperature]).to eq(21.5)
    end

    it 'reports an invalid value' do
      expect(build_report(indoor_temp: 'abc')[:error]).to eq('VAR_INDOOR_TEMP invalide : « abc »')
    end

    it 'rejects a humidity outside 0–100 %' do
      expect(build_report(indoor_rh: '120')[:error]).to start_with('VAR_INDOOR_RH doit être entre 0 et 100')
    end

    it 'summarises a network timeout' do
      allow(MeteoSwiss).to receive(:current).and_raise(Timeout::Error)
      expect(controller.build_report[:error]).to eq("Délai réseau dépassé (#{TIMEOUT} s)")
    end
  end

  describe '#save' do
    it 'writes the JSON and the page, adding each successful run to the history' do
      Dir.mktmpdir do |dir|
        stub_const('DATA_DIR', dir)
        stub_const('JSON_FILE', File.join(dir, 'report.json'))
        stub_const('HTML_FILE', File.join(dir, 'report.html'))
        report = build_report

        2.times { expect(controller.save(report)).to be_nil }
        expect(JSON.parse(File.read(JSON_FILE))['history'].size).to eq(2)
        expect(File.read(HTML_FILE, encoding: 'UTF-8')).to include('À vous de voir')
      end
    end
  end
end
