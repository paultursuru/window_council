# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Psychrometrics do
  describe '.projected_rh' do
    it 'gives about 32 % for air at 5 °C / 90 % brought to 21 °C' do
      expect(described_class.projected_rh(described_class.dew_point(5, 90), 21).round).to eq(32)
    end

    it 'round-trips through the dew point' do
      expect(described_class.projected_rh(described_class.dew_point(21, 60), 21)).to be_within(1e-6).of(60)
    end
  end
end
