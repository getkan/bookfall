require "test_helper"

class BackendSkeletonTest < ActionDispatch::IntegrationTest
  test "all planned routes explicitly report unimplemented behavior" do
    id = books(:completed).id
    [
      [ :post, "/login" ], [ :get, "/books" ], [ :get, "/books/#{id}" ],
      [ :post, "/books" ], [ :patch, "/books/#{id}" ],
      [ :delete, "/books/#{id}" ], [ :get, "/book-events" ]
    ].each do |method, path|
      public_send(method, path, as: :json)
      assert_response :not_implemented
      assert_equal "not_implemented", response.parsed_body.dig("error", "code")
      assert response.parsed_body.dig("error", "message").present?
    end
  end
end
