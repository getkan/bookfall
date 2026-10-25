module Timeline
  class Refresh
    CURRENT_KEY = "timeline:v2:current"
    RETENTION = 24.hours

    def self.key(revision)
      "timeline:v2:revision:#{revision}"
    end

    def self.read(revision)
      snapshot = Rails.cache.read(key(revision))
      snapshot if snapshot && Time.current.to_f < snapshot.fetch("published_at") + RETENTION
    end

    def self.call(cache: Rails.cache)
      rows = BookEvent.with_book_details.to_a
      rows.sort_by! do |event|
        [ event.date, event.type == "FINISH" ? 0 : 1, event.start_rank, event.book_id, event.id ]
      end
      events = rows.map(&:timeline_payload)
      revision = SecureRandom.uuid
      snapshot = {
        "revision" => revision, "published_at" => Time.current.to_f,
        "bounds" => { "first_date" => events.first&.fetch("date")&.slice(0, 10),
                      "last_date" => events.last&.fetch("date")&.slice(0, 10) },
        "events" => events
      }
      # Publish the pointer last so a failed build/write leaves the old revision usable.
      raise "Timeline revision cache write failed" unless cache.write(key(revision), snapshot, expires_in: RETENTION)
      raise "Timeline current revision publication failed" unless cache.write(CURRENT_KEY, revision, expires_in: RETENTION)

      snapshot
    end
  end
end
