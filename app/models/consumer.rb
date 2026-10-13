class Consumer < ApplicationRecord
  belongs_to :house

  has_many :locations, dependent: :destroy

  validates :name, presence: true
end