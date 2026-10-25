require "test_helper"
require "rake"

class BookEventSyncContractTest < ActiveSupport::TestCase
  test "first synchronization creates missing events and a successful checkpoint" do
    BookEvent.delete_all
    BookEventSync.call

    assert_equal 19, BookEvent.count
    checkpoint = TaskCheckpoint.find_by!(name: "book_events_sync")
    assert_equal "succeeded", checkpoint.status
    assert checkpoint.processed_through.present?
    assert checkpoint.last_succeeded_at.present?
    assert_equal 17, checkpoint.books_processed
  end

  test "scheduled rake entry point is idempotent for unchanged books" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("book_events:sync")
    task = Rake::Task["book_events:sync"]
    original_ids = BookEvent.order(:id).pluck(:id)

    2.times do
      task.reenable
      task.invoke
      assert_equal original_ids, BookEvent.order(:id).pluck(:id)
    end
    assert_equal 1, TaskCheckpoint.where(name: "book_events_sync").count
  end
end
