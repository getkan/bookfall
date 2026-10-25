require "test_helper"

class BookEventSyncPublicationTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rails.cache
    Rails.cache = SolidCache::Store.new
    Rails.cache.delete(Timeline::Refresh::CURRENT_KEY)
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "sync publishes joined changes while old cursors stay pinned" do
    get "/book-events"
    assert_response :ok
    first = response.parsed_body
    old_cursor = first.fetch("next_cursor")
    books(:completed).update!(title: "Synced title", rating: 2)
    checkpoint = BookEventSync.call

    get "/book-events"
    assert_response :ok
    fresh = response.parsed_body
    assert_not_equal first.fetch("revision"), fresh.fetch("revision")
    event = fresh.fetch("events").find { |item| item.fetch("book_id") == books(:completed).id }
    assert_equal "Synced title", event.fetch("title")
    assert_equal 2, event.fetch("rating")
    assert_equal "succeeded", checkpoint.status
    get "/book-events", params: { cursor: old_cursor }
    assert_response :ok
    assert_equal first.fetch("revision"), response.parsed_body.fetch("revision")
  end

  test "no changed books still publishes hard deletions" do
    BookEventSync.call
    old_revision = Rails.cache.read(Timeline::Refresh::CURRENT_KEY)
    id = books(:same_day).id
    books(:same_day).destroy!
    checkpoint = BookEventSync.call
    assert_equal 0, checkpoint.books_processed
    revision = Rails.cache.read(Timeline::Refresh::CURRENT_KEY)
    assert_not_equal old_revision, revision
    assert_not Timeline::Refresh.read(revision).fetch("events").any? { |event| event.fetch("book_id") == id }
    assert Timeline::Refresh.read(old_revision).fetch("events").any? { |event| event.fetch("book_id") == id }
  end

  test "cache write failure rolls back event creation and retains published state for retry" do
    [ "snapshot", "pointer" ].each do |stage|
      BookEvent.delete_all
      TaskCheckpoint.delete_all
      original = Timeline::Refresh.call
      before_keys = SolidCache::Entry.order(:id).pluck(:id)
      fault = lambda do |*args|
        payload = args.last
        key = payload[:key].to_s
        next unless key.include?("timeline:v1:")
        next if stage == "pointer" && !key.end_with?(Timeline::Refresh::CURRENT_KEY)

        raise "Injected cache publication failure"
      end
      assert_raises RuntimeError do
        ActiveSupport::Notifications.subscribed(fault, "cache_write.active_support") { BookEventSync.call }
      end
      assert_equal 0, BookEvent.count
      assert_equal original.fetch("revision"), Rails.cache.read(Timeline::Refresh::CURRENT_KEY)
      assert_equal before_keys, SolidCache::Entry.order(:id).pluck(:id)
      checkpoint = TaskCheckpoint.find_by!(name: "book_events_sync")
      assert_nil checkpoint.processed_through
      assert_equal "failed", checkpoint.status
      assert_equal "RuntimeError", checkpoint.last_error
      assert_equal "succeeded", BookEventSync.call.status
      assert_equal 19, BookEvent.count
    end
  end

  test "failure after cache publication rolls back pointer snapshot events and watermark" do
    previous = BookEventSync.call
    before_checkpoint = previous.attributes
    revision = Rails.cache.read(Timeline::Refresh::CURRENT_KEY)
    keys = SolidCache::Entry.order(:id).pluck(:id)
    book = books(:completed)
    book.update!(started_at: book.started_at + 1.day)
    events = BookEvent.order(:id).map(&:attributes)
    fault = lambda do |*args|
      sql = args.last.fetch(:sql)
      if sql.match?(/\A\s*UPDATE\s+["`]task_checkpoints["`]/i) &&
          Rails.cache.read(Timeline::Refresh::CURRENT_KEY) != revision
        raise ActiveRecord::StatementInvalid, "injected final checkpoint failure"
      end
    end
    assert_raises ActiveRecord::StatementInvalid do
      ActiveSupport::Notifications.subscribed(fault, "sql.active_record") { BookEventSync.call }
    end
    assert_equal revision, Rails.cache.read(Timeline::Refresh::CURRENT_KEY)
    assert_equal keys, SolidCache::Entry.order(:id).pluck(:id)
    assert_equal events, BookEvent.order(:id).map(&:attributes)
    assert_equal before_checkpoint.fetch("processed_through"), previous.reload.processed_through
    assert_equal before_checkpoint.fetch("last_succeeded_at"), previous.last_succeeded_at
    assert_equal "failed", previous.status
  end
end
