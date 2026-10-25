class BookEvent < ApplicationRecord
  self.inheritance_column = nil

  belongs_to :book
end
