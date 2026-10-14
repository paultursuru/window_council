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

    it 'closes when outdoor air would leave the target (21 °C / 50 % inside, 5 °C / 90 % outside → 32 %)' do
      expect(decision([21, 50], [5, 90]).verdict).to eq(:close)
    end

    it 'is indifferent when everything is on target (22.5 °C / 50 % inside, 20 °C / 50 % outside)' do
      expect(decision([22.5, 50], [20, 50]).verdict).to eq(:indifferent)
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
end
