# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe History do
  describe '.prune' do
    it 'drops an 8-day-old entry and keeps a 1-hour-old one' do
      now = Time.now
      history = [{ 'recorded_at' => ApplicationHelper.iso(now - (8 * 86_400)) },
                 { 'recorded_at' => ApplicationHelper.iso(now - 3600) }]
      expect(described_class.prune(history, now)).to eq([history[1]])
    end
  end

  describe '.dew_point_at' do
    let(:history) do
      [{ 'measured_at' => '2026-10-22T17:30:00+02:00', 'outdoor_dew_point' => 4.8 },
       { 'measured_at' => '2026-10-22T18:00:00+02:00', 'outdoor_dew_point' => 5.4 }]
    end

    it 'takes the closest outdoor measurement, within 45 min' do
      expect(described_class.dew_point_at(history, Time.new(2026, 10, 22, 17, 55, 0, '+02:00'))).to eq(5.4)
      expect(described_class.dew_point_at(history, Time.new(2026, 10, 22, 19, 0, 0, '+02:00'))).to be_nil
    end
  end

  describe '.read' do
    it 'restarts from scratch on an unreadable file, keeping a copy' do
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'report.json')
        File.write(file, '{ not json')
        expect(described_class.read(file)).to eq([])
        expect(File.read("#{file}.unreadable")).to eq('{ not json')
      end
    end
  end
end
