class Book < ApplicationRecord
  has_many :book_events, dependent: :destroy

  validates :title, :author, :started_at, presence: true
  validates :rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :finished_at, comparison: { greater_than_or_equal_to: :started_at },
    allow_nil: true, if: -> { started_at.present? }

  validate :finished_at_is_valid_timestamp

  private
    def finished_at_is_valid_timestamp
      if finished_at_before_type_cast.present? && finished_at.nil?
        errors.add(:finished_at, :invalid)
      end
    end
end
