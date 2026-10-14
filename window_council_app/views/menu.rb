# frozen_string_literal: true

require_relative '../config/settings'
require_relative '../helpers/application_helper'

# xbar output: verdict icon in the menu bar, details in the dropdown.
class Menu
  include ApplicationHelper

  def initialize(report, save_error = nil)
    @report = report
    @save_error = save_error
    @verdict = VERDICTS[report[:verdict]]
  end

  def lines
    body = @verdict ? [*header, '---', *axes, '---', *outdoor, '---', *indoor] : error
    body + ['---', page_link, "MétéoSuisse — #{FORECAST_NAME} | href=#{FORECAST_URL}", 'Rafraîchir | refresh=true']
  end

  private

  def header
    [@verdict[:icon], '---', "#{@verdict[:label]} : #{@report[:reason]}"]
  end

  def axes
    temp = @report[:indoor][:temperature]
    humidity = @report[:axes][:humidity]
    temperature = @report[:axes][:temperature]
    ["Humidité #{fmt(@report[:indoor][:humidity])} % · cible #{range_label(humidity[:target], '%')} → " \
     "#{verdict_name(humidity[:verdict])} : #{humidity[:reason]}",
     "Température #{fmt(temp)} °C · cible #{range_label(temperature[:target], '°C')} → " \
     "#{verdict_name(temperature[:verdict])} : #{temperature[:reason]}",
     "HR projetée de l'air extérieur à #{fmt(temp)} °C : #{fmt(@report[:projected_rh])} %"]
  end

  def outdoor
    outdoor = @report[:outdoor]
    rows = ["Extérieur — #{@report[:station]}, mesure de #{local_time(outdoor[:measured_at])}"]
    if outdoor[:incomplete_update_at]
      rows << "⚠️ Mise à jour MétéoSuisse de #{local_time(outdoor[:incomplete_update_at])} incomplète : " \
              'dernière mesure complète utilisée'
    end
    rows + ["Température : #{fmt(outdoor[:temperature])} °C",
            "Humidité relative : #{fmt(outdoor[:humidity])} %",
            "Point de rosée : #{fmt(outdoor[:dew_point])} °C"]
  end

  def indoor
    indoor = @report[:indoor]
    ["INDOOR_TEMP = #{fmt(indoor[:temperature])} °C · INDOOR_RH = #{fmt(indoor[:humidity])} % " \
     "(saisis à #{time_label(indoor[:entered_at])})",
     'Modifier : Open Plugin… (⌘E) | color=gray']
  end

  # "|" would start xbar options
  def error
    ['🪟?', '---', *@report[:error].each_line.map { |l| l.chomp.tr('|', '/') }]
  end

  def page_link
    @save_error ? "⚠️ #{@save_error.tr('|', '/')}" : "Voir le détail… | href=\"#{HTML_FILE}\""
  end
end
