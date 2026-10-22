# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Page do
  def chart_data(html)
    JSON.parse(html[%r{<script type="application/json" id="chart-data">(.*?)</script>}m, 1])
  end

  it 'shows the verdict, the form, both axes, airing and the chart data' do
    history = [{ 'recorded_at' => '2026-10-14T10:50:00+02:00' }]
    html = described_class.new(build_report.merge(history: history)).render
    expect(html).to include('<h1>À vous de voir</h1>', 'id="reading-form"', 'Humidité relative', '<h2>Aération</h2>',
                            'id="evolution"', 'const CHARTS')
    expect(chart_data(html)).to include(
      'history' => history,
      'readings' => [reading(18.0, 68.0)],
      'targets' => { 'temperature' => [TEMP_MIN, TEMP_MAX], 'humidity' => [RH_MIN, RH_MAX] },
      'ideals' => { 'temperature' => TEMP_IDEAL, 'humidity' => RH_IDEAL }
    )
  end

  it 'keeps the window setting of the latest reading in the form' do
    html = described_class.new(build_report(readings: [reading(21.0, 46.0, windows: 'cross')])).render
    expect(html).to include('<input type="radio" name="windows" value="cross" checked>')
  end

  it 'escapes the error message, and still offers the form' do
    html = described_class.new(error: 'Station <PUY> absente', updated_at: '2026-10-14T11:00:00+02:00').render
    expect(html).to include('<h1>Pas de verdict</h1>', 'Station &lt;PUY&gt; absente', 'id="reading-form"')
  end
end
