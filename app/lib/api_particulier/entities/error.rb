# frozen_string_literal: true

module APIParticulier
  module Entities
    class Error
      def initialize(**kwargs)
        attrs = kwargs.symbolize_keys
        @reason = attrs[:reason]
        @message = attrs[:messages]
        @error = attrs[:error]
      end

      attr_reader :reason, :message, :error

      def to_s
        <<~TEXT.strip
          reason: #{reason}
          message: #{message}
          error: #{error}
        TEXT
      end
    end
  end
end
