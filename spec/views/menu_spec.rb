# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Menu do
  it 'shows the verdict icon in the menu bar, then its reason' do
    expect(described_class.new(build_report).lines.first(3)).to eq(
      ['🪟⚠️', '---', 'Conflit : air sec mais trop froid dehors']
    )
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
    expect(lines.grep(/Voir le détail/)).to be_empty
  end
end
