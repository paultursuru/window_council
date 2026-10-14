# frozen_string_literal: true

# Final verdict (:open, :close, :indifferent or :conflict), its reason and both axes.
Decision = Struct.new(:verdict, :reason, :humidity, :temperature)
