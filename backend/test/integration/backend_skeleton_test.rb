require "test_helper"

class BackendSkeletonTest < ActionDispatch::IntegrationTest
  test "timeline route is public and returns its implemented envelope" do
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    get "/book-events", as: :json
    assert_response :ok
    assert_equal %w[bounds events next_cursor revision span], response.parsed_body.keys.sort
  ensure
    Rails.cache = original
  end
end
