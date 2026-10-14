# frozen_string_literal: true

require 'erb'
require 'json'
require_relative '../config/settings'
require_relative '../helpers/application_helper'

# report.html: verdict, gauges, evolution charts and measurements.
# CSS and JS are inlined so the page works on its own.
class Page
  include ERB::Util
  include ApplicationHelper

  def initialize(report)
    @report = report
    @verdict = VERDICTS[report[:verdict]]
  end

  def render
    ERB.new(read('templates/report.html.erb'), trim_mode: '-').result(binding)
  end

  private

  attr_reader :report, :verdict

  def outdoor
    report[:outdoor]
  end

  def indoor
    report[:indoor]
  end

  def humidity
    report[:axes][:humidity]
  end

  def temperature
    report[:axes][:temperature]
  end

  # Evolution section skeleton, filled by evolution.js
  def evolution
    read('templates/_evolution.html')
  end

  def styles
    read('assets/report.css')
  end

  def script
    read('assets/evolution.js')
  end

  # Data for evolution.js (#chart-data)
  def chart_data
    data = { updated_at: report[:updated_at], history: report[:history] || [],
             targets: { temperature: [TEMP_MIN, TEMP_MAX], humidity: [RH_MIN, RH_MAX] } }
    JSON.generate(data).gsub('</', '<\/')
  end

  # Target zone in green, outdoor value above, indoor value below
  def gauge(target:, inside:, outside:, unit:, outside_label:, pad:)
    lo = [target[0], inside, outside].min - pad
    hi = [target[1], inside, outside].max + pad
    pos = ->(x) { ((x - lo) / (hi - lo) * 100).round(1) }
    mark = lambda do |cls, x, label|
      pct = pos.call(x)
      edge = if pct < 25 then ' left'
             elsif pct > 75 then ' right'
             else ''
             end
      %(<div class="mark #{cls}#{edge}" style="left:#{pct}%"><span>#{label} <b>#{fmt(x)} #{unit}</b></span></div>)
    end
    zone = "left:#{pos.call(target[0])}%;width:#{(pos.call(target[1]) - pos.call(target[0])).round(1)}%"
    <<~HTML
      <div class="scale">
        <div class="track"><div class="zone" style="#{zone}"></div></div>
        #{mark.call('outdoor', outside, outside_label)}
        #{mark.call('indoor', inside, 'Dedans')}
      </div>
    HTML
  end

  # Explicit UTF-8: xbar runs the plugin without a locale
  def read(path)
    File.read(File.join(__dir__, path), encoding: 'UTF-8')
  end
end
