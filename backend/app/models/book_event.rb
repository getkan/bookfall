class BookEvent < ApplicationRecord
  self.inheritance_column = nil

  belongs_to :book

  scope :with_book_details, -> {
    joins(:book).select("book_events.*", "books.user_id AS book_user_id",
      "books.title AS book_title", "books.author AS book_author",
      "books.rating AS book_rating", "books.finished_at AS book_finished_at",
      "books.review AS book_review")
  }

  validates :type, inclusion: { in: %w[START FINISH] },
    uniqueness: { scope: :book_id }
  validates :date, presence: true
  validates :start_rank, numericality: { only_integer: true, in: 1..12 }

  def timeline_payload
    {
      "id" => id, "book_id" => book_id, "type" => type,
      "date" => date.utc.iso8601(date.usec.zero? ? 0 : 6), "start_rank" => start_rank,
      "user_id" => book_user_id, "title" => book_title, "author" => book_author,
      "rating" => book_rating, "review" => book_finished_at ? book_review : nil
    }
  end
end
