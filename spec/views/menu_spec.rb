# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Menu do
  it 'shows the verdict icon in the menu bar, then its reason' do
    expect(described_class.new(build_report).lines.first(3)).to eq(
      ['🪟⚠️', '---', 'Conflit : air sec mais trop froid dehors']
    )
  end

  it 'says how long to air when humidity says open' do
    report = build_report(indoor_temp: 21.0, indoor_rh: 46.0, vars: { 'VAR_RH_IDEAL' => '42' })
    lines = described_class.new(report).lines
    expect(lines).to include("Aérer jusqu'à 42.0 % : 1 fenêtre ~17 min · courant d'air ~4 min")
  end

  it 'shows when to close while airing, also in the menu bar' do
    opened = reading(21.0, 46.0, time: ApplicationHelper.iso(Time.now - 600), windows: 'one')
    lines = described_class.new(build_report(readings: [opened], vars: { 'VAR_RH_IDEAL' => '42' })).lines
    expect(lines.first).to match(/\A🪟✅ \d\d:\d\d\z/)
    expect(lines.grep(/\A1 fenêtre depuis \d\d:\d\d · HR estimée [\d.]+ % · fermer vers \d\d:\d\d\z/).size).to eq(1)
  end

  it 'flags an incomplete MeteoSwiss update' do
    measurement = ReportHelpers::MEASUREMENT.merge(incomplete: Time.new(2026, 10, 14, 11, 0))
    expect(described_class.new(build_report(measurement: measurement)).lines).to include(
      '⚠️ Mise à jour MétéoSuisse de 11:00 incomplète : dernière mesure complète utilisée'
    )
  end

  it 'shows errors without "|", which xbar would read as options' do
    report = { error: "Colonne(s) absente(s) : a|b\nEn-têtes trouvés :" }
    expect(described_class.new(report).lines.first(4)).to eq(
      ['🪟?', '---', 'Colonne(s) absente(s) : a/b', 'En-têtes trouvés :']
    )
  end

  it 'replaces the page link with the write error' do
    lines = described_class.new(build_report, 'Écriture impossible : disque plein').lines
    expect(lines).to include('⚠️ Écriture impossible : disque plein')
    expect(lines.grep(/Saisir un relevé|Voir le détail/)).to be_empty
  end
end
