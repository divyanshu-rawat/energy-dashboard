class Measurement < ApplicationRecord
  belongs_to :location

  validates :starts_at, :ends_at, :value, presence: true

  validate :valid_interval

  private

  def valid_interval
    return if starts_at.blank? || ends_at.blank?

    if ends_at <= starts_at
      errors.add(:ends_at, "must be after starts_at")
    end
  end
end