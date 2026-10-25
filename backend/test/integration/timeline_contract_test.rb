require "test_helper"

class TimelineContractTest < ActionDispatch::IntegrationTest
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
end
