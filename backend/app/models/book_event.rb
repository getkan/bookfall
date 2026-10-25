class BookEvent < ApplicationRecord
  self.inheritance_column = nil

  belongs_to :book

  validates :type, inclusion: { in: %w[START FINISH] },
    uniqueness: { scope: :book_id }
  validates :date, presence: true
  validates :start_rank, numericality: { only_integer: true, in: 1..12 }
end
