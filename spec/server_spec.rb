# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../window_council_app/server'

RSpec.describe Server do
  subject(:server) { described_class.new(plugin_path: File.join(DATA_DIR, 'window_council.10m.rb')) }

  let(:host) { { 'host' => "127.0.0.1:#{SERVER_PORT}" } }
  let(:form) { 'temperature=21%2C5&humidity=46&time=&windows=one' }

  before do
    allow(MeteoSwiss).to receive(:current).and_return(ReportHelpers::MEASUREMENT)
    allow(server).to receive(:refresh_xbar)
  end

  it 'serves the page with its form, building it on the first request' do
    Readings.write([reading(21.0, 46.0)])
    status, headers, body = server.handle('GET', '/', host, '')
    expect([status, headers['Content-Type']]).to eq([200, 'text/html; charset=utf-8'])
    expect(body).to include('id="reading-form"')
  end

  it 'refuses another host name (DNS rebinding)' do
    expect(server.handle('GET', '/', { 'host' => "evil.example:#{SERVER_PORT}" }, '').first).to eq(403)
  end

  it 'refuses a form posted from another site' do
    expect(server.handle('POST', '/readings', host.merge('origin' => 'https://evil.example'), form).first).to eq(403)
    expect(Readings.read).to be_empty
  end

  it 'saves a reading, rebuilds the report and refreshes xbar, then goes back to the page' do
    origin = { 'origin' => "http://127.0.0.1:#{SERVER_PORT}" }
    status, headers, = server.handle('POST', '/readings', host.merge(origin), form)
    expect([status, headers['Location']]).to match([303, start_with('/?ok=')])
    expect(Readings.read.last).to include('temperature' => 21.5, 'humidity' => 46.0, 'windows' => 'one')
    expect(JSON.parse(File.read(JSON_FILE))['indoor']).to include('humidity' => 46.0)
    expect(server).to have_received(:refresh_xbar)
  end

  it 'sends an invalid reading back to the form, with its values' do
    status, headers, = server.handle('POST', '/readings', host, 'temperature=21&humidity=146&time=&windows=closed')
    expect(status).to eq(303)
    expect(URI.decode_www_form(headers['Location'][2..]).to_h).to include(
      'erreur' => 'Humidité entre 0 et 100 % (« 146.0 »)', 'humidity' => '146'
    )
  end
end
