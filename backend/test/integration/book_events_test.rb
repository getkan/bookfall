require "test_helper"

class BookEventsTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "public detail returns the requested START or FINISH with the timeline payload" do
    snapshot = Timeline::Refresh.call
    [ book_events(:completed_start), book_events(:completed_finish) ].each do |event|
      get "/book-event/#{event.id}"
      assert_response :ok
      assert_equal [ "book_event" ], response.parsed_body.keys
      assert_equal snapshot.fetch("events").find { |item| item.fetch("id") == event.id },
        response.parsed_body.fetch("book_event")
      assert_equal "A thoughtful read.", response.parsed_body.dig("book_event", "review")
    end
  end

  test "detail returns live joined data without changing pinned timeline snapshots" do
    first = Timeline::Refresh.call
    event = book_events(:completed_start)
    books(:completed).update!(title: "Current title", review: "Current review")
    get "/book-event/#{event.id}"
    assert_response :ok
    assert_equal "Current title", response.parsed_body.dig("book_event", "title")
    assert_equal "Current review", response.parsed_body.dig("book_event", "review")
    get "/book-events"
    assert_equal first.fetch("revision"), response.parsed_body.fetch("revision")
    assert_equal "A thoughtful read.",
      response.parsed_body.fetch("events").find { |item| item.fetch("id") == event.id }.fetch("review")
  end

  test "detail keeps unfinished reviews hidden and includes nullable book fields" do
    book = books(:unfinished)
    book.update!(rating: nil, review: "Hidden unfinished review")
    event = book.book_events.first!
    get "/book-event/#{event.id}"
    assert_response :ok
    payload = response.parsed_body.fetch("book_event")
    assert_equal %w[author book_id date id rating review start_rank title type user_id], payload.keys.sort
    assert_nil payload.fetch("review")
    assert_nil payload.fetch("rating")
    assert_equal book.user_id, payload.fetch("user_id")
    assert_not_includes response.body, "Hidden unfinished review"
  end

  test "missing and deleted events return JSON not found" do
    event = book_events(:completed_start)
    id = event.id
    event.destroy!
    [ id, 999_999_999, "missing" ].each do |missing|
      get "/book-event/#{missing}"
      assert_response :not_found
      assert_equal({ "error" => { "code" => "not_found", "message" => "Book event not found" } },
        response.parsed_body)
    end
  end

  test "public events include completed book reviews but omit unfinished reviews and credentials" do
    books(:unfinished).update!(rating: 3, review: "Private unfinished review")
    get "/book-events"
    assert_response :ok
    events = response.parsed_body.fetch("events")
    events.each do |event|
      book = Book.find(event.fetch("book_id"))
      assert_equal %w[author book_id date id rating review start_rank title type user_id], event.keys.sort
      assert_equal book.title, event.fetch("title")
      assert_equal book.author, event.fetch("author")
      assert_equal book.user_id, event.fetch("user_id") if book.user_id
      assert_nil event.fetch("user_id") unless book.user_id
      assert_equal book.rating, event.fetch("rating") if book.rating
      assert_nil event.fetch("rating") unless book.rating
      expected_review = book.finished_at ? book.review : nil
      expected_review.nil? ? assert_nil(event.fetch("review")) : assert_equal(expected_review, event.fetch("review"))
      assert_not event.key?("password_digest")
    end
    unfinished = events.find { |event| event.fetch("book_id") == books(:unfinished).id }
    assert_equal "future-reader", unfinished.fetch("user_id")
    assert_equal 3, unfinished.fetch("rating")
    assert_nil unfinished.fetch("review")
    completed = events.find { |event| event.fetch("book_id") == books(:completed).id }
    assert_equal "A thoughtful read.", completed.fetch("review")
    assert_not_includes response.body, "Private unfinished review"
    assert_includes response.body, "A thoughtful read."
  end

  test "review payload uses a new revision namespace instead of cached pre-review snapshots" do
    Rails.cache.write("timeline:v1:current", "legacy-revision")
    Rails.cache.write("timeline:v1:revision:legacy-revision", { "events" => [] })

    get "/book-events"

    assert_response :ok
    assert_not_equal "legacy-revision", response.parsed_body.fetch("revision")
    assert_equal "A thoughtful read.",
      response.parsed_body.fetch("events").find { |event| event.fetch("book_id") == books(:completed).id }.fetch("review")
  end

  test "revision uses one joined query and cached pages never reload books" do
    queries = []
    capture = lambda do |*args|
      sql = args.last.fetch(:sql)
      queries << sql if sql.match?(/\bSELECT\b.*\b(?:books|book_events)\b/im)
    end
    ActiveSupport::Notifications.subscribed(capture, "sql.active_record") { get "/book-events" }
    assert_response :ok
    assert_equal 1, queries.size
    assert_match(/INNER JOIN ["`]books["`]/i, queries.first)
    cursor = response.parsed_body.fetch("next_cursor")
    queries.clear
    ActiveSupport::Notifications.subscribed(capture, "sql.active_record") do
      get "/book-events", params: { cursor: cursor }
      assert_response :ok
      get "/book-events"
      assert_response :ok
    end
    assert_empty queries
  end

  test "ratings and deleted event payloads stay pinned until refresh" do
    first = Timeline::Refresh.call
    original = first.fetch("events").find { |event| event.fetch("book_id") == books(:completed).id }
    books(:completed).update!(rating: 1)
    books(:same_day).destroy!
    get "/book-events"
    assert_response :ok
    assert_equal first.fetch("revision"), response.parsed_body.fetch("revision")
    assert_equal 5, response.parsed_body.fetch("events").find { |event| event.fetch("id") == original.fetch("id") }.fetch("rating")
    assert response.parsed_body.fetch("events").any? { |event| event.fetch("book_id") == 103 }
    Timeline::Refresh.call
    get "/book-events"
    assert_response :ok
    assert_equal 1, response.parsed_body.fetch("events").find { |event| event.fetch("id") == original.fetch("id") }.fetch("rating")
    assert_not response.parsed_body.fetch("events").any? { |event| event.fetch("book_id") == 103 }
  end

  test "refresh failures preserve the current revision and checkpoint" do
    first = Timeline::Refresh.call
    checkpoint = TaskCheckpoint.create!(name: "book_events_sync", status: "succeeded", processed_through: Time.current)
    before = checkpoint.attributes
    [ Timeline::Refresh.key("unused"), Timeline::Refresh::CURRENT_KEY ].each do |failed_key|
      cache = Rails.cache
      cache.define_singleton_method(:write) do |key, *args, **options|
        return false if failed_key == Timeline::Refresh::CURRENT_KEY ? key == failed_key : key.start_with?("timeline:v2:revision:")

        super(key, *args, **options)
      end
      assert_raises(RuntimeError) { Timeline::Refresh.call }
      assert_equal first.fetch("revision"), cache.read(Timeline::Refresh::CURRENT_KEY)
      assert_equal before, checkpoint.reload.attributes
      get "/book-events"
      assert_response :ok
      assert_equal first.fetch("revision"), response.parsed_body.fetch("revision")
      cache.singleton_class.remove_method(:write)
    end
  end

  test "malformed typed parameters and signed invalid cursor payloads return explicit errors" do
    [ "before[]=2026-01-01", "after[date]=2026-01-01", "cursor[]=bad" ].each do |query|
      get "/book-events?#{query}"
      assert_response :bad_request
      assert_equal "invalid_parameters", response.parsed_body.dig("error", "code")
    end
    verifier = Rails.application.message_verifier("timeline-cursor-v1")
    [ {}, { "version" => 2 }, { "version" => 1, "revision" => "missing",
      "direction" => "forward", "boundary" => "not-a-date" } ].each do |payload|
      token = verifier.generate(payload, purpose: "timeline-page")
      get "/book-events", params: { cursor: token }
      assert_response :bad_request
      assert_equal "invalid_cursor", response.parsed_body.dig("error", "code")
    end
  end

  test "same timestamps use type rank book and event identity as stable ordering" do
    BookEvent.update_all(date: Time.utc(2026, 1, 1), start_rank: 2)
    get "/book-events"
    assert_response :ok
    expected = BookEvent.all.sort_by do |event|
      [ event.date, event.type == "FINISH" ? 0 : 1, event.start_rank, event.book_id, event.id ]
    end
    assert_equal expected.map(&:id), response.parsed_body.fetch("events").map { |event| event.fetch("id") }
  end
end
