
require "net/http"
require "json"
require "uri"

module Measurements
  class ApiClient
    BASE_URL = "https://mock-measurement-api-8fbe027730b7.herokuapp.com"

    class Error < StandardError; end

    def fetch(location_id:, begin_date:)
      uri = URI("#{BASE_URL}/values/#{location_id}/load-profile")
      uri.query = URI.encode_www_form(beginDate: begin_date.to_s)

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 5,
        read_timeout: 20
      ) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "Measurement API returned HTTP #{response.code}"
      end

      normalize(JSON.parse(response.body), location_id)

    rescue JSON::ParserError, KeyError, TypeError, ArgumentError => e
      raise Error, "Invalid measurement API response: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "Measurement API timed out: #{e.message}"
    rescue SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Error, "Measurement API connection failed: #{e.message}"
    end

    private

    def normalize(daily_profiles, location_id)
      raise TypeError, "Expected an array of daily profiles" unless daily_profiles.is_a?(Array)

      daily_profiles.flat_map do |profile|
        raise TypeError, "Expected measurement values array" unless profile.fetch("values").is_a?(Array)

        if profile.fetch("locationId") != location_id
          raise Error, "Location ID mismatch in API response"
        end

        profile.fetch("values").map do |reading|
          {
            starts_at: Time.iso8601(reading.fetch("startDate")),
            ends_at: Time.iso8601(reading.fetch("endDate")),
            value: BigDecimal(reading.fetch("value").to_s),
            quality: reading.fetch("quality")
          }
        end
      end
    end
  end
end
