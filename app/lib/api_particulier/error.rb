module APIParticulier
  module Error
    class HttpError < ::StandardError
      def initialize(response)
        @connect_time = response.connect_time
        @curl_message = response.return_message
        @http_error_code = response.code
        @datetime = response.headers.fetch('Date', DateTime.current.inspect)
        @total_time = response.total_time

        uri = URI.parse(response.effective_url)
        @url = "#{uri.host}#{uri.path}"

        data = JSON.parse(response.body, symbolize_names: true)
        @error = APIParticulier::Entities::Error.new(**data)

        msg = <<~TEXT
          url: #{url}
          HTTP error code: #{http_error_code}
          #{error}
          curl message: #{curl_message}
          total time: #{total_time}
          connect time: #{connect_time}
          datetime: #{datetime}
        TEXT

        super(msg)
      end

      def as_yaml
        self.dup.tap { |e| e.set_backtrace([]) }
      end

      def to_yaml(options = {})
        Psych.dump(as_yaml, options)
      end

      attr_reader :connect_time, :curl_message, :http_error_code, :datetime, :total_time, :url, :error
    end

    class TimedOut < HttpError; end

    class Unauthorized < HttpError; end

    class NotFound < HttpError; end

    class RequestFailed < HttpError; end

    class ServiceUnavailable < HttpError; end

    class BadGateway < HttpError; end

    class BadFormatRequest < HttpError; end
  end
end
