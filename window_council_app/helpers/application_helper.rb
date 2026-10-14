# frozen_string_literal: true

require 'date'

# Verdict labels and number/date formatting, shared by Council, Menu and Page.
module ApplicationHelper
  module_function

  VERDICTS = {
    open: { icon: '🪟✅', label: 'Ouvrir', title: 'Ouvrez les fenêtres' },
    close: { icon: '🪟❌', label: 'Fermer', title: 'Fermez les fenêtres' },
    indifferent: { icon: '🪟➖', label: 'Indifférent', title: 'Peu importe' },
    conflict: { icon: '🪟⚠️', label: 'Conflit', title: 'À vous de voir' }
  }.freeze

  def fmt(x)
    format('%.1f', x)
  end

  def iso(time)
    time.strftime('%FT%T%:z')
  end

  # "14:03", or "12.10 14:03" if not today
  def time_label(iso_time)
    t = DateTime.iso8601(iso_time).to_time
    t.to_date == Date.today ? t.strftime('%H:%M') : t.strftime('%d.%m %H:%M')
  end

  def local_time(iso_time, pattern = '%H:%M')
    DateTime.iso8601(iso_time).strftime(pattern)
  end

  def range_label(target, unit)
    format('%<min>g–%<max>g %<unit>s', min: target[0], max: target[1], unit: unit)
  end

  def verdict_name(verdict)
    VERDICTS[verdict][:label].downcase
  end
end
