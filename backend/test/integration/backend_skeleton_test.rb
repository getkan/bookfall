require "test_helper"

class BackendSkeletonTest < ActionDispatch::IntegrationTest
  test "remaining product routes explicitly report unimplemented behavior after authorization" do
    id = books(:completed).id
    [
      [ :get, "/books/#{id}" ],
      [ :post, "/books" ], [ :patch, "/books/#{id}" ],
      [ :delete, "/books/#{id}" ], [ :get, "/book-events" ]
    ].each do |method, path|
      public_send(method, path,
        headers: { "Authorization" => "Bearer #{users(:admin).generate_token_for(:api_access)}" }, as: :json)
      assert_response :not_implemented
      assert_equal "not_implemented", response.parsed_body.dig("error", "code")
      assert response.parsed_body.dig("error", "message").present?
    end
  end
end
