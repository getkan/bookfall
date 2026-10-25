require "test_helper"

class TaskCheckpointStructureTest < ActiveSupport::TestCase
  test "checkpoint distinguishes processing watermark from monitoring timestamps" do
    checkpoint = TaskCheckpoint.create!(name: "book_events_sync")

    assert_nil checkpoint.processed_through
    assert_nil checkpoint.last_succeeded_at
    assert_nil checkpoint.last_started_at
    assert_nil checkpoint.last_finished_at
    assert_equal "idle", checkpoint.status
    assert_equal 0, checkpoint.books_processed
    assert_equal({}, checkpoint.metadata)
    assert_nil checkpoint.last_error
    assert checkpoint.created_at.present?
  end

  test "database prevents duplicate task identities and invalid monitoring state" do
    TaskCheckpoint.create!(name: "book_events_sync")
    assert_raises ActiveRecord::RecordNotUnique do
      TaskCheckpoint.transaction(requires_new: true) do
        TaskCheckpoint.create!(name: "book_events_sync")
      end
    end
    assert_raises ActiveRecord::StatementInvalid do
      TaskCheckpoint.transaction(requires_new: true) do
        TaskCheckpoint.create!(name: "invalid", status: "unknown")
      end
    end
    assert_raises ActiveRecord::StatementInvalid do
      TaskCheckpoint.create!(name: "negative", books_processed: -1)
    end
  end

  test "ordinary book writes maintain timestamps for incremental selection" do
    book = books(:unfinished)
    assert book.created_at.present?
    assert book.updated_at.present?
    previous = book.updated_at

    travel_to previous + 1.minute do
      book.update!(title: "Updated title")
      assert_operator book.reload.updated_at, :>, previous
    end
    assert Book.connection.index_exists?(:books, [ :updated_at, :id ])
  end
end
