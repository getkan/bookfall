class TaskCheckpoint < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[idle running succeeded failed] }
  validates :books_processed, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :metadata, exclusion: { in: [ nil ] }
end
