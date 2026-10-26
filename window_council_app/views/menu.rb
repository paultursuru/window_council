# frozen_string_literal: true

require_relative '../config/settings'
require_relative '../helpers/application_helper'

# xbar output: verdict icon in the menu bar, details in the dropdown.
class Menu
  include ApplicationHelper

  # reminder: CloseReminder state, for its on/off item
  def initialize(report, save_error = nil, reminder = nil)
    @report = report
    @save_error = save_error
    @reminder = reminder
    @verdict = VERDICTS[report[:verdict]]
  end

  def lines
    body = @verdict ? [*header, '---', *axes, *airing, '---', *outdoor, '---', *indoor] : error
    body + ['---', *page_links, *reminder, "MétéoSuisse — #{FORECAST_NAME} | href=#{FORECAST_URL}",
            'Rafraîchir | refresh=true']
  end

  private

  def header
    ["#{@verdict[:icon]}#{countdown}", '---', "#{@verdict[:label]} : #{@report[:reason]}"]
  end

  # While airing: when to close, then ⏰ once it is time
  def countdown
    open = (@report[:airing] || {})[:open]
    return '' unless open && open[:close_at]

    open[:due] ? ' ⏰' : " #{local_time(open[:close_at])}"
  end

  def axes
    temp = @report[:indoor][:temperature]
    humidity = @report[:axes][:humidity]
    temperature = @report[:axes][:temperature]
    ["Humidité #{fmt(@report[:indoor][:humidity])} % · idéal #{format('%g', humidity[:ideal])} % → " \
     "#{verdict_name(humidity[:verdict])} : #{humidity[:reason]}",
     "Température #{fmt(temp)} °C · idéal #{format('%g', temperature[:ideal])} °C → " \
     "#{verdict_name(temperature[:verdict])} : #{temperature[:reason]}",
     "HR projetée de l'air extérieur à #{fmt(temp)} °C : #{fmt(@report[:projected_rh])} %"]
  end

  # Airing in progress, or how long to air
  def airing
    plan = @report[:airing] || {}
    if (open = plan[:open])
      ["#{WINDOWS[open[:windows]]} depuis #{time_label(open[:since])} · " \
       "HR estimée #{fmt(open[:estimated_rh])} %#{close_hint(open)}"]
    elsif (durations = plan[:durations])
      ["Aérer jusqu'à #{fmt(plan[:target_rh])} % : 1 fenêtre ~#{duration_label(durations['one'])} · " \
       "courant d'air ~#{duration_label(durations['cross'])}"]
    else
      []
    end
  end

  def close_hint(open)
    return '' unless open[:close_at]

    open[:due] ? ' · cible atteinte : fermer' : " · fermer vers #{local_time(open[:close_at])}"
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
    settings = @report[:settings]
    ["Intérieur : #{fmt(indoor[:temperature])} °C · #{fmt(indoor[:humidity])} % " \
     "(relevé de #{time_label(indoor[:entered_at])})",
     "Idéaux #{format('%g', settings[:temp_ideal])} °C et #{format('%g', settings[:rh_ideal])} % : " \
     'Open Plugin… (⌘E) pour les changer | color=gray']
  end

  # "|" would start xbar options
  def error
    ['🪟?', '---', *@report[:error].each_line.map { |l| l.chomp.tr('|', '/') }]
  end

  # The form needs the local server; with ⌥, the page file alone
  def page_links
    return ["⚠️ #{@save_error.tr('|', '/')}"] if @save_error

    ["Saisir un relevé, voir le détail… | shell=#{RbConfig.ruby} param1=\"#{SERVER_FILE}\" terminal=false",
     "Voir le détail, sans formulaire… | href=\"#{HTML_FILE}\" alternate=true"]
  end

  # A click turns it on or off; the refresh that follows sets or deletes the reminder
  def reminder
    return [] unless @reminder

    at = @reminder['at']
    label = if !@reminder['enabled'] then '🔕 Rappel pour fermer : désactivé'
            elsif !at then '🔔 Rappel pour fermer : activé'
            elsif time_at(at) > Time.now then "🔔 Rappel pour fermer : activé, sonne à #{local_time(at)}"
            else "🔔 Rappel pour fermer : activé, a sonné à #{local_time(at)}"
            end
    ["#{label} | shell=#{RbConfig.ruby} param1=\"#{TOGGLE_FILE}\" terminal=false refresh=true",
     *(@reminder['error'] && "⚠️ #{@reminder['error'].tr('|', '/')}")]
  end
end
