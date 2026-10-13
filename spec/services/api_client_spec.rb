
require "rails_helper"

RSpec.describe Measurements::ApiClient do
  subject(:client) { described_class.new }

  let(:location_id) { "1234567890" }
  let(:begin_date) { Date.new(2026, 6, 4) }

  let(:url) do
    "https://mock-measurement-api-8fbe027730b7.herokuapp.com" \
      "/values/#{location_id}/load-profile?beginDate=2026-06-04"
  end

  let(:response_body) do
    [
      {
        "locationId" => location_id,
        "startDate" => "2026-06-04T00:00:00",
        "endDate" => "2026-06-05T00:00:00",
        "values" => [
          {
            "value" => 0.0658,
            "quality" => "TRUE",
            "startDate" => "2026-06-04T00:00:00+02:00",
            "endDate" => "2026-06-04T00:15:00+02:00"
          },
          {
            "value" => 0.4199,
            "quality" => "TRUE",
            "startDate" => "2026-06-04T00:15:00+02:00",
            "endDate" => "2026-06-04T00:30:00+02:00"
          }
        ]
      }
    ]
  end

  describe "#fetch" do
    it "fetches and normalizes measurements" do
      stub_request(:get, url)
        .to_return(
          status: 200,
          body: response_body.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      measurements = client.fetch(
        location_id: location_id,
        begin_date: begin_date
      )

      expect(measurements.size).to eq(2)
      expect(measurements.first[:value]).to eq(BigDecimal("0.0658"))
      expect(measurements.first[:quality]).to eq("TRUE")

      expect(measurements.first[:starts_at]).to eq(
        Time.iso8601("2026-06-04T00:00:00+02:00")
      )
    end

    it "raises an error when the API fails" do
      stub_request(:get, url)
        .to_return(status: 500, body: "Server error")

      expect {
        client.fetch(location_id: location_id, begin_date: begin_date)
      }.to raise_error(
        Measurements::ApiClient::Error,
        /HTTP 500/
      )
    end

    it "rejects malformed JSON" do
      stub_request(:get, url)
        .to_return(status: 200, body: "invalid JSON")

      expect {
        client.fetch(location_id: location_id, begin_date: begin_date)
      }.to raise_error(
        Measurements::ApiClient::Error,
        /Invalid measurement API response/
      )
    end

    it "rejects mismatched location identifiers" do
      invalid_body = response_body.deep_dup
      invalid_body.first["locationId"] = "9999999999"

      stub_request(:get, url)
        .to_return(status: 200, body: invalid_body.to_json)

      expect {
        client.fetch(location_id: location_id, begin_date: begin_date)
      }.to raise_error(
        Measurements::ApiClient::Error,
        /Location ID mismatch/
      )
    end
  end
end
