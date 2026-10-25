require "test_helper"

class CorsTest < ActionDispatch::IntegrationTest
  test "configured origin permits authorization and JSON preflights for approved methods" do
    %w[GET POST PATCH DELETE OPTIONS HEAD].each do |method|
      options "/books", headers: {
        "Origin" => origin,
        "Access-Control-Request-Method" => method,
        "Access-Control-Request-Headers" => "Authorization, Content-Type"
      }
      assert_response :ok
      assert_equal origin, response.headers["Access-Control-Allow-Origin"]
      assert_includes response.headers.fetch("Access-Control-Allow-Methods").split(/,\s*/), method
      allowed_headers = response.headers.fetch("Access-Control-Allow-Headers").downcase
      assert_includes allowed_headers, "authorization"
      assert_includes allowed_headers, "content-type"
      assert_nil response.headers["Access-Control-Allow-Credentials"]
    end
  end

  test "allowed origin receives CORS headers on authentication errors without bypassing auth" do
    get "/books", headers: { "Origin" => origin }
    assert_response :unauthorized
    assert_equal origin, response.headers["Access-Control-Allow-Origin"]
    assert_nil response.headers["Access-Control-Allow-Credentials"]
    assert_equal "unauthorized", response.parsed_body.dig("error", "code")
    assert_includes response.headers.fetch("Vary").downcase, "origin"
  end

  test "allowed authenticated requests retain normal book behavior" do
    get "/books", headers: {
      "Origin" => origin,
      "Authorization" => "Bearer #{users(:admin).generate_token_for(:api_access)}"
    }
    assert_response :ok
    assert_equal origin, response.headers["Access-Control-Allow-Origin"]
    assert_equal Book.count, response.parsed_body.fetch("books").size
    assert_nil response.headers["Access-Control-Allow-Credentials"]
  end

  test "unapproved origins do not receive CORS permission for actual requests or preflights" do
    [ "https://unapproved.invalid", "#{origin}.unapproved.invalid", "null" ].each do |unapproved|
      get "/books", headers: { "Origin" => unapproved }
      assert_response :unauthorized
      assert_nil response.headers["Access-Control-Allow-Origin"]
      options "/books", headers: {
        "Origin" => unapproved,
        "Access-Control-Request-Method" => "POST",
        "Access-Control-Request-Headers" => "Authorization"
      }
      assert_nil response.headers["Access-Control-Allow-Origin"]
    end
  end

  test "PUT is not granted preflight permission and same originless requests are unaffected" do
    options "/books/101", headers: {
      "Origin" => origin, "Access-Control-Request-Method" => "PUT"
    }
    assert_nil response.headers["Access-Control-Allow-Origin"]
    get "/books"
    assert_response :unauthorized
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  private
    def origin
      Rails.application.config.x.frontend_origin
    end
end
