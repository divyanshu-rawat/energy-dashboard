
class HouseImportsController < ApplicationController
  def create
    house = House.find(params[:id])

    begin_date = Date.iso8601(params.require(:begin_date))

    importer = Measurements::Importer.new
    processed = 0

    house.consumers.find_each do |consumer|
      processed += importer.call(
        consumer: consumer,
        begin_date: begin_date
      )
    end

    redirect_to house_path(house),
      notice: "Import completed. Processed #{processed} readings.",
      status: :see_other

  rescue ArgumentError, ActionController::ParameterMissing => e
    redirect_to house_path(params[:id]),
      alert: "Invalid import date: #{e.message}",
      status: :see_other

  rescue Measurements::ApiClient::Error,
         Measurements::Importer::Error => e
    redirect_to house_path(params[:id]),
      alert: "Import failed: #{e.message}",
      status: :see_other
  end
end
