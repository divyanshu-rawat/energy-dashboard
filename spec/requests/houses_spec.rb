
require "rails_helper"

RSpec.describe "House dashboard", type: :request do
  let!(:house) { House.create!(name: "Solar House Demo") }
  let!(:consumer) do
    Consumer.create!(house: house, name: "Apartment 1")
  end

  describe "GET /" do
    it "lists houses" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Solar House Demo")
    end
  end

  describe "GET /houses/:id" do
    it "displays the consumption dashboard" do
      get house_path(house)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Total solar consumption")
      expect(response.body).to include("Apartment 1")
      expect(response.body).to include("Import measurements")
    end

    it "accepts a valid date range" do
      get house_path(house),
          params: {
            from_date: "2026-06-04",
            to_date: "2026-06-05"
          }

      expect(response).to have_http_status(:ok)
    end

    it "redirects for an invalid date range" do
      get house_path(house),
          params: {
            from_date: "2026-06-05",
            to_date: "2026-06-04"
          }

      expect(response).to redirect_to(house_path(house))
    end

    it "shows an error for a reversed date range" do
      get house_path(house),
          params: {
            from_date: "2026-10-15",
            to_date: "2026-06-04"
          }

      expect(response).to redirect_to(house_path(house))

      follow_redirect!

      expect(response.body).to include("Invalid date range")
    end

    it "shows an empty state when no measurements exist" do
      get house_path(house),
          params: {
            from_date: "2026-06-04",
            to_date: "2026-06-05"
          }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "No consumption data available"
      )
    end

  end

  describe "POST /houses/:id/import" do
    let(:importer) { instance_double(Measurements::Importer) }

    before do
      allow(Measurements::Importer).to receive(:new)
        .and_return(importer)
    end

    it "triggers an import for the house's consumer" do
      expect(importer).to receive(:call).with(
        consumer: consumer,
        begin_date: Date.new(2026, 6, 4)
      ).and_return(192)

      post import_house_path(house),
           params: { begin_date: "2026-06-04" }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(house_path(house))

      follow_redirect!
      expect(response.body).to include("Processed 192 readings")
    end

    it "rejects an invalid import date" do
      expect(importer).not_to receive(:call)

      post import_house_path(house),
           params: { begin_date: "invalid-date" }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(house_path(house))
    end
  end
end
