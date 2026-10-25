require "test_helper"

class BookListingTest < ActionDispatch::IntegrationTest
  test "admin list contains all books and only approved fields in stable order" do
    get "/books", headers: admin_headers
    assert_response :ok
    body = response.parsed_body
    assert_equal [ "books" ], body.keys
    listed = body.fetch("books")
    assert_equal Book.order(:id).pluck(:id), listed.map { |book| book.fetch("id") }
    listed.each do |book|
      source = Book.find(book.fetch("id"))
      fields = %w[id user_id title author started_at finished_at]
      fields.concat(%w[rating review]) if source.finished_at
      assert_equal fields.sort, book.keys.sort
      assert_equal source.user_id, book.fetch("user_id") if source.user_id
      assert_nil book.fetch("user_id") unless source.user_id
      assert_equal source.title, book.fetch("title")
      assert_equal source.author, book.fetch("author")
      assert_equal source.started_at, Time.iso8601(book.fetch("started_at"))
      if source.finished_at
        assert_equal source.finished_at, Time.iso8601(book.fetch("finished_at"))
      else
        assert_nil book.fetch("finished_at")
      end
    end
    completed = listed.find { |book| book.fetch("id") == books(:completed).id }
    assert_equal 5, completed.fetch("rating")
    assert_equal "A thoughtful read.", completed.fetch("review")
    unreviewed = listed.find { |book| book.fetch("id") == books(:same_day).id }
    assert_nil unreviewed.fetch("rating")
    assert_nil unreviewed.fetch("review")
  end

  test "unfinished books omit reviews even when stored" do
    books(:unfinished).update!(rating: 4, review: "Not yet public in reads")
    get "/books", headers: admin_headers
    assert_response :ok
    book = response.parsed_body.fetch("books").find { |item| item.fetch("id") == books(:unfinished).id }
    assert_not book.key?("rating")
    assert_not book.key?("review")
  end

  test "empty book list returns an explicit empty array" do
    BookEvent.delete_all
    Book.delete_all
    get "/books", headers: admin_headers
    assert_response :ok
    assert_equal({ "books" => [] }, response.parsed_body)
  end

  private
    def admin_headers
      { "Authorization" => "Bearer #{users(:admin).generate_token_for(:api_access)}" }
    end
end
