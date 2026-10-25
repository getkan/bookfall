module Timeline
  class Page
    def self.call(cursor: nil, before: nil, after: nil)
      new.call(cursor: cursor, before: before, after: after)
    end

    def call(cursor:, before:, after:)
      supplied = [ cursor, before, after ].compact
      if supplied.size > 1 || supplied.any? { |value| !value.is_a?(String) || value.blank? }
        raise Error.new("invalid_parameters", "Supply only one nonempty cursor, before or after", :bad_request)
      end

      if cursor
        payload = decode_cursor(cursor)
        snapshot = Refresh.read(payload.fetch("revision"))
        raise Error.new("revision_expired", "Timeline revision is unavailable; restart with an initial request", :gone) unless snapshot

        direction = payload.fetch("direction")
        anchor = Date.iso8601(payload.fetch("boundary"))
      else
        anchor = parse_timestamp(before || after) if before || after
        direction = before ? "backward" : "forward"
        current = Rails.cache.read(Refresh::CURRENT_KEY)
        snapshot = (Refresh.read(current) if current) || Refresh.call
      end
      build_page(snapshot, direction, anchor)
    end

    private
      def verifier
        Rails.application.message_verifier("timeline-cursor-v1")
      end

      def decode_cursor(cursor)
        payload = verifier.verified(cursor, purpose: "timeline-page")
        valid = payload.is_a?(Hash) && payload["version"] == 1 &&
          payload["revision"].is_a?(String) &&
          %w[forward backward].include?(payload["direction"]) &&
          payload["boundary"].is_a?(String)
        raise ArgumentError unless valid

        Date.iso8601(payload.fetch("boundary"))
        payload
      rescue ArgumentError, Date::Error
        raise Error.new("invalid_cursor", "Invalid timeline cursor", :bad_request)
      end

      def parse_timestamp(value)
        raise ArgumentError unless value.match?(/\A\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)\z/)

        Date.iso8601(value[0, 10])
        Time.iso8601(value).utc.to_date
      rescue ArgumentError
        raise Error.new("invalid_timestamp", "Use a valid full ISO 8601 timestamp with timezone", :bad_request)
      end

      def build_page(snapshot, direction, anchor)
        bounds = snapshot.fetch("bounds")
        result = { revision: snapshot.fetch("revision"), bounds: bounds, span: nil, events: [], next_cursor: nil }
        return result unless bounds.fetch("first_date")

        first = Date.iso8601(bounds.fetch("first_date"))
        last = Date.iso8601(bounds.fetch("last_date"))
        anchor ||= first
        if direction == "forward"
          from = [ anchor, first ].max
          return result if from > last

          through = [ from + 29, last ].min
          boundary = through + 1 if through < last
        else
          through = [ anchor, last ].min
          return result if through < first

          from = [ through - 29, first ].max
          boundary = from - 1 if from > first
        end
        result[:span] = { from: from.iso8601, through: through.iso8601 }
        result[:events] = snapshot.fetch("events").select do |event|
          day = event.fetch("date")[0, 10]
          day >= from.iso8601 && day <= through.iso8601
        end
        if boundary
          result[:next_cursor] = verifier.generate(
            { "version" => 1, "revision" => snapshot.fetch("revision"),
              "direction" => direction, "boundary" => boundary.iso8601 },
            purpose: "timeline-page"
          )
        end
        result
      end
  end
end
