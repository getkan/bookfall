require "test_helper"

class StagingSeedsContractTest < ActiveSupport::TestCase
  test "staging loader restores deterministic data idempotently without provisioning users" do
    BookEvent.delete_all
    Book.delete_all
    users_before = User.count

    2.times do
      Rails.application.load_seed
      assert_equal 17, Book.count
      assert_equal 19, BookEvent.count
      assert_equal users_before, User.count
      assert_nil Book.find(102).finished_at
      assert_equal [ 1 ], Book.find(101).book_events.distinct.pluck(:start_rank)
    end
  end
end
