class BookEventSync
  def self.call(random: Random)
    new(random: random).call
  end

  def initialize(random:)
    @random = random
  end

  def call
    checkpoint = TaskCheckpoint.find_or_create_by!(name: "book_events_sync")
    bound = Time.current
    checkpoint.update!(status: "running", last_started_at: bound,
      last_finished_at: nil, books_processed: 0, last_error: nil)

    begin
      BookEvent.transaction do
        books = Book.where("updated_at <= ?", bound)
        books = books.where("updated_at >= ?", checkpoint.processed_through) if checkpoint.processed_through
        processed = 0
        books.order(:updated_at, :id).each do |book|
          reconcile(book)
          processed += 1
        end
        checkpoint.update!(status: "succeeded", processed_through: bound,
          last_finished_at: Time.current, last_succeeded_at: Time.current,
          books_processed: processed)
      end
    rescue StandardError => error
      # Store the class only: exception messages can contain SQL and book data.
      checkpoint.reload.update!(status: "failed", last_finished_at: Time.current,
        books_processed: 0, last_error: error.class.name)
      Rails.logger.error("Book event synchronization failed (#{error.class.name})")
      raise
    end
    checkpoint
  end

  private
    def reconcile(book)
      events = book.book_events.index_by(&:type)
      rank = events["START"]&.start_rank || events["FINISH"]&.start_rank || choose_rank(book)
      { "START" => book.started_at, "FINISH" => book.finished_at }.each do |type, date|
        event = events[type]
        if date
          event ||= book.book_events.build(type: type)
          event.assign_attributes(date: date, start_rank: rank)
          event.save! if event.new_record? || event.changed?
        else
          event&.destroy!
        end
      end
    end

    def choose_rank(book)
      usage = (1..12).index_with { 0 }
      { "START" => book.started_at, "FINISH" => book.finished_at }.each do |type, date|
        next unless date

        day = date.utc.beginning_of_day
        BookEvent.where(type: type, date: day...(day + 1.day)).group(:start_rank).count.each do |rank, count|
          usage[rank] += count
        end
      end
      least_used = usage.values.min
      usage.select { |_rank, count| count == least_used }.keys.sample(random: @random)
    end
end
