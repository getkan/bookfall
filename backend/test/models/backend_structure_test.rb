require "test_helper"

class BackendStructureTest < ActiveSupport::TestCase
  test "user credentials are hashed and no book ownership association exists" do
    admin = users(:admin)
    assert admin.authenticate("fixture-only-password")
    assert_not_equal "fixture-only-password", admin.password_digest
    assert_nil Book.reflect_on_association(:user)
    assert_equal :string, Book.type_for_attribute("user_id").type
    assert_nil books(:completed).user_id
    assert_equal "future-reader", books(:unfinished).user_id
  end

  test "book event type is data rather than Rails inheritance" do
    event = book_events(:completed_finish)
    assert_instance_of BookEvent, event
    assert_equal "FINISH", event.type
    assert_equal books(:completed), event.book
  end

  test "deterministic fixtures cover paired dense empty and unfinished spans" do
    assert_equal 17, Book.count
    assert_equal 19, BookEvent.count
    assert_equal [ 1 ], books(:completed).book_events.distinct.pluck(:start_rank)
    assert_equal [ "START" ], books(:unfinished).book_events.pluck(:type)
    assert_equal 14, BookEvent.where(date: Time.utc(2026, 1, 4).all_day).count
    assert_equal 0, BookEvent.where(date: Time.utc(2026, 2, 1).all_month).count
    assert_nil books(:same_day).rating
    assert_nil books(:same_day).review
  end

  test "database rejects out of range rating" do
    assert_raises ActiveRecord::StatementInvalid do
      books(:completed).update_columns(rating: 6)
    end
  end

  test "database rejects finishing before starting" do
    assert_raises ActiveRecord::StatementInvalid do
      books(:completed).update_columns(finished_at: Time.utc(2025, 12, 1))
    end
  end

  test "database rejects out of range ranks" do
    [ 0, 13 ].each do |rank|
      assert_raises ActiveRecord::StatementInvalid do
        BookEvent.transaction(requires_new: true) do
          book_events(:completed_start).update_columns(start_rank: rank)
        end
      end
    end
  end

  test "database rejects invalid event type and duplicate book type" do
    assert_raises ActiveRecord::StatementInvalid do
      BookEvent.transaction(requires_new: true) do
        book_events(:completed_start).update_columns(type: "OTHER")
      end
    end
    assert_raises ActiveRecord::RecordNotUnique do
      book_events(:completed_start).reload.dup.save!(validate: false)
    end
  end
end
