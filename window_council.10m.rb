#!/usr/bin/env ruby
# frozen_string_literal: true

# <xbar.title>Window Council</xbar.title>
# <xbar.version>v2.1</xbar.version>
# <xbar.author>Paul Lahana</xbar.author>
# <xbar.author.github>paultursuru</xbar.author.github>
# <xbar.desc>Ouvrir ou fermer les fenêtres ? Croise humidité et température intérieures avec l'air extérieur (MétéoSuisse).</xbar.desc>
# <xbar.dependencies>ruby</xbar.dependencies>
# <xbar.var>string(VAR_TEMP_IDEAL="21"): Température idéale de la pièce, en °C</xbar.var>
# <xbar.var>string(VAR_RH_IDEAL="50"): Humidité relative idéale de la pièce, en %</xbar.var>

# xbar runs this file every 10 min (the "10m" in its name).
# Code in window_council_app/, settings in window_council_app/config/settings.rb.
# Indoor readings are entered on the page (menu > Saisir un relevé…), not here.

require_relative 'window_council_app/controller'

Controller.new(plugin_path: __FILE__).run
