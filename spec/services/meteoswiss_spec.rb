# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe MeteoSwiss do
  let(:rows) do
    CSV.parse(<<~CSV, col_sep: ';', headers: true)
      station_abbr;reference_timestamp;tre200s0;ure200s0;tde200s0
      PUY;13.10.2026 15:10;15.6;67.1;9.5
      PUY;13.10.2026 15:20;-;;
    CSV
  end

  describe '.measurements' do
    it 'returns nil for missing values ("-" or empty)' do
      expect(described_class.measurements(rows[1])).to eq(temp: nil, rh: nil, dew: nil)
    end
  end

  describe '.last_complete' do
    it 'skips an incomplete update (15:10, not 15:20)' do
      expect(described_class.last_complete(rows)['reference_timestamp']).to eq('13.10.2026 15:10')
    end
  end
end
