# frozen_string_literal: true

# One axis verdict (:open, :close or :indifferent), with a full and a short reason.
Axis = Struct.new(:verdict, :reason, :short)
