require "test_helper"

class TaskCheckpointTest < ActiveSupport::TestCase
  test "defaults allow a new checkpoint without a watermark" do
    checkpoint = TaskCheckpoint.create!(name: "model-task")
    assert_equal "idle", checkpoint.status
    assert_equal 0, checkpoint.books_processed
    assert_equal({}, checkpoint.metadata)
    assert_nil checkpoint.processed_through
    assert_nil checkpoint.last_started_at
    assert_nil checkpoint.last_finished_at
    assert_nil checkpoint.last_succeeded_at
    assert_nil checkpoint.last_error
  end

  test "task name is required and unique" do
    [ nil, "", " " ].each do |name|
      checkpoint = TaskCheckpoint.new(name: name)
      assert_not checkpoint.save
      assert checkpoint.errors.of_kind?(:name, :blank)
    end
    TaskCheckpoint.create!(name: "model-task")
    duplicate = TaskCheckpoint.new(name: "model-task")
    assert_not duplicate.save
    assert duplicate.errors.of_kind?(:name, :taken)
  end

  test "status accepts only defined monitoring states" do
    checkpoint = TaskCheckpoint.new(name: "model-task")
    %w[idle running succeeded failed].each do |status|
      checkpoint.status = status
      assert checkpoint.valid?, checkpoint.errors.full_messages.to_sentence
    end
    [ nil, "", "unknown" ].each do |status|
      checkpoint.status = status
      assert_not checkpoint.save
      assert checkpoint.errors[:status].present?
    end
  end

  test "books processed is a nonnegative integer" do
    checkpoint = TaskCheckpoint.new(name: "model-task")
    [ 0, 1, 100 ].each do |count|
      checkpoint.books_processed = count
      assert checkpoint.valid?
    end
    [ nil, -1, 1.5, "2.5", "invalid" ].each do |count|
      checkpoint.books_processed = count
      assert_not checkpoint.save
      assert checkpoint.errors[:books_processed].present?
    end
  end

  test "metadata can be empty or extensible JSON but not null" do
    checkpoint = TaskCheckpoint.new(name: "model-task", metadata: nil)
    assert_not checkpoint.save
    assert checkpoint.errors[:metadata].present?
    checkpoint.metadata = { "attempt" => 2, "details" => { "retry" => true } }
    checkpoint.save!
    assert_equal({ "attempt" => 2, "details" => { "retry" => true } }, checkpoint.reload.metadata)
  end
end
