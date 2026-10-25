require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @original_store = SessionsController.login_rate_limit_store
    SessionsController.login_rate_limit_store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    SessionsController.login_rate_limit_store = @original_store
  end

  test "admin login returns only a usable token without cookie authentication" do
    login
    assert_response :ok
    assert_equal [ "token" ], response.parsed_body.keys
    assert_equal users(:admin), User.find_by_token_for(:api_access, response.parsed_body.fetch("token"))
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_nil response.headers["Set-Cookie"]
    get "/books"
    assert_error :unauthorized, "unauthorized"
  end

  test "missing malformed unknown wrong and nonadmin credentials return the same error" do
    users(:admin).update!(is_admin: false)
    [
      {}, { username: "unknown", password: "wrong" },
      { username: "fixture-admin", password: "wrong" },
      { username: "fixture-admin", password: "fixture-only-password" },
      { username: [], password: {} }, { username: "fixture-admin", password: "" }
    ].each do |credentials|
      post "/login", params: credentials, as: :json
      assert_error :unauthorized, "unauthorized"
      assert_equal "Invalid admin credentials", response.parsed_body.dig("error", "message")
    end
  end

  test "every book route rejects missing malformed tampered and nonadmin bearer credentials" do
    admin_token = users(:admin).generate_token_for(:api_access)
    users(:admin).update!(is_admin: false)
    [ nil, "Basic invalid", "Bearer", "Bearer invalid", "Bearer #{admin_token}tampered",
      "Bearer #{admin_token} extra", "Bearer #{admin_token}" ].each do |authorization|
      book_routes.each do |method, path|
        headers = authorization ? { "Authorization" => authorization } : {}
        public_send(method, path, headers: headers, as: :json)
        if authorization == "Bearer #{admin_token}"
          assert_error :forbidden, "forbidden"
        else
          assert_error :unauthorized, "unauthorized"
        end
      end
    end
  end

  test "valid admin bearer reaches book listing and remaining action boundaries" do
    token = users(:admin).generate_token_for(:api_access)
    book_routes.each do |method, path|
      public_send(method, path, headers: { "Authorization" => "Bearer #{token}" }, as: :json)
      if method == :get && path == "/books"
        assert_response :ok
        assert response.parsed_body.fetch("books").is_a?(Array)
      else
        assert_error :not_implemented, "not_implemented"
      end
    end
  end

  test "expired revoked and deleted-user tokens cannot reach book actions" do
    travel_to Time.utc(2026, 6, 1)
    user = users(:admin)
    token = user.generate_token_for(:api_access)
    travel 12.hours + 1.second
    get "/books", headers: { "Authorization" => "Bearer #{token}" }
    assert_error :unauthorized, "unauthorized"
    token = user.generate_token_for(:api_access)
    user.update!(password: "changed-fixture-password")
    get "/books", headers: { "Authorization" => "Bearer #{token}" }
    assert_error :unauthorized, "unauthorized"
    token = user.generate_token_for(:api_access)
    user.destroy!
    get "/books", headers: { "Authorization" => "Bearer #{token}" }
    assert_error :unauthorized, "unauthorized"
  ensure
    travel_back
  end

  test "rate limit counts successes and failures and resets after three minutes" do
    travel_to Time.utc(2026, 6, 1)
    5.times { login; assert_response :ok }
    5.times { login(password: "wrong"); assert_response :unauthorized }
    login
    assert_error :too_many_requests, "rate_limited"
    assert_equal "180", response.headers["Retry-After"]
    travel 3.minutes + 1.second
    login
    assert_response :ok
  ensure
    travel_back
  end

  test "rate limit is IP scoped and ignores spoofed forwarding from untrusted peers" do
    headers = { "REMOTE_ADDR" => "198.51.100.30" }
    10.times do
      post "/login", params: credentials, headers: headers, as: :json
      assert_response :ok
    end
    post "/login", params: credentials,
      headers: headers.merge("X-Forwarded-For" => "198.51.100.10"), as: :json
    assert_error :too_many_requests, "rate_limited"
    post "/login", params: credentials, headers: { "REMOTE_ADDR" => "198.51.100.20" }, as: :json
    assert_response :ok
  end

  test "login rate limit uses the shared database cache across store instances" do
    travel_to Time.utc(2026, 6, 1)
    key = "login-attempts:127.0.0.1"
    first = SolidCache::Store.new
    second = SolidCache::Store.new
    first.delete(key)
    SessionsController.login_rate_limit_store = first
    10.times { login; assert_response :ok }
    SessionsController.login_rate_limit_store = second
    travel 2.minutes
    login
    assert_error :too_many_requests, "rate_limited"
    travel 1.minute + 1.second
    login
    assert_response :ok
  ensure
    first&.delete(key)
    travel_back
  end

  test "configured trusted proxies separate forwarded clients" do
    proxy = IPAddr.new("192.0.2.10")
    proxies = Rails.application.config.action_dispatch.trusted_proxies
    proxies << proxy
    headers = { "REMOTE_ADDR" => "192.0.2.10", "X-Forwarded-For" => "198.51.100.40" }
    10.times do
      post "/login", params: credentials, headers: headers, as: :json
      assert_response :ok
    end
    post "/login", params: credentials, headers: headers, as: :json
    assert_error :too_many_requests, "rate_limited"
    post "/login", params: credentials,
      headers: headers.merge("X-Forwarded-For" => "198.51.100.50"), as: :json
    assert_response :ok
  ensure
    proxies&.delete(proxy)
  end

  test "rate limit store failure is not treated as an unlimited successful login" do
    store = ActiveSupport::Cache::MemoryStore.new
    store.define_singleton_method(:increment) { |*| nil }
    SessionsController.login_rate_limit_store = store
    error = assert_raises(RuntimeError) { login }
    assert_equal "Login rate limit store did not record the attempt", error.message
  end

  private
    def credentials
      { username: "fixture-admin", password: "fixture-only-password" }
    end

    def login(password: "fixture-only-password")
      post "/login", params: credentials.merge(password: password), as: :json
    end

    def book_routes
      id = books(:completed).id
      [ [ :get, "/books" ], [ :get, "/books/#{id}" ], [ :post, "/books" ],
        [ :patch, "/books/#{id}" ], [ :delete, "/books/#{id}" ] ]
    end

    def assert_error(status, code)
      assert_response status
      assert_equal code, response.parsed_body.dig("error", "code")
      assert response.parsed_body.dig("error", "message").present?
    end
end
