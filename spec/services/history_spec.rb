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
