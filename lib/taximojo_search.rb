require "cgi"
require "json"
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "transport_app_integration")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "faraday_connections")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "envs")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "dist_calc")
require File.join(File.dirname(File.dirname(__FILE__)), "lib", "google", "google_distance")

class TaximojoSearch < TransportAppIntegration

  attr_reader :error

  # TODO(noam): update this taxi fare, since it doesn't seem accurate.
  PRICE = { :base => 3.50, :per_mile => 2.75, :per_mile_outter => 2.75, :per_min => 0.55, :min => 0  }

  TAXIMOJO_QUERY_URL = "http://default.swishly.com/1.0.0/metaio/poi?latitude=:lat&longitude=:long"

  def initialize(lat, long)
    @lat, @long = lat.to_s, long.to_s
    response = FaradayConnections.make_request_through_cache(
        URI(TAXIMOJO_QUERY_URL.gsub(":lat", @lat).gsub(":long", @long)), 2.minutes)
    begin
      @drivers = JSON.parse(response.body)["drivers"]
    rescue Exception => e
      puts "ERROR (taximojo): could not get data from #{e}"
      @error = true
    end
  end

  def get_distance_to_closest
    return {} if @drivers.nil? || @drivers.empty?
    # for the moment assuming the json returned is sorted by distance, make sure this is in fact the case.
    begin
      coordinates = @drivers[0]["coordinates"]
      # Uncomment the lines below if we want to remove the google request
      # dist = DistCalc::distance_formatted(@lat, @long, coordinates["latitude"], coordinates["longitude"])
      # dist[:amount].to_s + dist[:metric].to_s
      GoogleDistance.new([coordinates["latitude"], coordinates["longitude"]], [@lat, @long]).duration_text
    rescue Exception => e
      puts "ERROR (taximojo): could not get the coordinates of the closest driver #{e}"
      {}
    end
  end

  def fare_estimate(distance, duration)
    [(PRICE[:base] + [PRICE[:per_mile] * distance, PRICE[:per_min] * duration].max), PRICE[:min]].max.to_i
  end

end
