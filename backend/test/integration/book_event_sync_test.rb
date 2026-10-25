require "test_helper"

class BookEventSyncTest < ActiveSupport::TestCase
  setup do
    BookEvent.delete_all
    Book.delete_all
  end

  test "randomly fills all twelve ranks before reusing the least used" do
    25.times { |index| create_book(index) }
    BookEventSync.call(random: Random.new(123))
    ranks = BookEvent.order(:book_id).pluck(:start_rank)
    assert_equal (1..12).to_a, ranks.first(12).sort
    assert_equal (1..12).to_a, ranks.slice(12, 12).sort
    assert_not_equal (1..12).to_a, ranks.first(12)
    assert_equal [ 2, 3 ], ranks.tally.values.uniq.sort
    before = BookEvent.order(:id).map(&:attributes)
    BookEventSync.call(random: Random.new(456))
    assert_equal before, BookEvent.order(:id).map(&:attributes)
  end

  test "new pairs avoid ranks occupied on either relevant day and type" do
    10.times do |index|
      owner = create_book(index)
      BookEvent.create!(book: owner, type: "START", date: start_date, start_rank: index + 1)
    end
    owner = create_book("finish-owner")
    BookEvent.create!(book: owner, type: "FINISH", date: finish_date, start_rank: 12)
    target = create_book("target", finished_at: finish_date)
    checkpoint_for_target(target)
    BookEventSync.call
    assert_equal [ 11, 11 ], target.book_events.order(:type).pluck(:start_rank)
  end

  test "overflow minimizes combined usage across both day and type groups" do
    12.times do |index|
      owner = create_book(index)
      BookEvent.create!(book: owner, type: "START", date: start_date, start_rank: index + 1)
      next if index == 6

      BookEvent.create!(book: owner, type: "FINISH", date: finish_date, start_rank: index + 1)
    end
    target = create_book("target", finished_at: finish_date)
    checkpoint_for_target(target)
    BookEventSync.call
    assert_equal [ 7, 7 ], target.book_events.order(:type).pluck(:start_rank)
  end

  test "rank selection ignores opposite types and adjacent UTC days" do
    12.times do |index|
      owner = create_book(index)
      BookEvent.create!(book: owner, type: "FINISH", date: start_date, start_rank: index + 1)
      BookEvent.create!(book: owner, type: "START", date: start_date.utc.beginning_of_day + 1.day, start_rank: index + 1)
    end
    target = create_book("target")
    checkpoint_for_target(target)
    random = Random.new(9)
    assert_equal (1..12).to_a.sample(random: Random.new(9)), begin
      BookEventSync.call(random: random)
      target.book_events.find_by!(type: "START").start_rank
    end
  end

  test "adding completion preserves existing start rank even with a finish collision" do
    book = create_book("target")
    BookEvent.create!(book: book, type: "START", date: start_date, start_rank: 8)
    other = create_book("other", finished_at: finish_date)
    BookEvent.create!(book: other, type: "FINISH", date: finish_date, start_rank: 8)
    book.update!(finished_at: finish_date)
    checkpoint_for_target(book)
    BookEventSync.call
    assert_equal [ 8, 8 ], book.book_events.order(:type).pluck(:start_rank)
  end

  test "rank occupancy includes the entire UTC day for offset timestamps" do
    11.times do |index|
      owner = create_book(index)
      BookEvent.create!(book: owner, type: "START",
        date: Time.utc(2026, 1, 4, index.even? ? 0 : 23, 59), start_rank: index + 1)
    end
    target = create_book("offset")
    target.update!(started_at: "2026-01-05T01:00:00+02:00")
    checkpoint_for_target(target)
    BookEventSync.call
    assert_equal 12, target.book_events.find_by!(type: "START").start_rank
  end

  test "finish-only recovery reuses its rank and repairs a mismatched pair from start" do
    book = create_book("target", finished_at: finish_date)
    finish = BookEvent.create!(book: book, type: "FINISH", date: finish_date, start_rank: 4)
    BookEventSync.call
    start = book.book_events.find_by!(type: "START")
    assert_equal 4, start.start_rank
    finish.update!(start_rank: 9)
    book.touch
    BookEventSync.call
    assert_equal 4, finish.reload.start_rank
  end

  test "captured bound excludes later writes and no-op runs advance monitoring" do
    now = Time.utc(2026, 7, 1)
    book = create_book("future")
    book.update_columns(updated_at: now + 1.second)
    travel_to now do
      checkpoint = BookEventSync.call
      assert_equal now, checkpoint.processed_through
      assert_equal 0, checkpoint.books_processed
      assert_equal "succeeded", checkpoint.status
      assert_empty book.book_events
    end
    travel_to now + 2.seconds do
      checkpoint = BookEventSync.call
      assert_equal 1, checkpoint.books_processed
      assert_equal 1, book.book_events.count
    end
  end

  test "failed first run rolls back new events and records sanitized failure for retry" do
    create_book("first")
    create_book("second")
    inserts = 0
    fault = lambda do |*args|
      if args.last.fetch(:sql).match?(/\A\s*INSERT INTO\s+["`]book_events["`]/i)
        inserts += 1
        raise ActiveRecord::StatementInvalid, "sensitive book data" if inserts == 2
      end
    end
    assert_raises ActiveRecord::StatementInvalid do
      ActiveSupport::Notifications.subscribed(fault, "sql.active_record") { BookEventSync.call }
    end
    assert_equal 0, BookEvent.count
    checkpoint = TaskCheckpoint.find_by!(name: "book_events_sync")
    assert_equal "failed", checkpoint.status
    assert_nil checkpoint.processed_through
    assert_nil checkpoint.last_succeeded_at
    assert_equal 0, checkpoint.books_processed
    assert_equal "ActiveRecord::StatementInvalid", checkpoint.last_error
    assert checkpoint.last_finished_at
    assert_equal "succeeded", BookEventSync.call.status
    assert_equal 2, BookEvent.count
  end

  private
    def start_date
      Time.utc(2026, 1, 4, 12)
    end

    def finish_date
      Time.utc(2026, 2, 4, 12)
    end

    def create_book(index, finished_at: nil)
      Book.create!(title: "Sync book #{index}", author: "Test Author",
        started_at: start_date, finished_at: finished_at)
    end

    def checkpoint_for_target(book)
      watermark = Time.current - 1.minute
      Book.where.not(id: book.id).update_all(updated_at: watermark - 1.second)
      TaskCheckpoint.create!(name: "book_events_sync", processed_through: watermark)
    end
end
