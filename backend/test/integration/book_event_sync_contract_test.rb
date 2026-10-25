require "test_helper"
require "rake"

class BookEventSyncContractTest < ActiveSupport::TestCase
  test "first synchronization creates missing events and a successful checkpoint" do
    BookEvent.delete_all
    BookEventSync.call

    assert_equal 19, BookEvent.count
    checkpoint = TaskCheckpoint.find_by!(name: "book_events_sync")
    assert_equal "succeeded", checkpoint.status
    assert checkpoint.processed_through.present?
    assert checkpoint.last_succeeded_at.present?
    assert_equal 17, checkpoint.books_processed
  end

  test "scheduled rake entry point is idempotent for unchanged books" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("book_events:sync")
    task = Rake::Task["book_events:sync"]
    original_ids = BookEvent.order(:id).pluck(:id)

    2.times do
      task.reenable
      task.invoke
      assert_equal original_ids, BookEvent.order(:id).pluck(:id)
    end
    assert_equal 1, TaskCheckpoint.where(name: "book_events_sync").count
  end

  test "incremental run corrects dates removes finish and preserves unrelated events" do
    watermark = Time.utc(2026, 6, 1)
    TaskCheckpoint.create!(name: "book_events_sync", processed_through: watermark, status: "succeeded")
    Book.update_all(updated_at: watermark - 1.day)
    changed = books(:completed)
    start_id = book_events(:completed_start).id
    untouched = books(:same_day).book_events.order(:id).map(&:attributes)
    travel_to watermark + 1.hour do
      changed.update!(started_at: Time.utc(2026, 1, 2), finished_at: nil)
      BookEventSync.call
    end
    assert_equal [ start_id ], changed.book_events.pluck(:id)
    assert_equal Time.utc(2026, 1, 2), BookEvent.find(start_id).date
    assert_equal untouched, books(:same_day).book_events.order(:id).map(&:attributes)
    assert_equal 1, TaskCheckpoint.find_by!(name: "book_events_sync").books_processed
  end

  test "books exactly on the watermark are replayed safely" do
    watermark = Time.utc(2026, 6, 1)
    TaskCheckpoint.create!(name: "book_events_sync", processed_through: watermark, status: "succeeded")
    Book.update_all(updated_at: watermark - 1.day)
    books(:completed).update_columns(started_at: Time.utc(2026, 1, 2), updated_at: watermark)
    start_id = book_events(:completed_start).id
    travel_to watermark + 1.hour do
      BookEventSync.call
    end
    assert_equal Time.utc(2026, 1, 2), BookEvent.find(start_id).date
    assert_equal [ start_id ], books(:completed).book_events.where(type: "START").pluck(:id)
  end

  test "failed reconciliation retains watermark and can be retried without duplicates" do
    watermark = Time.utc(2026, 6, 1)
    checkpoint = TaskCheckpoint.create!(name: "book_events_sync", processed_through: watermark, status: "succeeded")
    Book.update_all(updated_at: watermark - 1.day)
    books(:completed).update_columns(started_at: Time.utc(2026, 1, 2), updated_at: watermark)
    before = BookEvent.order(:id).map(&:attributes)
    fault = lambda do |*args|
      sql = args.last.fetch(:sql)
      raise ActiveRecord::StatementInvalid, "injected event write failure" if sql.match?(/\A\s*(UPDATE|INSERT|DELETE).*["`]book_events["`]/im)
    end
    assert_raises ActiveRecord::StatementInvalid do
      ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
        BookEventSync.call
      end
    end
    assert_equal before, BookEvent.order(:id).map(&:attributes)
    assert_equal watermark, checkpoint.reload.processed_through
    assert_equal "failed", checkpoint.status
    assert checkpoint.last_error.present?
    BookEventSync.call
    assert_equal "succeeded", checkpoint.reload.status
    assert_equal before.map { |event| event.fetch("id") }, BookEvent.order(:id).pluck(:id)
    assert_equal Time.utc(2026, 1, 2), book_events(:completed_start).reload.date
  end
end
