require "test_helper"

class StagingSeedsContractTest < ActiveSupport::TestCase
  test "db seed creates the staging books idempotently without events or users" do
    BookEvent.delete_all
    Book.delete_all
    users_before = User.count

    2.times do
      Rails.application.load_seed
      assert_equal 17, Book.count
      assert_equal 0, BookEvent.count
      assert_equal users_before, User.count
    end

    completed = Book.find_by!(title: "A Long Reading")
    assert_equal Time.utc(2026, 4, 1, 12), completed.finished_at
    assert_equal 5, completed.rating
    assert_equal "A thoughtful read.", completed.review
    unfinished = Book.find_by!(title: "Still Reading")
    assert_nil unfinished.finished_at
    assert_equal "future-reader", unfinished.user_id
    assert_equal 14, Book.where(author: "Fixture Author", started_at: Time.utc(2026, 1, 4, 12)).count
  end

  test "rerunning seeds preserves existing books and their events" do
    books_before = Book.order(:id).map(&:attributes)
    events_before = BookEvent.order(:id).map(&:attributes)
    users_before = User.count

    StagingSeeds.load!

    assert_equal books_before, Book.order(:id).map(&:attributes)
    assert_equal events_before, BookEvent.order(:id).map(&:attributes)
    assert_equal users_before, User.count
  end

  test "seeds create only missing books without assigning fixture ids" do
    books(:same_day).book_events.delete_all
    books(:same_day).destroy!

    assert_difference -> { Book.count }, 1 do
      assert_no_difference -> { BookEvent.count } do
        StagingSeeds.load!
      end
    end
    restored = Book.find_by!(title: "One Day", author: "Example Author")
    assert_not_equal 103, restored.id
  end

  test "invalid seed data fails explicitly and creates nothing" do
    Tempfile.create([ "books", ".yml" ]) do |file|
      file.write(<<~YAML)
        valid:
          title: Valid Seed
          author: Seed Author
          started_at: "2026-02-01T00:00:00Z"
        invalid:
          title: Invalid Seed
          author: Seed Author
          started_at: "2026-02-02T00:00:00Z"
          rating: 6
      YAML
      file.flush

      assert_no_difference -> { Book.count } do
        assert_raises(ActiveRecord::RecordInvalid) { StagingSeeds.load!(path: file.path) }
      end
    end
  end
end
