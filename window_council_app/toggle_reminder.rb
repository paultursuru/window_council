# frozen_string_literal: true

# Menu > Rappel pour fermer: turns the reminder on or off. xbar then refreshes the plugin
# (refresh=true), which sets or deletes it.
require_relative 'services/close_reminder'

CloseReminder.toggle
