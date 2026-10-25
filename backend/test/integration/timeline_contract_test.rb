require "test_helper"
require "rake"

class TimelineContractTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "timeline pages preserve revision complete UTC days pairs and empty spans" do
    get "/book-events"
    assert_response :ok
    first = response.parsed_body
    revision = first.fetch("revision")
    assert revision.present?
    assert_equal({ "first_date" => "2026-01-01", "last_date" => "2026-04-01" }, first.fetch("bounds"))
    seen = []
    pages = []
    cursors = []

    100.times do
      page = response.parsed_body
      assert_equal revision, page.fetch("revision")
      assert_equal first.fetch("bounds"), page.fetch("bounds")
      from = Date.iso8601(page.fetch("span").fetch("from"))
      through = Date.iso8601(page.fetch("span").fetch("through"))
      assert_operator through, :>=, from
      assert_operator (through - from).to_i + 1, :<=, 30
      assert_equal Date.iso8601(pages.last.fetch("span").fetch("through")) + 1, from if pages.any?
      events = page.fetch("events")
      expected_ids = BookEvent.where(date: from.beginning_of_day..through.end_of_day).pluck(:id)
      assert_equal expected_ids.sort, events.map { |event| event.fetch("id") }.sort
      events.each do |event|
        assert_equal revision, page.fetch("revision")
        assert_includes [ "START", "FINISH" ], event.fetch("type")
        assert_includes 1..12, event.fetch("start_rank")
        assert_equal "Z", event.fetch("date")[-1]
        assert event.key?("user_id")
        assert event.key?("title")
        assert event.key?("author")
      end
      seen.concat(events)
      pages << page
      cursor = page.fetch("next_cursor")
      break if cursor.nil?
      assert_not_includes cursors, cursor
      cursors << cursor
      get "/book-events", params: { cursor: cursor }
      assert_response :ok
    end

    assert_nil pages.last.fetch("next_cursor"), "pagination must terminate"
    assert_equal BookEvent.order(:id).pluck(:id), seen.map { |event| event.fetch("id") }.sort
    assert_equal seen.size, seen.map { |event| event.fetch("id") }.uniq.size
    assert pages.any? { |page| page.fetch("events").empty? && page.fetch("next_cursor").present? }
    paired = seen.select { |event| event.fetch("book_id") == books(:completed).id }
    assert_equal [ "FINISH", "START" ], paired.map { |event| event.fetch("type") }.sort
    assert_equal [ 1 ], paired.map { |event| event.fetch("start_rank") }.uniq
    pair_pages = pages.select { |page| page.fetch("events").any? { |event| event.fetch("book_id") == books(:completed).id } }
    assert_equal 2, pair_pages.size
  end

  test "empty timeline has explicit empty bounds and terminal cursor" do
    BookEvent.delete_all
    Book.delete_all
    get "/book-events"
    assert_response :ok
    page = response.parsed_body
    assert_equal({ "first_date" => nil, "last_date" => nil }, page.fetch("bounds"))
    assert_nil page.fetch("span")
    assert_empty page.fetch("events")
    assert_nil page.fetch("next_cursor")
  end

  test "invalid cursor is not a success shaped empty result" do
    get "/book-events", params: { cursor: "invalid" }
    assert_response :bad_request
    assert_equal "invalid_cursor", response.parsed_body.dig("error", "code")
  end

  test "after anchor normalizes offset and includes its whole UTC day" do
    get "/book-events", params: { after: "2026-01-05T01:00:00+02:00" }
    assert_response :ok
    page = response.parsed_body
    assert_equal({ "from" => "2026-01-04", "through" => "2026-02-02" }, page.fetch("span"))
    assert_equal 14, page.fetch("events").size
    assert_equal BookEvent.where(date: Time.utc(2026, 1, 4).all_day).order(:id).pluck(:id),
      page.fetch("events").map { |event| event.fetch("id") }
  end

  test "before anchor includes later events on the same day" do
    get "/book-events", params: { before: "2026-01-03T12:00:00Z" }
    assert_response :ok
    page = response.parsed_body
    assert_equal({ "from" => "2026-01-01", "through" => "2026-01-03" }, page.fetch("span"))
    assert_includes page.fetch("events").map { |event| event.fetch("id") }, book_events(:same_day_finish).id
    assert_nil page.fetch("next_cursor")
  end

  test "backward traversal preserves complete days revision and chronological page order" do
    get "/book-events", params: { before: "2026-04-01T12:00:00Z" }
    assert_response :ok
    revision = response.parsed_body.fetch("revision")
    pages = []
    cursors = []
    10.times do
      page = response.parsed_body
      assert_equal revision, page.fetch("revision")
      span = page.fetch("span")
      from = Date.iso8601(span.fetch("from"))
      through = Date.iso8601(span.fetch("through"))
      assert_equal Date.iso8601(pages.last.fetch("span").fetch("from")) - 1, through if pages.any?
      assert_operator (through - from).to_i + 1, :<=, 30
      events = page.fetch("events")
      expected = BookEvent.where(date: from.beginning_of_day..through.end_of_day).to_a.sort_by do |event|
        [ event.date, event.type == "FINISH" ? 0 : 1, event.start_rank, event.book_id, event.id ]
      end
      assert_equal expected.map(&:id), events.map { |event| event.fetch("id") }
      pages << page
      cursor = page.fetch("next_cursor")
      break if cursor.nil?
      assert_not_includes cursors, cursor
      cursors << cursor
      get "/book-events", params: { cursor: cursor }
      assert_response :ok
    end
    assert_nil pages.last.fetch("next_cursor"), "backward browsing must terminate"
    ids = pages.flat_map { |page| page.fetch("events").map { |event| event.fetch("id") } }
    assert_equal BookEvent.order(:id).pluck(:id), ids.sort
    assert_equal ids.size, ids.uniq.size
    assert pages.any? { |page| page.fetch("events").empty? && page.fetch("next_cursor").present? }
  end

  test "anchors outside navigable bounds are terminal without losing revision bounds" do
    [ { after: "2027-01-01T00:00:00Z" }, { before: "2025-01-01T00:00:00Z" } ].each do |query|
      get "/book-events", params: query
      assert_response :ok
      page = response.parsed_body
      assert_equal({ "first_date" => "2026-01-01", "last_date" => "2026-04-01" }, page.fetch("bounds"))
      assert_empty page.fetch("events")
      assert_nil page.fetch("span")
      assert_nil page.fetch("next_cursor")
    end
  end

  test "opposite outer anchors clip to bounds" do
    get "/book-events", params: { after: "2025-01-01T00:00:00Z" }
    assert_response :ok
    assert_equal "2026-01-01", response.parsed_body.dig("span", "from")
    get "/book-events", params: { before: "2027-01-01T00:00:00Z" }
    assert_response :ok
    assert_equal "2026-04-01", response.parsed_body.dig("span", "through")
  end

  test "conflicting empty and duplicate parameters are explicit errors" do
    [
      "before=2026-01-01T00:00:00Z&after=2026-01-01T00:00:00Z",
      "cursor=token&after=2026-01-01T00:00:00Z",
      "cursor=token&before=2026-01-01T00:00:00Z",
      "after=", "before=", "cursor=",
      "after=2026-01-01T00:00:00Z&after=2026-01-02T00:00:00Z",
      "before=2026-01-01T00:00:00Z&before=2026-01-02T00:00:00Z",
      "cursor=first&cursor=second"
    ].each do |query|
      get "/book-events?#{query}"
      assert_response :bad_request
      assert_equal "invalid_parameters", response.parsed_body.dig("error", "code")
    end
  end

  test "anchors require valid full timestamps with explicit timezones" do
    [ "invalid", "2026-01-01", "2026-01-01T12:00:00", "2026-02-30T12:00:00Z" ].each do |timestamp|
      [ :before, :after ].each do |direction|
        get "/book-events", params: { direction => timestamp }
        assert_response :bad_request
        assert_equal "invalid_timestamp", response.parsed_body.dig("error", "code")
      end
    end
  end

  test "cursor pins event payloads across source mutations" do
    get "/book-events"
    assert_response :ok
    first = response.parsed_body
    original = books(:completed).title
    books(:completed).update!(title: "Changed after first page")
    book_events(:completed_finish).update!(date: Time.utc(2026, 5, 1))
    cursor = first.fetch("next_cursor")
    found = nil
    10.times do
      break if cursor.nil?
      get "/book-events", params: { cursor: cursor }
      assert_response :ok
      page = response.parsed_body
      assert_equal first.fetch("revision"), page.fetch("revision")
      assert_equal first.fetch("bounds"), page.fetch("bounds")
      found ||= page.fetch("events").find { |event| event.fetch("id") == book_events(:completed_finish).id }
      cursor = page.fetch("next_cursor")
    end
    assert_nil cursor, "pinned traversal must terminate"
    assert found.present?, "the original finish event must remain in the pinned revision"
    assert_equal original, found.fetch("title")
    assert_equal "2026-04-01T12:00:00Z", found.fetch("date")
  end

  test "revision expires after 24 hours instead of silently switching data" do
    travel_to Time.utc(2026, 6, 1)
    get "/book-events"
    assert_response :ok
    first = response.parsed_body
    cursor = first.fetch("next_cursor")
    assert cursor.present?

    travel 23.hours
    get "/book-events", params: { cursor: cursor }
    assert_response :ok
    assert_equal first.fetch("revision"), response.parsed_body.fetch("revision")
    travel 1.hour + 1.second
    get "/book-events", params: { cursor: cursor }
    assert_response :gone
    assert_equal "revision_expired", response.parsed_body.dig("error", "code")
    get "/book-events"
    assert_response :ok
    assert_not_equal first.fetch("revision"), response.parsed_body.fetch("revision")
  ensure
    travel_back
  end

  test "cache eviction expires pinned cursor but initial request can recover" do
    get "/book-events"
    assert_response :ok
    cursor = response.parsed_body.fetch("next_cursor")
    assert cursor.present?
    Rails.cache.clear
    get "/book-events", params: { cursor: cursor }
    assert_response :gone
    assert_equal "revision_expired", response.parsed_body.dig("error", "code")
    get "/book-events"
    assert_response :ok
  end

  test "force refresh publishes changed data and keeps older cursors usable" do
    get "/book-events"
    assert_response :ok
    first = response.parsed_body
    cursor = first.fetch("next_cursor")
    assert cursor.present?
    books(:completed).update!(title: "Fresh cached title")
    Rails.application.load_tasks unless Rake::Task.task_defined?("book_events:refresh_cache")
    task = Rake::Task["book_events:refresh_cache"]
    task.reenable
    task.invoke

    get "/book-events"
    assert_response :ok
    fresh = response.parsed_body
    assert_not_equal first.fetch("revision"), fresh.fetch("revision")
    event = fresh.fetch("events").find { |item| item.fetch("id") == book_events(:completed_start).id }
    assert_equal "Fresh cached title", event.fetch("title")

    get "/book-events", params: { cursor: cursor }
    assert_response :ok
    assert_equal first.fetch("revision"), response.parsed_body.fetch("revision")
  end
end
