require "test_helper"

class BookCrudTest < ActionDispatch::IntegrationTest
  setup do
    @headers = { "Authorization" => "Bearer #{users(:admin).generate_token_for(:api_access)}" }
  end

  test "create permits book fields only and leaves event creation to sync" do
    assert_no_difference -> { BookEvent.count } do
      assert_difference -> { Book.count }, 1 do
        post "/books", params: { book: attributes.merge(id: 9999, is_admin: true) },
          headers: @headers, as: :json
        assert_response :created
      end
    end
    book = Book.find(response.parsed_body.fetch("book").fetch("id"))
    assert_not_equal 9999, book.id
    assert_equal "opaque-reader", book.user_id
    assert_equal Time.utc(2026, 5, 1, 10), book.started_at
    assert_equal 4, book.rating
    assert_equal "Stored for completion", book.review
    assert_not response.parsed_body.fetch("book").key?("rating")
    assert_not response.parsed_body.fetch("book").key?("review")
  end

  test "detail uses the same serialization as listing" do
    get "/books", headers: @headers
    listed = response.parsed_body.fetch("books")
    [ books(:completed), books(:unfinished), books(:same_day) ].each do |book|
      get "/books/#{book.id}", headers: @headers
      assert_response :ok
      assert_equal [ "book" ], response.parsed_body.keys
      assert_equal listed.find { |entry| entry.fetch("id") == book.id }, response.parsed_body.fetch("book")
    end
  end

  test "missing books return explicit errors for detail update and delete" do
    [ :get, :patch, :delete ].each do |method|
      payload = { book: { title: "Missing" } } if method == :patch
      public_send(method, "/books/999999", params: payload,
        headers: @headers, as: :json)
      assert_error :not_found, "not_found"
    end
  end

  test "missing empty or nonscalar book parameters return explicit errors" do
    [ :post, :patch ].each do |method|
      path = method == :post ? "/books" : "/books/#{books(:completed).id}"
      [ {}, { book: nil }, { book: {} }, { book: "bad" }, { book: [] },
        { book: { title: [] } }, { book: { rating: {} } },
        { book: { started_at: true } } ].each do |payload|
        assert_no_difference -> { Book.count } do
          public_send(method, path, params: payload, headers: @headers, as: :json)
          assert_error :bad_request, "invalid_parameters"
        end
      end
    end
  end

  test "invalid writes return validation errors without changing books or events" do
    book = books(:completed)
    before = book.attributes
    events = book.book_events.order(:id).map(&:attributes)
    [ { title: "" }, { author: nil }, { started_at: "invalid" },
      { finished_at: "invalid" }, { rating: 0 }, { rating: 6 }, { rating: 1.5 },
      { finished_at: "2025-01-01T00:00:00Z" } ].each do |invalid|
      post "/books", params: { book: attributes.merge(invalid) }, headers: @headers, as: :json
      assert_error :unprocessable_entity, "validation_failed"
      patch "/books/#{book.id}", params: { book: invalid }, headers: @headers, as: :json
      assert_error :unprocessable_entity, "validation_failed"
      assert_equal before, book.reload.attributes
      assert_equal events, book.book_events.order(:id).map(&:attributes)
    end
  end

  test "partial edits preserve event ids and ranks and do not modify unrelated books" do
    book = books(:completed)
    identities = book.book_events.order(:id).pluck(:id, :type, :start_rank)
    other_book = books(:same_day).attributes
    other_events = books(:same_day).book_events.order(:id).map(&:attributes)

    patch "/books/#{book.id}", params: { book: {
      title: "Edited title", started_at: "2026-01-02T12:00:00Z",
      finished_at: "2026-04-02T12:00:00Z", rating: nil, review: nil
    } }, headers: @headers, as: :json
    assert_response :ok
    assert_equal "Edited title", book.reload.title
    assert_equal "Example Author", book.author
    assert_nil book.rating
    assert_nil book.review
    assert_equal identities, book.book_events.order(:id).pluck(:id, :type, :start_rank)
    assert_equal Time.utc(2026, 1, 2, 12), book.book_events.find_by!(type: "START").date
    assert_equal Time.utc(2026, 4, 2, 12), book.book_events.find_by!(type: "FINISH").date
    assert_equal other_book, books(:same_day).reload.attributes
    assert_equal other_events, books(:same_day).book_events.order(:id).map(&:attributes)
  end

  test "removing completion removes only the finish event and hides the stored review" do
    book = books(:completed)
    start = book.book_events.find_by!(type: "START").attributes
    assert_difference -> { BookEvent.count }, -1 do
      patch "/books/#{book.id}", params: { book: { finished_at: nil } }, headers: @headers, as: :json
      assert_response :ok
    end
    assert_equal start, book.book_events.find_by!(type: "START").attributes
    assert_nil book.reload.finished_at
    assert_equal "A thoughtful read.", book.review
    assert_not response.parsed_body.fetch("book").key?("review")
  end

  test "adding completion does not invent a finish event or rank" do
    book = books(:unfinished)
    assert_no_difference -> { BookEvent.count } do
      patch "/books/#{book.id}", params: { book: {
        finished_at: "2026-05-01T12:00:00Z", rating: 5, review: "Finished"
      } }, headers: @headers, as: :json
      assert_response :ok
    end
    assert_equal 5, response.parsed_body.dig("book", "rating")
    assert_equal "Finished", response.parsed_body.dig("book", "review")
    assert_nil book.book_events.find_by(type: "FINISH")
  end

  test "an event update failure rolls back the book and all event changes" do
    book = books(:completed)
    original_book = book.attributes
    original_events = book.book_events.order(:id).map(&:attributes)
    updates = 0
    fault = lambda do |*args|
      if args.last.fetch(:sql).match?(/\A\s*UPDATE\s+["`]book_events["`]/i)
        updates += 1
        raise ActiveRecord::StatementInvalid, "injected event failure" if updates == 2
      end
    end

    assert_raises ActiveRecord::StatementInvalid do
      ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
        patch "/books/#{book.id}", params: { book: {
          started_at: "2026-01-02T12:00:00Z", finished_at: "2026-04-02T12:00:00Z"
        } }, headers: @headers, as: :json
      end
    end
    assert_equal 2, updates
    assert_equal original_book, book.reload.attributes
    assert_equal original_events, book.book_events.order(:id).map(&:attributes)
  end

  test "a book deletion failure restores its already deleted events" do
    book = books(:completed)
    original_events = book.book_events.order(:id).map(&:attributes)
    fault = lambda do |*args|
      if args.last.fetch(:sql).match?(/\A\s*DELETE FROM\s+["`]books["`]/i)
        raise ActiveRecord::StatementInvalid, "injected book deletion failure"
      end
    end
    assert_raises ActiveRecord::StatementInvalid do
      ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
        delete "/books/#{book.id}", headers: @headers
      end
    end
    assert Book.exists?(book.id)
    assert_equal original_events, book.book_events.order(:id).map(&:attributes)
  end

  private
    def attributes
      {
        user_id: "opaque-reader", title: "New book", author: "New author",
        started_at: "2026-05-01T12:00:00+02:00", finished_at: nil,
        rating: 4, review: "Stored for completion"
      }
    end

    def assert_error(status, code)
      assert_response status
      assert_kind_of Hash, response.parsed_body["error"], response.body
      assert_equal code, response.parsed_body.dig("error", "code")
      assert response.parsed_body.dig("error", "message").present?
    end
end
