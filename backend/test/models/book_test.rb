require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "required fields reject missing and blank values" do
    [ :title, :author, :started_at ].each do |field|
      [ nil, "", " " ].each do |value|
        book = valid_book
        book.public_send("#{field}=", value)
        assert_not book.valid?, "#{field} must reject #{value.inspect}"
        assert book.errors.of_kind?(field, :blank)
      end
    end
  end

  test "in progress and completed books allow absent rating review and user id" do
    [ nil, Time.utc(2026, 1, 2) ].each do |finished_at|
      book = valid_book
      book.finished_at = finished_at
      assert book.save!, book.errors.full_messages.to_sentence
      book.reload
      assert_nil book.user_id
      assert_nil book.rating
      assert_nil book.review
      if finished_at
        assert_equal finished_at, book.finished_at
      else
        assert_nil book.finished_at
      end
    end
  end

  test "user id is an opaque string without a user association" do
    book = valid_book
    book.user_id = "external-reader"
    book.save!
    assert_equal "external-reader", book.reload.user_id
    assert_nil Book.reflect_on_association(:user)
  end

  test "all integer ratings from one through five are accepted before completion" do
    (1..5).each do |rating|
      book = valid_book
      book.rating = rating
      book.review = "Review before completion"
      assert book.save!, book.errors.full_messages.to_sentence
      assert_equal rating, book.reload.rating
      assert_equal "Review before completion", book.review
      assert_nil book.finished_at
    end
  end

  test "invalid ratings produce model errors rather than database exceptions" do
    [ 0, 6, -1, 1.5, "2.5", "invalid" ].each do |rating|
      book = valid_book
      book.rating = rating
      assert_not book.save, "rating must reject #{rating.inspect}"
      assert book.errors[:rating].present?
      assert_not book.persisted?
    end
  end

  test "completion equal to or after start is accepted" do
    [ Time.utc(2026, 1, 1, 12), Time.utc(2026, 1, 2) ].each do |finished_at|
      book = valid_book
      book.finished_at = finished_at
      assert book.valid?, book.errors.full_messages.to_sentence
    end
  end

  test "completion before start is rejected without a database exception" do
    book = valid_book
    book.finished_at = book.started_at - 1.second
    assert_not book.save
    assert book.errors.of_kind?(:finished_at, :greater_than_or_equal_to)
  end

  test "invalid timestamps are rejected instead of silently clearing completion" do
    [ :started_at, :finished_at ].each do |field|
      book = valid_book
      book.public_send("#{field}=", "not-a-timestamp")
      assert_not book.save
      assert book.errors[field].present?
    end
  end

  test "invalid persisted updates leave stored values unchanged" do
    book = books(:completed)
    original = book.attributes
    assert_not book.update(rating: 6)
    assert_equal original, book.reload.attributes
    assert_not book.update(started_at: book.finished_at + 1.second)
    assert book.errors[:finished_at].present?
    assert_equal original, book.reload.attributes
    assert_not book.update(finished_at: "invalid")
    assert_equal original, book.reload.attributes
  end

  test "completion and review fields can be cleared" do
    book = books(:completed)
    assert book.update(finished_at: nil, rating: nil, review: nil)
    book.reload
    assert_nil book.finished_at
    assert_nil book.rating
    assert_nil book.review
  end

  private
    def valid_book
      Book.new(title: "Model test", author: "Test Author",
        started_at: Time.utc(2026, 1, 1, 12))
    end
end
