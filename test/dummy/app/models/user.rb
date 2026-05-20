class User < ApplicationRecord
  has_many :posts, dependent: :destroy

  validates :email, presence: true
end
