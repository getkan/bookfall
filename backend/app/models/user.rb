class User < ApplicationRecord
  has_secure_password

  validates :username, presence: true, uniqueness: true
  validates :is_admin, inclusion: { in: [ true, false ] }

  generates_token_for :api_access, expires_in: 12.hours do
    password_salt&.last(10)
  end
end
