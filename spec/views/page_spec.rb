# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Page do
  def chart_data(html)
    JSON.parse(html[%r{<script type="application/json" id="chart-data">(.*?)</script>}m, 1])
  end

  it 'shows the verdict, both axes and the chart data' do
    history = [{ 'recorded_at' => '2026-10-14T10:50:00+02:00' }]
    html = described_class.new(build_report.merge(history: history)).render
    expect(html).to include('<h1>À vous de voir</h1>', 'Humidité relative', 'id="evolution"', 'const CHARTS')
    expect(chart_data(html)).to include(
      'history' => history,
      'targets' => { 'temperature' => [TEMP_MIN, TEMP_MAX], 'humidity' => [RH_MIN, RH_MAX] }
    )
  end

  it 'escapes the error message' do
    html = described_class.new(error: 'Station <PUY> absente', updated_at: '2026-10-14T11:00:00+02:00').render
    expect(html).to include('<h1>Pas de verdict</h1>', 'Station &lt;PUY&gt; absente')
  end
end
