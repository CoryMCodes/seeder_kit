class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy

  enum :status, { draft: 0, published: 1, archived: 2 }

  validates :title, presence: true

  scope :published, -> { where(status: :published) }
end
