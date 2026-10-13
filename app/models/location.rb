class Location < ApplicationRecord
  belongs_to :consumer
  has_many :measurements, dependent: :destroy

  validates :location_type,
            presence: true,
            inclusion: { in: %w[market metering] },
            uniqueness: { scope: :consumer_id }

  validates :external_id,
            presence: true,
            uniqueness: true

  validate :external_id_format

  private

  def external_id_format
    return if external_id.blank?

    case location_type
    when "market"
      errors.add(:external_id, "must be 10 digits") unless
        external_id.match?(/\A\d{10}\z/)
    when "metering"
      errors.add(:external_id, "must be 33 characters") unless
        external_id.length == 33
    end
  end
end