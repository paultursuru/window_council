# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Council do
  # inside / outside: [temperature °C, RH %]
  def decision(inside, outside)
    described_class.decide(inside[0], inside[1], outside[0], Psychrometrics.dew_point(*outside))
  end

  describe '.decide' do
    it 'opens when outdoor air is drier (21 °C / 68 % inside, 12 °C / 60 % outside)' do
      expect(decision([21, 68], [12, 60]).verdict).to eq(:open)
    end

    it 'closes when outdoor air would move the room away from RH_IDEAL ' \
       '(21 °C / 50 % inside, 5 °C / 90 % outside → 32 %)' do
      expect(decision([21, 50], [5, 90]).verdict).to eq(:close)
    end

    it 'opens when drier air brings the room back toward RH_IDEAL, ' \
       'even if it would end up below the target (21.9 °C / 55 % inside, 11.6 °C / 75.8 % outside → 39.5 %)' do
      d = decision([21.9, 55], [11.6, 75.8])
      expect([d.verdict, d.reason]).to eq([:open, 'air sec'])
    end

    it 'is indifferent when everything is near the ideals (22 °C / 50 % inside, 20 °C / 58 % outside → 51.4 %)' do
      expect(decision([22, 50], [20, 58]).verdict).to eq(:indifferent)
    end

    it 'aims at the ideals it is given (21 °C / 46 % inside, 12 °C / 65 % outside → 37 %)' do
      inside = [21, 46]
      dew = Psychrometrics.dew_point(12, 65)
      expect(described_class.decide(*inside, 12, dew).verdict).to eq(:close)
      expect(described_class.decide(*inside, 12, dew, rh_ideal: 42).verdict).to eq(:open)
    end

    it 'reports a conflict when the axes disagree (18 °C / 68 % inside, 10 °C / 60 % outside)' do
      d = decision([18, 68], [10, 60])
      expect([d.verdict, d.reason]).to eq([:conflict, 'air sec mais trop froid dehors'])
    end

    context 'when it is colder than MIN_OUTDOOR_TEMP outside' do
      it 'does not open for humidity alone (21 °C / 68 % inside, 2 °C / 80 % outside)' do
        expect(decision([21, 68], [2, 80]).verdict).to eq(:close)
      end

      it 'opens when temperature also says so (26 °C / 68 % inside, 2 °C / 80 % outside)' do
        expect(decision([26, 68], [2, 80]).verdict).to eq(:open)
      end
    end
  end

  # indoor RH, projected RH → verdict, with a 40–60 % target, RH_IDEAL 50 % and a 3-point margin
  describe '.humidity_axis' do
    {
      [55, 39.5] => :open,        # above the ideal, drier air
      [45, 62] => :open,          # below the ideal, wetter air
      [68, 32] => :open,          # too humid, drier air
      [55, 57] => :close,         # above the ideal, air not drier enough
      [45, 42] => :close,         # below the ideal, drier air
      [35, 38] => :close,         # too dry, air not wetter enough
      [51, 32] => :close,         # at the ideal, air would move it away
      [51, 49] => :indifferent    # at the ideal, air close to it
    }.each do |(indoor, projected), verdict|
      it "#{verdict} at #{indoor} % inside with outdoor air at #{projected} %" do
        expect(described_class.humidity_axis(indoor, projected).verdict).to eq(verdict)
      end
    end
  end

  # indoor, outdoor °C → verdict and reason, with TEMP_IDEAL 21 °C, a 1 °C margin and a 20–25 °C target
  describe '.temperature_axis' do
    {
      [23, 15] => [:open, 'plutôt chaud, 15.0 °C dehors'],
      [26, 15] => [:open, 'trop chaud, 15.0 °C dehors'],
      [23, 23] => [:close, 'plutôt chaud, mais 23.0 °C dehors'],
      [19.5, 10] => [:close, 'trop froid, mais 10.0 °C dehors'],
      [19.5, 24] => [:open, 'trop froid, 24.0 °C dehors'],
      [21.5, 10] => [:indifferent, "proche de l'idéal"]
    }.each do |(indoor, outdoor), (verdict, reason)|
      it "#{verdict} at #{indoor} °C inside with #{outdoor} °C outside" do
        axis = described_class.temperature_axis(indoor, outdoor)
        expect([axis.verdict, axis.reason]).to eq([verdict, reason])
      end
    end
  end
end
