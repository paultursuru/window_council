# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Readings do
  describe '.parse' do
    let(:now) { Time.local(2026, 10, 22, 19, 0, 30) }
    let(:form) { { 'temperature' => '21,5', 'humidity' => '46', 'time' => '', 'windows' => 'one' } }

    it 'reads a decimal comma and takes now for an empty time' do
      expect(described_class.parse(form, now)).to eq(
        'at' => ApplicationHelper.iso(now), 'temperature' => 21.5, 'humidity' => 46.0, 'windows' => 'one'
      )
    end

    it 'puts a time today, or yesterday when it is later than now' do
      at = ->(time) { described_class.parse(form.merge('time' => time), now)['at'] }
      expect(at.call('18:45')).to eq(ApplicationHelper.iso(Time.local(2026, 10, 22, 18, 45)))
      expect(at.call('23:50')).to eq(ApplicationHelper.iso(Time.local(2026, 10, 21, 23, 50)))
    end

    {
      { 'humidity' => '' } => 'Humidité manquante',
      { 'humidity' => '120' } => 'Humidité entre 0 et 100 % (« 120.0 »)',
      { 'temperature' => 'abc' } => 'Température invalide : « abc »',
      { 'time' => '25:00' } => 'Heure invalide : « 25:00 » (par exemple 18:45)',
      { 'windows' => 'all' } => 'État des fenêtres inconnu (« all »)'
    }.each do |change, message|
      it "refuses #{change.inspect}" do
        expect { described_class.parse(form.merge(change), now) }.to raise_error(Readings::Invalid, message)
      end
    end
  end

  describe '.add' do
    it 'keeps readings sorted, and replaces one entered again at the same time' do
      described_class.add(reading(21.0, 46.0, time: '2026-10-22T18:45:00+02:00'))
      described_class.add(reading(21.0, 44.0, time: '2026-10-22T17:55:00+02:00'))
      described_class.add(reading(21.0, 41.0, time: '2026-10-22T18:45:00+02:00'))
      expect(described_class.read.map { |r| r['humidity'] }).to eq([44.0, 41.0])
    end
  end

  describe '.load' do
    it 'starts from the xbar entries in the history, counting entries seconds apart once' do
      entry = { 'indoor_temp' => 20.6, 'indoor_rh' => 48.0, 'outdoor_dew_point' => 6.0 }
      history = [entry.merge('entered_at' => '2026-10-22T09:00:10+02:00'),
                 entry.merge('entered_at' => '2026-10-22T09:00:13+02:00'),
                 entry.merge('entered_at' => '2026-10-22T09:00:13+02:00'),
                 entry.merge('entered_at' => '2026-10-22T14:03:25+02:00', 'indoor_temp' => 21.0, 'indoor_rh' => 46.0)]
      File.write(JSON_FILE, JSON.generate('history' => history))
      expect(described_class.load).to eq(
        [{ 'at' => '2026-10-22T09:00:13+02:00', 'temperature' => 20.6, 'humidity' => 48.0, 'outdoor_dew_point' => 6.0 },
         { 'at' => '2026-10-22T14:03:25+02:00', 'temperature' => 21.0, 'humidity' => 46.0, 'outdoor_dew_point' => 6.0 }]
      )
      expect(File).to exist(READINGS_FILE)
    end
  end
end
