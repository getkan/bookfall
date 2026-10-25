require "test_helper"

class BookEventTest < ActiveSupport::TestCase
  test "event requires an existing book and valid date" do
    event = book_events(:completed_start)
    event.book = nil
    assert_not event.valid?
    assert event.errors[:book].present?
    event.book_id = Book.maximum(:id) + 1
    assert_not event.valid?
    assert event.errors[:book].present?
    event.book = books(:completed)
    [ nil, "", "invalid" ].each do |date|
      event.date = date
      assert_not event.save
      assert event.errors[:date].present?
    end
  end

  test "only START and FINISH types are accepted" do
    event = book_events(:completed_start)
    [ nil, "", "start", "FINISHED", "OTHER" ].each do |type|
      event.type = type
      assert_not event.save
      assert event.errors[:type].present?
    end
    assert book_events(:completed_finish).valid?
    event.type = "START"
    assert event.valid?
  end

  test "rank accepts every integer from one through twelve" do
    event = book_events(:completed_start)
    (1..12).each do |rank|
      event.start_rank = rank
      assert event.valid?, event.errors.full_messages.to_sentence
    end
  end

  test "rank rejects absent fractional malformed and out of range values" do
    event = book_events(:completed_start)
    [ nil, 0, 13, -1, 1.5, "2.5", "invalid" ].each do |rank|
      event.start_rank = rank
      assert_not event.save, "rank must reject #{rank.inspect}"
      assert event.errors[:start_rank].present?
    end
  end

  test "a book cannot have duplicate event types" do
    event = book_events(:completed_start).dup
    assert_not event.save
    assert event.errors.of_kind?(:type, :taken)
    assert book_events(:completed_start).valid?
  end

  test "deleting a book removes both associated event types" do
    book = books(:completed)
    ids = book.book_events.pluck(:id)
    assert_equal 2, ids.size
    assert_difference("BookEvent.count", -2) { book.destroy! }
    assert_empty BookEvent.where(id: ids)
  end
end
