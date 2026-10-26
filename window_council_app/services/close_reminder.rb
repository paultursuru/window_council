# frozen_string_literal: true

require 'json'
require 'timeout'
require_relative '../config/settings'
require_relative '../helpers/application_helper'
require_relative 'storage'

# Reminder to close the windows, in the Reminders app: macOS rings it at closing time, on the Mac and
# on the iPhone or watch sharing those reminders, with no process left waiting. One per airing reading,
# at the closing time computed then (later outdoor measurements only move the time in the menu);
# the next reading replaces or deletes it. reminder.json keeps it, and whether it is on.
module CloseReminder
  extend ApplicationHelper

  module_function

  # Reminders unreachable or refusing access: shown in the menu, retried at the next run
  class Failed < StandardError; end

  TITLE = 'Fermer les fenêtres'
  # list, title, notes, seconds from now → id of the new reminder.
  # Reminders is quit again if it was not running.
  CREATE = <<~APPLESCRIPT
    on run {listName, reminderName, reminderNotes, waitSeconds}
      set remindAt to (current date) + (waitSeconds as integer)
      set wasRunning to application "Reminders" is running
      tell application "Reminders"
        if not (exists list listName) then make new list with properties {name:listName}
        set props to {name:reminderName, body:reminderNotes, due date:remindAt, remind me date:remindAt}
        tell list listName to set newReminder to make new reminder at end with properties props
        set reminderId to id of newReminder
      end tell
      if not wasRunning then tell application "Reminders" to quit
      return reminderId
    end run
  APPLESCRIPT
  # id → deleted; one already deleted in Reminders (-1728) is fine
  DELETE = <<~APPLESCRIPT
    on run {reminderId}
      set wasRunning to application "Reminders" is running
      tell application "Reminders"
        try
          delete reminder id reminderId
        on error errText number errNum
          if errNum is not -1728 then error errText number errNum
        end try
      end tell
      if not wasRunning then tell application "Reminders" to quit
    end run
  APPLESCRIPT

  # Menu > Rappel pour fermer; the plugin run that follows sets or deletes the reminder
  def toggle
    Storage.locked do
      state = read
      write(state.merge('enabled' => !state['enabled']))
    end
  end

  # Sets, replaces or deletes the reminder after the report's airing.
  # Returns the state: 'enabled', and 'at' while a reminder is set; 'error' if Reminders failed.
  def sync(report, now = Time.now)
    Storage.locked do
      state = read
      # Without outdoor data the airing is unknown: the reminder stays
      return state if report[:error] && state['enabled']

      open = airing(report) if state['enabled']
      key = open && airing_key(open, report[:indoor])
      return state if key == state['airing']

      delete(state['id']) if state['id']
      state = { 'enabled' => state['enabled'], 'airing' => key }.compact
      # A reading entered after its closing time: the menu already says to close
      state.merge!(create(open, now)) if key && time_at(open[:close_at]) > now
      write(state)
      state
    end
  rescue Failed => e
    read.merge('error' => "Rappel pour fermer impossible : #{e.message}")
  end

  def read
    state = File.exist?(REMINDER_FILE) ? JSON.parse(File.read(REMINDER_FILE, encoding: 'UTF-8')) : {}
    { 'enabled' => true }.merge(state)
  rescue JSON::ParserError
    { 'enabled' => true }
  end

  def write(state)
    Storage.write_atomically(REMINDER_FILE, JSON.pretty_generate(state))
  end

  # Airing in progress with a closing time
  def airing(report)
    open = (report[:airing] || {})[:open]
    open if open && open[:close_at]
  end

  # The reading the airing started from: correcting it (same time, other values) sets a new reminder
  def airing_key(open, indoor)
    [open[:since], open[:windows], indoor[:temperature], indoor[:humidity]].join(' ')
  end

  def create(open, now)
    notes = "#{ApplicationHelper::WINDOWS[open[:windows]]} depuis #{time_label(open[:since])}. " \
            "Saisis un relevé en fermant : il sert à mesurer l'aération."
    wait = (time_at(open[:close_at]) - now).round
    { 'id' => osascript(CREATE, REMINDER_LIST, TITLE, notes, wait.to_s), 'at' => open[:close_at] }
  end

  def delete(reminder_id)
    osascript(DELETE, reminder_id)
  end

  # Output of an AppleScript run with these arguments, or Failed with its error
  def osascript(script, *args)
    output = IO.popen(['osascript', '-e', script, *args], err: %i[child out]) do |io|
      Timeout.timeout(REMINDER_TIMEOUT) { io.read }
    rescue Timeout::Error
      Process.kill('KILL', io.pid)
      raise Failed, "Rappels ne répond pas (#{REMINDER_TIMEOUT} s)"
    end
    raise Failed, failure(output) unless Process.last_status.success?

    output.strip
  rescue SystemCallError => e
    raise Failed, e.message
  end

  # "0:42: execution error: Not authorized to send Apple events to Reminders. (-1743)" → what to do
  def failure(output)
    if output.match?(/\(-174[34]\)/)
      return "autorise l'accès à Rappels (Réglages Système > Confidentialité et sécurité > Automatisation)"
    end

    output.strip.sub(/\A\d+:\d+: (execution error: )?/, '')
  end
end
