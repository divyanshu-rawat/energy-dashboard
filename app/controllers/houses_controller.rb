
class HousesController < ApplicationController
  DEFAULT_BEGIN_DATE = Date.new(2026, 6, 4)

  def index
    @houses = House.order(:name)
  end

  def show
    @house = House.find(params[:id])

    @from_date = parse_date(params[:from_date], DEFAULT_BEGIN_DATE)
    @to_date = parse_date(params[:to_date], Date.current)

    @summary = SolarConsumption::Calculator.new.call(
      house: @house,
      from_date: @from_date,
      to_date: @to_date
    )

  rescue ArgumentError => e
    redirect_to house_path(@house),
      alert: e.message,
      status: :see_other
  end

  private

    def parse_date(value, default)
      value.present? ? Date.iso8601(value) : default
    end
end
