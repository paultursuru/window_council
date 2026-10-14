#!/usr/bin/env ruby
# frozen_string_literal: true

# <xbar.title>Window Council</xbar.title>
# <xbar.version>v2.0</xbar.version>
# <xbar.author>Paul Lahana</xbar.author>
# <xbar.author.github>paultursuru</xbar.author.github>
# <xbar.desc>Ouvrir ou fermer les fenêtres ? Croise humidité et température intérieures avec l'air extérieur (MétéoSuisse).</xbar.desc>
# <xbar.dependencies>ruby</xbar.dependencies>
# <xbar.var>string(VAR_INDOOR_TEMP="21.0"): Température intérieure en °C, lue sur l'hygromètre</xbar.var>
# <xbar.var>string(VAR_INDOOR_RH="60"): Humidité relative intérieure en %, lue sur l'hygromètre</xbar.var>

# xbar runs this file every 10 min (the "10m" in its name).
# Code in window_council_app/, settings in window_council_app/config/settings.rb.

require_relative 'window_council_app/controller'

Controller.new(plugin_path: __FILE__).run
