module Timeline
  class Refresh
    CURRENT_KEY = "timeline:v1:current"
    RETENTION = 24.hours

    def self.key(revision)
      "timeline:v1:revision:#{revision}"
    end

    def self.read(revision)
      snapshot = Rails.cache.read(key(revision))
      snapshot if snapshot && Time.current.to_f < snapshot.fetch("published_at") + RETENTION
    end

    def self.call
      rows = BookEvent.joins(:book).pluck(
        "book_events.id", "book_events.book_id", "book_events.type",
        "book_events.date", "book_events.start_rank",
        "books.user_id", "books.title", "books.author", "books.rating"
      )
      rows.sort_by! { |id, book_id, type, date, rank, *| [ date, type == "FINISH" ? 0 : 1, rank, book_id, id ] }
      events = rows.map do |id, book_id, type, date, rank, user_id, title, author, rating|
        {
          "id" => id, "book_id" => book_id, "type" => type,
          "date" => date.utc.iso8601(date.usec.zero? ? 0 : 6), "start_rank" => rank,
          "user_id" => user_id, "title" => title, "author" => author, "rating" => rating
        }
      end
      revision = SecureRandom.uuid
      snapshot = {
        "revision" => revision, "published_at" => Time.current.to_f,
        "bounds" => { "first_date" => events.first&.fetch("date")&.slice(0, 10),
                      "last_date" => events.last&.fetch("date")&.slice(0, 10) },
        "events" => events
      }
      # Publish the pointer last so a failed build/write leaves the old revision usable.
      raise "Timeline revision cache write failed" unless Rails.cache.write(key(revision), snapshot, expires_in: RETENTION)
      raise "Timeline current revision publication failed" unless Rails.cache.write(CURRENT_KEY, revision, expires_in: RETENTION)

      snapshot
    end
  end
end
