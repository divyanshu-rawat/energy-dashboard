class House < ApplicationRecord
    has_many :consumers, dependent: :destroy

    validates :name, presence: true
    
end
