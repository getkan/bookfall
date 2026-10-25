require "test_helper"

class BackendContractTest < ActionDispatch::IntegrationTest
  setup do
    @original_rate_limit_store = SessionsController.login_rate_limit_store
    SessionsController.login_rate_limit_store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    SessionsController.login_rate_limit_store = @original_rate_limit_store
  end

  test "admin login returns a bearer token" do
    post "/login", params: { username: "fixture-admin", password: "fixture-only-password" }, as: :json
    assert_response :ok
    assert response.parsed_body.fetch("token").present?
  end

  test "invalid credentials are rejected explicitly" do
    post "/login", params: { username: "fixture-admin", password: "incorrect" }, as: :json
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.dig("error", "code")
  end

  test "all book routes reject missing authentication" do
    id = books(:completed).id
    [
      [ :get, "/books" ], [ :get, "/books/#{id}" ], [ :post, "/books" ],
      [ :patch, "/books/#{id}" ], [ :delete, "/books/#{id}" ]
    ].each do |method, path|
      public_send(method, path, as: :json)
      assert_response :unauthorized, "#{method.upcase} #{path}"
    end
  end

  test "authenticated admin reads completed and in progress books" do
    headers = admin_headers
    get "/books", headers: headers
    assert_response :ok
    assert_equal Book.count, response.parsed_body.fetch("books").size

    get "/books/#{books(:completed).id}", headers: headers
    assert_response :ok
    book = response.parsed_body.fetch("book")
    assert_equal 5, book.fetch("rating")
    assert_equal "A thoughtful read.", book.fetch("review")
    assert_nil book.fetch("user_id")

    get "/books/#{books(:unfinished).id}", headers: headers
    assert_response :ok
    book = response.parsed_body.fetch("book")
    assert_not book.key?("rating")
    assert_not book.key?("review")
    assert_nil book.fetch("finished_at")
  end

  test "admin can create update review and delete a book" do
    headers = admin_headers
    attributes = {
      title: "New Reading", author: "New Author", user_id: nil,
      started_at: "2026-05-01T12:00:00Z", finished_at: "2026-05-02T12:00:00Z",
      rating: 4, review: "Admin review"
    }
    assert_difference("Book.count", 1) do
      post "/books", params: { book: attributes }, headers: headers, as: :json
      assert_response :created
    end
    id = response.parsed_body.fetch("book").fetch("id")
    patch "/books/#{id}", params: { book: { rating: 5, review: "Updated review" } },
      headers: headers, as: :json
    assert_response :ok
    assert_equal "Updated review", response.parsed_body.dig("book", "review")
    assert_difference("Book.count", -1) do
      delete "/books/#{id}", headers: headers
      assert_response :no_content
    end
    assert_empty BookEvent.where(book_id: id)
  end

  test "invalid admin book writes have explicit validation errors" do
    post "/books", params: { book: { title: "", rating: 6 } },
      headers: admin_headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
  end

  test "admin edit updates associated event dates without replacing identities" do
    book = books(:completed)
    event_ids = book.book_events.order(:id).pluck(:id)
    patch "/books/#{book.id}",
      params: { book: { started_at: "2026-01-02T12:00:00Z", finished_at: "2026-04-02T12:00:00Z" } },
      headers: admin_headers, as: :json
    assert_response :ok
    assert_equal event_ids, book.book_events.order(:id).pluck(:id)
    assert_equal Time.utc(2026, 1, 2, 12), book.book_events.find_by!(type: "START").date
    assert_equal Time.utc(2026, 4, 2, 12), book.book_events.find_by!(type: "FINISH").date
  end

  test "admin deletion removes preexisting associated events" do
    book = books(:completed)
    assert_equal 2, book.book_events.count
    headers = admin_headers
    assert_difference("BookEvent.count", -2) do
      assert_difference("Book.count", -1) do
        delete "/books/#{book.id}", headers: headers
        assert_response :no_content
      end
    end
    assert_empty BookEvent.where(book_id: book.id)
  end

  private
    def admin_headers
      post "/login", params: { username: "fixture-admin", password: "fixture-only-password" }, as: :json
      assert_response :ok
      { "Authorization" => "Bearer #{response.parsed_body.fetch("token")}" }
    end
end
