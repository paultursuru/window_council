# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Airing do
  # 22.10.2026: one window open 45 min, 21 °C / 46 % → 41 %, outdoor dew point 5.5 °C (36.4 % at 21 °C)
  let(:opened) { reading(21.0, 46.0, time: '2026-10-22T17:55:00+02:00', windows: 'one', dew: 5.5) }
  let(:closed) { reading(21.0, 41.0, time: '2026-10-22T18:40:00+02:00', dew: 5.5) }

  def at(hour, min)
    Time.new(2026, 10, 22, hour, min, 0, '+02:00')
  end

  describe '.sample' do
    it 'measures how fast the gap with outdoor air shrinks' do
      expect(described_class.sample(opened, closed)['rate']).to be_within(0.01).of(0.98)
    end

    it 'says nothing with windows closed, or when humidity moves away from outdoor air' do
      expect(described_class.sample(closed, opened)).to be_nil
      expect(described_class.sample(opened, closed.merge('humidity' => 48.0))).to be_nil
    end
  end

  describe '.rates' do
    it 'uses the measured airings, or the default rate' do
      rates = described_class.rates([opened, closed])
      expect(rates['one']).to include(samples: 1)
      expect(rates['one'][:rate]).to be_within(0.01).of(0.98)
      expect(rates['cross']).to eq(rate: AIRING_RATES['cross'], samples: 0)
    end
  end

  # indoor RH, projected RH, ideal → RH to aim for
  describe '.target' do
    {
      [46, 36.6, 45] => 45,    # drier air reaches the ideal
      [55, 47, 45] => 50.0,    # drier air, but not enough to reach it
      [46, 36.6, 50] => nil,   # drying would move away from it
      [35, 45, 50] => 42.0     # wetter air
    }.each do |(indoor, projected, ideal), goal|
      it "aims at #{goal.inspect} from #{indoor} % with outdoor air at #{projected} % and an ideal of #{ideal} %" do
        expect(described_class.target(indoor, projected, ideal)).to eq(goal)
      end
    end
  end

  describe '.plan' do
    it 'says how long to air when humidity says open' do
      plan = described_class.plan([closed.merge('humidity' => 55.0)], humidity_open: true, outdoor_dew: 5.5,
                                                                      rh_ideal: 45.0, now: at(19, 0))
      expect(plan).to include(target_rh: 45.0, durations: { 'one' => 46, 'cross' => 12 })
    end

    it 'follows an airing in progress: estimated humidity, then when to close' do
      plan = described_class.plan([opened], humidity_open: true, outdoor_dew: 5.5, rh_ideal: 42.0, now: at(18, 10))
      expect(plan[:open]).to eq(windows: 'one', since: opened['at'], estimated_rh: 43.9,
                                close_at: '2026-10-22T18:27:14+02:00', due: false)
    end

    it 'says when it is time to close' do
      plan = described_class.plan([opened], humidity_open: true, outdoor_dew: 5.5, rh_ideal: 42.0, now: at(18, 30))
      expect(plan[:open]).to include(estimated_rh: 41.7, due: true)
    end

    it 'forgets windows left open without a reading for hours' do
      plan = described_class.plan([opened], humidity_open: true, outdoor_dew: 5.5, rh_ideal: 42.0, now: at(23, 59))
      expect(plan).not_to have_key(:open)
    end
  end
end
