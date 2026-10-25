class Book < ApplicationRecord
  has_many :book_events, dependent: :destroy
end
